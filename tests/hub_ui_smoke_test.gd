extends SceneTree
var passed: int=0
var failures: Array=[]
func check(label: String,ok: bool) -> void:
    if ok:passed+=1
    else:failures.append(label);print("FAIL "+label)
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
    # Main restores user data: only run this scene in the established isolated launcher.
    if not OS.get_environment("APPDATA").contains("step37_runs"):
        printerr("Use Invoke-SceValidation.ps1 with isolated APPDATA for this test.");quit(2);return
    root.size=Vector2i(1280,900)
    var main=load("res://main.tscn").instantiate();root.add_child(main);await process_frame
    var ui: Region1RunUI=main.region_run_ui
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    var items: Dictionary=helper.make_items(ui.run.roller,981731);helper.free()
    ui.run.save_path="user://hub_phase_a_fixture.json"
    check("fixture adopted through existing commit",ui.run.adopt_initial(items))
    var before: String=JSON.stringify(ui.run.state)
    var save_before: String=FileAccess.get_file_as_string(ui.run.save_path)
    var save_time: int=FileAccess.get_modified_time(ui.run.save_path)
    ui.render();await process_frame
    ui.open_hub_page("equipment");await process_frame
    var panel: HubEquipmentPanel=ui.find_child("HubEquipmentPanel",true,false)
    check("real Campaign hub library",panel!=null and ui is CampaignUI and ui.run is CampaignController)
    check("all six owned instances displayed",panel.inventory_list.item_count==6)
    for i in range(6):
        panel.inventory_list.select(i);panel.inventory_list.item_selected.emit(i)
        var row: Dictionary=panel.visible_rows[i]
        for id in row.item.cards:
            var text: HubCardView=panel.detail.get_node("Card_"+str(id))
            check("official full text in detail "+str(id),text.text.ends_with(str(panel.analyzer.cards[str(id)].text)))
    for key in ["slot","rolled_attribute","card_attribute","card_weapon","rarity","sort"]:
        var dropdown: OptionButton=panel.find_child("Filter_"+key,true,false)
        check("filter UI "+key,dropdown!=null)
        for i in range(dropdown.item_count):dropdown.select(i);dropdown.item_selected.emit(i)
        dropdown.select(0);dropdown.item_selected.emit(0)
    var search: LineEdit=panel.find_child("InventorySearch",true,false)
    search.text="NOT_FOUND";search.text_changed.emit(search.text)
    check("empty filtered UI",panel.inventory_list.item_count==0 and panel.selected_uid=="")
    search.text="";search.text_changed.emit(search.text)
    check("filter reset restores all",panel.inventory_list.item_count==6)
    panel.tabs.current_tab=1;await process_frame;panel.tabs.current_tab=0
    check("view interactions preserve entire state",JSON.stringify(ui.run.state)==before)
    check("view interactions preserve save bytes and mtime",FileAccess.get_file_as_string(ui.run.save_path)==save_before and FileAccess.get_modified_time(ui.run.save_path)==save_time)
    main.generation_job=RefCounted.new()
    panel.inventory_list.item_selected.emit(0)
    check("generation-time viewing cannot write",JSON.stringify(ui.run.state)==before and FileAccess.get_file_as_string(ui.run.save_path)==save_before)
    main.generation_job=null
    ui.run.save_blocked=true;panel.refresh_inventory()
    check("blocked-save viewing cannot write",JSON.stringify(ui.run.state)==before and FileAccess.get_file_as_string(ui.run.save_path)==save_before)
    ui.run.save_blocked=false
    check("begin unchanged",ui.run.begin(883219));ui.render();await process_frame
    check("library absent during run",ui.find_child("HubEquipmentPanel",true,false)==null)
    check("real battle entry",ui.run.choose_route(0))
    var battle_before: String=JSON.stringify(ui.run.battle.export_region1_state())
    var run_before: String=JSON.stringify(ui.run.state)
    var analysis=HubDeckAnalyzer.new();analysis.analyze(ui.run.items_from_state())
    check("analysis cannot mutate battle or RNG",JSON.stringify(ui.run.battle.export_region1_state())==battle_before and JSON.stringify(ui.run.state)==run_before)
    ui.render();await process_frame
    check("library absent during battle",ui.find_child("HubEquipmentPanel",true,false)==null)
    main.queue_free();await process_frame
    print("HUB_UI PASS=%d FAIL=%d"%[passed,failures.size()]);quit(0 if failures.is_empty() else 1)

