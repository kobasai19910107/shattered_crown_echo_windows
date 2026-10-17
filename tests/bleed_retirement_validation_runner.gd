extends SceneTree

# Run: godot --headless --path . -s res://tests/bleed_retirement_validation_runner.gd
var passed: int=0
var failed: Array[String]=[]

func check(label: String, ok: bool) -> void:
    if ok:
        passed+=1
    else:
        failed.append(label)
        print("FAIL: ",label)

func _initialize() -> void:
    var catalog := RegionEnemyCatalog.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 2021891360
    for name in ["R1-B04","R1-E02","R1-N05","R2-B02","R2-N02","R2-N06"]:
        var enemy: Dictionary=catalog.create(name,1,rng)
        check(name+" exists",not enemy.is_empty())
        if enemy.is_empty(): continue
        var definition: Dictionary=enemy.r1_data
        for key in ["ai_pattern","ai_pattern_stage_2","ai_pattern_stage_3"]:
            for action in definition.get(key,[]):
                check(name+" no retired AI mode",str(action)!="bleed")
        check(name+" no retired status",str(definition.get("signature_player_status",""))!="Bleed")
        check(name+" no retired condition",str(definition.get("signature_condition_status",""))!="Bleed")
        var patterns: Array=[]
        patterns.append_array(definition.get("ai_pattern",[]))
        patterns.append_array(definition.get("ai_pattern_stage_2",[]))
        patterns.append_array(definition.get("ai_pattern_stage_3",[]))
        for action_name in patterns:
            enemy.r1_action = str(action_name)
            var intent: Dictionary=catalog.intent(enemy,{})
            check(name+" intent populated "+str(action_name),not intent.get("actions",[]).is_empty())
            for action in intent.get("actions",[]):
                check(name+" no bleed intent action "+str(action_name),str(action.get("status",""))!="Bleed")
        if name == "R1-B04":
            check("B04 maxHP unchanged",int(definition.max_hp)==158)
            check("B04 block unchanged",int(definition.defend_amount)==12)
            check("B04 rhythm unchanged",definition.ai_pattern==["buff","defend","signature","attackx2"])
        if name == "R1-N05" or name == "R2-N02":
            enemy.r1_action = "signature"
            var special: Dictionary=catalog.intent(enemy,{})
            var found: bool=false
            for action in special.get("actions",[]):
                if str(action.get("type",""))=="attack":
                    found = int(action.get("hits",0))==2 and int(action.get("damage",-1))==3
            check(name+" two-hit 3x2",found)
        if name == "R2-N06":
            check("N06 Poison retained",str(definition.signature_condition_status)=="Poison")

    var c := BattleController.new()
    var db := CardDatabase.new()
    check("load cards",db.load_data())
    var cards: Array=[]
    for card in db.create_prototype_deck():
        cards.append(str(card.get("id","")))
    check("prototype deck available",cards.size()>0)
    check("start boss with carried HP",c.start_region1(2021891360,cards,["R1-B04"],{},43))
    check("carried HP is actual encounter start",c.player_hp==43 and int(c.playtest_stats.get("combat_start_hp",0))==43)
    check("start log records carried HP", "DIAG ENCOUNTER_START" in "\n".join(c.logs) and "hp=43/" in "\n".join(c.logs))
    check("start log records whole deck", "deck=" in "\n".join(c.logs))
    check("no live bleed",int(c.region1_player_status.get("Bleed",-1))==0 and int(c.region1_player_status.get("BleedTurns",-1))==0)
    var legacy: Dictionary=c.export_region1_state()
    legacy.region1_player_status={"Bleed":5,"BleedTurns":2}
    # Real old saves may omit Expires entirely (title-screen Continue regression).
    legacy.campaign_status.erase("Expires")
    legacy.campaign_status["Bleed"]=4
    legacy.enemies[0].r1_data.signature_player_status="Bleed"
    legacy.enemies[0].r1_data.signature_player_status_value=2
    legacy.enemies[0].r1_data.role_description="Strength・Block・Thorns・Bleedを段階的に組み合わせる。"
    legacy.enemies[0].r1_data.signature_action_description="Strength・Block・Thorns・Bleedを段階的に組み合わせる。"
    var restored := BattleController.new()
    var imported: bool=restored.import_region1_state(legacy)
    check("legacy boss save migrates",imported)
    if imported:
        check("legacy bleed normalized",int(restored.region1_player_status.get("Bleed",-1))==0 and int(restored.region1_player_status.get("BleedTurns",-1))==0)
        check("legacy HP preserved",restored.player_hp==43)
        check("legacy boss canon refreshed",restored.enemies[0].r1_data==catalog.entries["R1-B04"])
        check("missing Expires normalized",restored.campaign_status.has("Expires") and restored.campaign_status["Expires"] is Dictionary)
        check("legacy campaign Bleed removed",not restored.campaign_status.has("Bleed"))
        var before: int=restored.player_hp
        restored.finish_player_turn_effects()
        check("no old bleed tick",restored.player_hp==before)
        var exported: Dictionary=restored.export_region1_state()
        check("reexported Bleed zero",int(exported.region1_player_status.Bleed)==0)

    var legacy_with_expires: Dictionary=legacy.duplicate(true)
    legacy_with_expires.campaign_status["Expires"]={"Bleed":10,"Poison":12}
    var restored_with_expires := BattleController.new()
    var imported_with_expires: bool=restored_with_expires.import_region1_state(legacy_with_expires)
    check("legacy Expires dictionary migrates",imported_with_expires)
    if imported_with_expires:
        check("Bleed timer removed",not restored_with_expires.campaign_status["Expires"].has("Bleed"))
        check("unrelated status expiry preserved",int(restored_with_expires.campaign_status["Expires"].get("Poison",-1))==12)
    print("BLEED RETIREMENT: PASS ",passed," FAIL ",failed.size())
    if not failed.is_empty():
        print("Failures: ",failed)
    quit(0 if failed.is_empty() else 1)
