extends SceneTree
var passed: int=0
var failures: Array=[]
func check(title: String,ok: bool) -> void:
    if ok:passed+=1
    else:failures.append(title);print("FAIL "+title)
func _initialize() -> void:call_deferred("run_test")
func settle() -> void:
    for i in range(8):await process_frame
func run_test() -> void:
    if not (OS.get_environment("APPDATA").contains("step37_runs") or OS.get_environment("SCE_HUB_ISOLATED_TEST")=="1"):quit(2);return
    root.size=Vector2i(1280,900)
    var main=load("res://main.tscn").instantiate();root.add_child(main);await settle()
    var ui: Region1RunUI=main.region_run_ui
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    ui.run.save_path="user://readability_fixture.json"
    check("adopt",ui.run.adopt_initial(helper.make_items(ui.run.roller,517901)))
    var state: Dictionary=ui.run.state.duplicate(true);state.base_gold=10000;state.materials=30
    for i in range(20):
        for item in helper.make_items(ui.run.roller,718301+i*10000).values():state.inventory[str(item.instance_id)]=item
    helper.free();check("commit",ui.run._commit(state))
    ui.render();main.tab_container.current_tab=ui.get_index();await settle()
    ui.open_hub_page("equipment");await settle()
    var panel: HubEquipmentPanel=ui.hub_library
    var snapshot: String=JSON.stringify(ui.run.state)
    var save: String=FileAccess.get_file_as_string(ui.run.save_path)
    var mtime: int=FileAccess.get_modified_time(ui.run.save_path)
    var views: Array=[]
    for id in panel.analyzer.cards:
        var view=HubCardView.new();root.add_child(view);view.build(str(id),panel.analyzer);views.append(view)
    await settle()
    for view in views:
        var id: String=view.text.substr(0,4)
        check("formal text "+id,view.effect.get_parsed_text()==str(panel.analyzer.cards[id].text))
        check("cost metadata "+id,view.get_child(0).get_child(1).text.contains("Cost %d"%int(panel.analyzer.cards[id].cost)))
        view.queue_free()
    await settle()
    check("equipment screen navigation",ui.hub_page=="equipment" and ui.find_child("HubEquipmentViews",true,false)!=null)
    check("hidden legacy forge tab",not panel.tabs.tabs_visible and panel.tabs.current_tab<2)
    check("equipment page fits",ui.content.get_global_rect().end.y<=900 and panel.tabs.size.y>200)
    check("equipment internal scroll",panel.tabs.get_global_rect().end.x<=1280 and not ui.page_scroll.visible)
    var stats: Dictionary=panel.analyzer.analyze(ui.run.items_from_state())
    for field in ["attribute","weapon"]:
        var total: int=0
        for count in stats.distribution[field].values():total+=int(count)
        check(field+" total 24",total==24)
    check("SC inspector",int(stats.completed_sc)==int(ui.run.roller.inspect_deck(ui.run.items_from_state()).completed_sc))
    var uid: String=""
    for row in panel.visible_rows:
        if not bool(row.equipped):uid=str(row.uid);break
    panel.selected_uid=uid;panel.refresh_inventory();await settle()
    panel.inventory_list.get_v_scroll_bar().value=250;await settle()
    var scroll: float=panel.inventory_list.get_v_scroll_bar().value
    panel.tabs.current_tab=1;await settle();panel.tabs.current_tab=0;await settle()
    check("tab keeps selection scroll",panel.selected_uid==uid and absf(panel.inventory_list.get_v_scroll_bar().value-scroll)<1)
    check("preview state save mtime",snapshot==JSON.stringify(ui.run.state) and save==FileAccess.get_file_as_string(ui.run.save_path) and mtime==FileAccess.get_modified_time(ui.run.save_path))
    var identity: int=panel.get_instance_id()
    panel.confirm_equipment();await settle()
    check("equip partial update identity",ui.hub_library.get_instance_id()==identity)
    check("equip selection scroll",panel.selected_uid==uid and absf(panel.inventory_list.get_v_scroll_bar().value-scroll)<1)
    var forge: HubForgePanel=panel.tabs.get_child(2);forge.selected_uid=uid;forge.refresh_inventory();panel.tabs.current_tab=2;await settle()
    var forge_identity: int=forge.get_instance_id()
    forge.request_operation("enhance");forge.dialog.confirmed.emit();await settle()
    check("forge partial identity",ui.hub_library.get_instance_id()==identity and panel.tabs.get_child(2).get_instance_id()==forge_identity)
    check("forge selection funds updated",forge.selected_uid==uid and ui.hub_status.text.contains("%dG"%int(ui.run.state.base_gold)))
    forge.filters={"rarity":str(ui.run.state.inventory[uid].rarity),"search":uid,"sort":"hp"};forge.restore_filters(forge.filters)
    panel.filters={"rarity":str(ui.run.state.inventory[uid].rarity),"search":uid,"sort":"hp"};panel.restore_filters(panel.filters)
    ui.seed.value=4321;ui.render();await settle()
    check("full refresh filters selected",ui.hub_library.filters.search==uid and ui.hub_library.selected_uid==uid and ui.hub_library.filters.sort=="hp")
    check("forge filters restored",ui.hub_library.tabs.get_child(2).filters.search==uid and ui.hub_library.tabs.get_child(2).selected_uid==uid)
    check("seed retained",int(ui.seed.value)==4321)
    var reload=CampaignController.new();reload.save_path=ui.run.save_path
    check("save reload",reload.load_saved() and JSON.parse_string(JSON.stringify(reload.state))==JSON.parse_string(JSON.stringify(ui.run.state)))
    ui.run=reload;ui.render();await settle();forge=ui.hub_library.tabs.get_child(2)
    forge.selected_uid=uid;forge.refresh_inventory();forge.request_operation("reroll",0);forge.dialog.confirmed.emit();await settle()
    check("pending two columns",not forge.detail.get_parent().visible and forge.menu.size.x>700)
    ui.hub_library.tabs.current_tab=2;await settle()
    check("pending viewport",ui.content.get_global_rect().end.y<=900 and ui.hub_library.tabs.get_global_rect().end.x<=1280)
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        check("GPU candidates",root.get_texture().get_image().save_png("user://test_outputs/candidates.png")==OK)
    forge.resolve_choice(-1);await settle()
    check("pending resolved restores detail",forge.detail.get_parent().visible and ui.run.state.forge_pending.is_empty())
    main.queue_free();await settle()
    print("HUB_D PASS=%d FAIL=%d"%[passed,failures.size()]);quit(0 if failures.is_empty() else 1)
