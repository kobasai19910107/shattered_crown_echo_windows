extends SceneTree

# OPTIONAL, SLOW: godot --headless --path . -s res://tests/r1_b04_balance_audit_runner.gd -- --seeds=30
# 6 weapon archetypes x 30 seeds. Existing AutoBattlePolicy is a computer policy,
# not a human win-rate estimate. No baseline-A claim unless separately executed.
const WEAPONS := ["SWORD","RAPIER","DAGGER","GREATSWORD","MAGICSWORD","KATANA"]
const SLOTS := ["main_weapon","offhand","head","body","hands","feet"]
var outcome: Array=[]
var failures: Array[String]=[]

func _initialize() -> void:
    var seed_count: int=30
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--seeds="):
            seed_count=clampi(int(arg.trim_prefix("--seeds=")),1,30)
    var generator := InitialDeckGenerator.new()
    if not generator.load_data():
        push_error("Cannot load initial equipment definitions")
        quit(2)
        return
    for weapon in WEAPONS:
        var ids: Dictionary={}
        for slot in SLOTS:
            for template_id in generator.roller.templates:
                var template: Dictionary=generator.roller.templates[template_id]
                if str(template.get("Rarity","")) != "Rare": continue
                if str(generator.roller.SLOT_CODES.get(str(template.get("Slot","")),"")) != slot: continue
                if slot=="main_weapon" and str(template.get("BaseCode",""))!=weapon: continue
                ids[slot]=str(template_id)
                break
        if ids.size()!=6:
            failures.append("Missing 6 Rare template slots for "+weapon)
            continue
        for index in range(seed_count):
            var equipment_seed: int=20261008+index
            var fight_seed: int=2021891360+index
            var generated: Dictionary=generator.generate_initial_loadout(ids,equipment_seed,InitialDeckGenerator.PROFILE_VERSION,64)
            if not bool(generated.get("ok",false)):
                outcome.append({"weapon":weapon,"seed":fight_seed,"result":"EQUIPMENT_GENERATION_FAILED"})
                continue
            var loadout: Dictionary=generated.items
            var deck: Array=[]
            for slot in SLOTS:
                deck.append_array(loadout[slot].cards)
            var core := BattleController.new()
            if not core.start_region1(fight_seed,deck,["R1-B04"],loadout,core._resolve_player_max_hp(loadout)):
                failures.append("Could not initialize battle: "+weapon+"/"+str(fight_seed))
                continue
            # Fixed maximum for capped evaluations; cap reached is NOT a defeat.
            var actions: int=0
            while not core.combat_over and core.turn_number<=45 and actions<250:
                var auto := AutoBattlePolicy.new()
                var move: Dictionary=auto.choose(core)
                if move.is_empty() or not auto.execute(core,move):
                    failures.append("Invalid AutoBattlePolicy action: "+weapon+"/"+str(fight_seed))
                    break
                actions+=1
            var stats: Dictionary=core.get_playtest_report()
            var result_name: String="VICTORY" if core.victory else ("DEFEAT" if core.combat_over else "CENSORED")
            outcome.append({"weapon":weapon,"seed":fight_seed,"equipment_seed":equipment_seed,
                "policy":"AutoBattlePolicy depth5 width20 public-info baseline","result":result_name,
                "turns":core.turn_number,"start_hp":int(core.playtest_stats.get("combat_start_hp",0)),
                "final_hp":core.player_hp,"damage_taken":int(stats.get("damage_taken",0)),
                "block_absorbed":int(stats.get("block_absorbed",0)),"cards_used":int(stats.get("cards_used",0)),
                "power_placements":int(stats.get("power_placements",0)),"hp_ledger_delta":int(stats.get("hp_ledger_actual_delta",0))})
    var output: Dictionary={"mode":"AFTER_ONLY","seeds_per_weapon":seed_count,"results":outcome,"failures":failures,
        "note":"Human play untested; no old baseline executed; CENSORED is neither win nor defeat."}
    var file := FileAccess.open("user://r1_b04_balance_results.json",FileAccess.WRITE)
    if file == null:
        failures.append("Cannot write user://r1_b04_balance_results.json")
    else:
        file.store_string(JSON.stringify(output,"  "))
        file.close()
    print("B04 audit: ",outcome.size()," rows / errors ",failures.size())
    quit(0 if failures.is_empty() else 1)
