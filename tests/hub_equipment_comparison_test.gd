extends SceneTree
var passed: int=0
var failures: Array=[]
func check(title: String,ok: bool) -> void:
    if ok:passed+=1
    else:failures.append(title);print("FAIL "+title)
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
    if not OS.get_environment("APPDATA").contains("step37_runs"):quit(2);return
    var service=HubEquipmentComparison.new()
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    for seed_value in range(12):
        var items: Dictionary=helper.make_items(service.analyzer.roller,712301+seed_value*10000)
        for slot in HubDeckAnalyzer.SLOTS:
            var templates: Array=service.analyzer.roller.get_templates_for_slot(slot)
            var candidate: Dictionary=service.analyzer.roller.generate_item(str(templates[-1].EquipmentID),812901+seed_value)
            var snapshot: String=JSON.stringify(items)
            var candidate_snapshot: String=JSON.stringify(candidate)
            var result: Dictionary=service.compare(items,candidate)
            check("preview input immutability",JSON.stringify(items)==snapshot and JSON.stringify(candidate)==candidate_snapshot)
            check("24 cards",result.before.complete and result.after.complete and result.after.deck.size()==24)
            for field in ["attribute","weapon"]:
                var count: int=0
                for n in result.after.distribution[field].values():count+=int(n)
                check(field+" total24",count==24)
            var inspect: Dictionary=service.analyzer.roller.inspect_deck(result.after_items)
            check("existing SC and orphan",result.after.completed_sc==inspect.completed_sc and result.after.orphan==inspect.orphan)
            check("comparison shares analyzer orphan_pairs",result.before.orphan_pairs==service.analyzer.analyze(result.before_items).orphan_pairs and result.after.orphan_pairs==service.analyzer.analyze(result.after_items).orphan_pairs)
            for other in HubDeckAnalyzer.SLOTS:
                check("only candidate slot",result.after_items[other]==(candidate if slot==other else items[other]))
            result.after_items[slot].cards.clear();result.before_items[slot].cards.clear();result.candidate.fixed_cards.clear()
            check("deep copies",JSON.stringify(items)==snapshot and JSON.stringify(candidate)==candidate_snapshot)
            check("same equipment no change",service.compare(items,items[slot]).unchanged)
        var partial: Dictionary=items.duplicate(true);partial.erase("feet")
        var partial_result: Dictionary=service.compare(partial,items.main_weapon)
        check("missing explicit",partial_result.before.missing_slots==["feet"] and partial_result.after.missing_slots==["feet"] and not partial_result.after.complete)
        check("missing slot can be filled",service.compare(partial,items.feet).after.complete)
    helper.free()
    root.size=Vector2i(1280,900)
    var main=load("res://main.tscn").instantiate();root.add_child(main);await process_frame
    var ui: Region1RunUI=main.region_run_ui
    helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    var items: Dictionary=helper.make_items(ui.run.roller,912701);helper.free()
    ui.run.save_path="user://hub_phase_b_fixture.json"
    check("adopt fixture",ui.run.adopt_initial(items))
    var next: Dictionary=ui.run.state.duplicate(true)
    var candidate: Dictionary=ui.run.roller.generate_item(str(ui.run.roller.get_templates_for_slot("main_weapon")[-1].EquipmentID),912708)
    var uid: String=str(candidate.instance_id);next.inventory[uid]=candidate
    check("inventory fixture commit",ui.run._commit(next))
    ui.render();await process_frame
    ui.open_hub_page("equipment");await process_frame
    var panel: HubEquipmentPanel=ui.find_child("HubEquipmentPanel",true,false)
    var before: String=JSON.stringify(ui.run.state)
    var save_before: String=FileAccess.get_file_as_string(ui.run.save_path)
    var mtime: int=FileAccess.get_modified_time(ui.run.save_path)
    panel.selected_uid=uid;panel.refresh_inventory();panel.tabs.current_tab=0;await process_frame
    check("selected candidate comparison",panel.preview.candidate==candidate and panel.preview.before.card_count==24 and panel.preview.after.card_count==24)
    check("inline comparison visible",panel.detail.find_child("WarehouseSideBySideComparison",true,false)!=null and panel.detail.find_child("WarehouseComparisonMetrics",true,false)!=null)
    check("preview no state or inventory loss",JSON.stringify(ui.run.state)==before)
    check("preview no save write",FileAccess.get_file_as_string(ui.run.save_path)==save_before and FileAccess.get_modified_time(ui.run.save_path)==mtime)
    for blocker in ["save","pending","phase","generation","animation"]:
        if blocker=="save":ui.run.save_blocked=true
        if blocker=="pending":ui.run.state.forge_pending={"fixture":true}
        if blocker=="phase":ui.run.state.phase="route"
        if blocker=="generation":main.generation_job=RefCounted.new()
        if blocker=="animation":ui.animation_busy=true
        var blocked_state: String=JSON.stringify(ui.run.state)
        panel.confirm_equipment()
        check("blocked "+blocker,JSON.stringify(ui.run.state)==blocked_state and FileAccess.get_file_as_string(ui.run.save_path)==save_before)
        ui.run.save_blocked=false;ui.run.state.forge_pending={};ui.run.state.phase="hub";main.generation_job=null;ui.animation_busy=false
    var good_path: String=ui.run.save_path
    ui.run.save_path="user://missing_directory/fixture.json"
    panel.confirm_equipment()
    check("save failure preserves state",JSON.stringify(ui.run.state)==before and FileAccess.get_file_as_string(good_path)==save_before and ui.run.notice!="")
    check("existing error shown",panel.detail.get_child(-1).text==ui.run.notice)
    ui.run.save_path=good_path
    var inventory_before: Dictionary=ui.run.state.inventory.duplicate(true)
    var loadout_before: Dictionary=ui.run.state.loadout.duplicate(true)
    panel.confirm_buttons[0].pressed.emit();await process_frame
    for slot in HubDeckAnalyzer.SLOTS:check("confirmed target only "+slot,ui.run.state.loadout[slot]==(uid if slot=="main_weapon" else loadout_before[slot]))
    check("all owned instances retained",ui.run.state.inventory==inventory_before)
    panel=ui.find_child("HubEquipmentPanel",true,false)
    check("successful refresh and selection",panel.selected_uid==uid and panel.preview.unchanged and panel.preview.after_items.main_weapon==candidate)
    check("new analysis agrees",panel.analyzer.analyze(ui.run.items_from_state()).hp==panel.preview.after.hp)
    var reload=CampaignController.new();reload.save_path=good_path
    check("existing save reload succeeds",reload.load_saved())
    check("existing save reload",reload.state.loadout==ui.run.state.loadout and JSON.parse_string(JSON.stringify(reload.state.inventory))==JSON.parse_string(JSON.stringify(ui.run.state.inventory)))
    save_before=FileAccess.get_file_as_string(good_path);panel.confirm_equipment()
    check("same equipment no write",FileAccess.get_file_as_string(good_path)==save_before)
    check("begin after swap",ui.run.begin(883219))
    check("battle after swap",ui.run.choose_route(0) and ui.run.battle!=null)
    var battle=ui.run.battle
    var battle_snapshot: String=JSON.stringify(battle.export_region1_state())
    service.compare(ui.run.items_from_state(),candidate)
    check("battle RNG snapshot untouched",JSON.stringify(battle.export_region1_state())==battle_snapshot)
    var played: bool=false
    for i in range(battle.hand.size()):
        if battle.can_use_card(i):
            played=battle.use_card(i,0);break
    check("actual Battle card resolves",played)
    while battle.is_hand_selection_active():battle.select_hand_for_pending(0)
    battle.end_player_turn()
    check("actual turn advances",battle.turn_number>=2 or battle.combat_over)
    main.queue_free();await process_frame
    print("HUB_B PASS=%d FAIL=%d"%[passed,failures.size()]);quit(0 if failures.is_empty() else 1)
