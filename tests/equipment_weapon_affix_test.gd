extends SceneTree

# Stage 3 integration harness. Run with Godot 4.7.2:
# godot --headless --path . -s res://tests/equipment_weapon_affix_test.gd
# No balance outcomes are asserted here; this checks the W01-W18 event hooks.
var passed: int = 0
var failed: Array[String] = []

func check(label: String, yes: bool) -> void:
    if yes:
        passed+=1
    else:
        failed.append(label)
        push_error("FAIL: "+label)

func _initialize() -> void:
    call_deferred("run")

func fixture(effect_id: String, card_id: String) -> Dictionary:
    var b: BattleController = BattleController.new()
    b.start_battle(120901,[],"standard_trio")
    var c: Dictionary = b.database.cards.get(card_id, {}).duplicate(true)
    c["source_equipment_uid"] = "FIXTURE_MAIN"
    c["source_slot"] = "main_weapon"
    c["card_instance_uid"] = "FIXTURE_MAIN:main_weapon:0"
    b.active_equipment_loadout = {"main_weapon":{
        "instance_id":"FIXTURE_MAIN", "slot":"main_weapon",
        "cards":[card_id,"C001","C002","C003"],
        "special_effects":[{"effect_id":effect_id}]
    }}
    return {"battle":b, "card":c}

func sample_for(effect_id: String, master: Dictionary) -> String:
    var weapon_index: int = int((int(effect_id.substr(1))-1)/3)
    var names: Array[String] = ["片手剣","レイピア","短剣","大剣","魔法剣","刀"]
    var weapon: String = names[weapon_index]
    var action: String = ""
    match effect_id:
        "W01","W04","W05","W07","W10","W14","W15","W17","W18": action="CONSUME"
        "W03","W06","W08","W11","W13","W16": action="SET"
    for card_id in master.keys():
        var c: Dictionary=master[card_id]
        if str(c.get("weapon",""))!=weapon: continue
        if action!="" and str(c.get("weapon_trait_action",""))!=action: continue
        match effect_id:
            "W01","W04","W05","W07","W09","W10","W12","W17","W18":
                if str(c.get("card_type",""))!="attack": continue
            "W02":
                if str(c.get("card_type",""))!="skill" or int(c.get("base_block",0))<=0: continue
            "W14","W15":
                if int(c.get("attribute_trait_gain",0))<=0: continue
        if effect_id in ["W17","W18"] and not bool(c.get("iai_compatible",false)): continue
        if effect_id=="W12" and int(c.get("cost",0))<2: continue
        return str(card_id)
    return ""

func run() -> void:
    var b: BattleController=BattleController.new()
    b.start_battle(98201,[],"standard_trio")
    var db: Dictionary=b.database.cards
    check("master has 120", db.size()==120)
    check("exactly 48 enabled IDs",EquipmentSpecialEffectPolicy.EFFECT_IDS.size()==48)
    for effect_id in EquipmentSpecialEffectPolicy.W_EFFECT_IDS:
        var sample: String=sample_for(effect_id,db)
        check("sample exists "+effect_id, sample!="")
        if sample=="": continue
        var setup: Dictionary=fixture(effect_id,sample)
        var card: Dictionary=setup.card
        var ctl: BattleController=setup.battle
        check("origin filter positive "+effect_id,ctl._local_weapon_effect_ids(card).has(effect_id))
        var other: Dictionary=card.duplicate(true)
        other["source_equipment_uid"]="WRONG"
        check("origin filter negative "+effect_id,ctl._local_weapon_effect_ids(other).is_empty())
        check("policy has details "+effect_id,EquipmentSpecialEffectPolicy.NAMES.has(effect_id) and EquipmentSpecialEffectPolicy.DETAILS.has(effect_id))
        check("eligible with matching card "+effect_id,EquipmentSpecialEffectPolicy.eligible_ids({"cards":[sample,"C001","C002","C003"]}).has(effect_id))
    # Representative actual ON/CONSUME and second-hit checks.
    var x: Dictionary=fixture("W01","C001")
    x.battle._local_weapon_after_card(x.card.merged({"_local_weapon_trait_use":{"sword":true}},true))
    check("W01 Sword consume -> Block2",x.battle.player_block==2)
    x=fixture("W02","C002")
    x.battle.campaign_status["LastType"]="attack"
    check("W02 Attack then Sword Skill +3",x.battle._local_skill_block_bonus(x.card,6)==3)
    x=fixture("W03","C002")
    x.battle._local_weapon_set(x.card,"流転",true)
    check("W03 new ON => Block2",x.battle.player_block==2)
    x.battle._local_weapon_set(x.card,"流転",false)
    check("W03 already ON => no extra",x.battle.player_block==2)
    x=fixture("W04","C003")
    check("W04 Precision consumed +2",x.battle._local_attack_bonus(x.card,{"precision":true})==2)
    x=fixture("W05","C003")
    x.battle.enemies[0]["hp"]=100
    x.battle.enemies[0]["block"]=0
    x.battle.enemies[0]["vulnerable"]=0
    x.battle._resolve_attack(x.card,0,1,{"precision":true})
    check("W05 actually applies 脆弱 -> Block2",int(x.battle.enemies[0].vulnerable)==1 and x.battle.player_block==2)
    x=fixture("W06","C004")
    x.battle.draw_pile=x.battle.database.create_deck_from_ids(["C001"])
    var old_hand_count: int=x.battle.hand.size()
    x.battle._local_weapon_set(x.card,"精密",true)
    check("W06 fresh ON draws one",x.battle.hand.size()==old_hand_count+1)
    x=fixture("W07","C005")
    x.battle.enemies[0]["hp"]=100
    x.battle.enemies[0]["block"]=0
    var hp_before: int=int(x.battle.enemies[0].hp)
    x.battle._resolve_attack(x.card,0,5,{"flurry":true})
    check("W07 second hit +2 only",hp_before-int(x.battle.enemies[0].hp)==12)
    x=fixture("W08","C006")
    x.battle._local_weapon_set(x.card,"連刃",true)
    check("W08 new ON -> Block2",x.battle.player_block==2)
    x=fixture("W09","C005")
    check("W09 first Dagger Attack no bonus",x.battle._local_attack_bonus(x.card)==0)
    x.battle.playtest_stats["dagger_attacks_turn"]=1
    check("W09 later Dagger Attack +2",x.battle._local_attack_bonus(x.card)==2)
    x=fixture("W10","C008")
    check("W10 after multiplier +3",x.battle._local_weapon_post_heavy_bonus(x.card,{"charge":true},0)==3)
    x=fixture("W11","C007")
    x.battle._local_weapon_set(x.card,"重撃",true)
    check("W11 new ON -> Block3",x.battle.player_block==3)
    x=fixture("W12","C008")
    x.battle._local_weapon_after_card(x.card)
    check("W12 Printed Cost>=2 -> Block2",x.battle.player_block==2)
    # Find the actual SET and CONSUME Magic Sword cards from the live 120 master.
    var magic_set_id: String=sample_for("W13",db)
    var magic_gain_id: String="C105" # 秘術/魔珠: player-side attribute gain, no enemy target required
    x=fixture("W13",magic_set_id)
    x.battle._local_weapon_set(x.card,"魔導",true)
    check("W13 new ON -> Block2",x.battle.player_block==2)
    x=fixture("W14",magic_gain_id)
    var natural_gain: int=int(x.card.get("attribute_trait_gain",0))
    var attr: String=str(x.card.get("attribute_trait",""))
    x.card["_weapon_trait_magic_used"]=true
    x.card["_local_weapon_trait_use"]={"magic":true}
    x.battle.resolving_card=x.card
    var old_trait: int=x.battle.get_attribute_trait(attr)
    x.battle._finish_resolving_card()
    check("W14 Magic gain +1 beyond usual +2",x.battle.get_attribute_trait(attr)==old_trait+natural_gain+3)
    x=fixture("W15",magic_gain_id)
    x.card["_local_weapon_trait_use"]={"magic":true}
    var mana_before: int=x.battle.current_mana
    x.battle._local_weapon_after_card(x.card)
    check("W15 Magic consumed +1 Mana",x.battle.current_mana==mana_before+1)
    x=fixture("W16","C023")
    x.battle._local_weapon_set(x.card,"納刀",true)
    check("W16 new ON -> Block2",x.battle.player_block==2)
    x=fixture("W17","C012")
    check("W17 Iai consumed +3",x.battle._local_attack_bonus(x.card,{"sheathed":true})==3)
    x=fixture("W18","C012")
    x.card["_local_weapon_trait_use"]={"sheathed":true}
    x.battle._local_weapon_after_card(x.card)
    check("W18 Iai after +3 Block",x.battle.player_block==3)
    print("EQUIPMENT_WEAPON_AFFIX_TEST: %d PASS / %d FAIL %s" % [passed,failed.size(),str(failed)])
    quit(0 if failed.is_empty() else 1)
