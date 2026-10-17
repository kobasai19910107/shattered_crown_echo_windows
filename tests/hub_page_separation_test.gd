extends SceneTree
var passes: int=0
var fails: Array=[]
func check(label: String,condition: bool) -> void:
    if condition:passes+=1
    else:fails.append(label);print("FAIL "+label)
func _initialize() -> void:call_deferred("run_tests")
func settle() -> void:
    for i in range(5):await process_frame
func run_tests() -> void:
    # Never touch a real user's save. Run with an isolated APPDATA / user://.
    if OS.get_environment("SCE_HUB_ISOLATED_TEST")!="1":
        printerr("SCE_HUB_ISOLATED_TEST=1 and isolated APPDATA required")
        quit(2);return
    root.size=Vector2i(1280,900)
    var main=load("res://main.tscn").instantiate();root.add_child(main);await settle()
    var ui: Region1RunUI=main.region_run_ui
    ui.run.save_path="user://hub_split_fixture.json"
    var fixture=load("res://tests/hub_inventory_analysis_test.gd").new()
    check("fixture adopted",ui.run.adopt_initial(fixture.make_items(ui.run.roller,517901)))
    fixture.free()
    ui.render();main.tab_container.current_tab=ui.get_index();await settle()
    check("home default",ui.hub_page=="home" and ui.find_child("HubHomeDestinations",true,false)!=null)
    check("no equipment panel on home",ui.find_child("HubEquipmentPanel",true,false)==null)
    check("no departure on home",ui.find_child("SoloDepartureButton",true,false)==null)
    var state: String=JSON.stringify(ui.run.state)
    var save: String=FileAccess.get_file_as_string(ui.run.save_path)
    ui.open_hub_page("equipment");await settle()
    var library: HubEquipmentPanel=ui.find_child("HubEquipmentPanel",true,false)
    check("equipment standalone",ui.hub_page=="equipment" and library!=null and not library.tabs.tabs_visible and library.tabs.current_tab==0)
    check("equipment subnavigation",ui.find_child("HubEquipmentViews",true,false)!=null)
    check("forge and departure hidden from equipment",ui.find_child("SoloDepartureButton",true,false)==null)
    ui._select_equipment_view(1,ui.find_child("HubEquipmentViews",true,false));await settle()
    check("recommended deck shows",library.tabs.current_tab==1 and library.find_child("OwnedLoadoutRecommendations",true,false)!=null)
    var deck_section: VBoxContainer=library.deck_box
    var current_idx: int=-1
    var recommended_idx: int=-1
    for i in range(deck_section.get_child_count()):
        if deck_section.get_child(i).name=="CurrentDeckAnalysis":current_idx=i
        if deck_section.get_child(i).name=="OwnedLoadoutRecommendations":recommended_idx=i
    check("deck analysis above recommendations",current_idx>=0 and recommended_idx>current_idx)
    check("deck analysis expanded at top",current_idx>=0 and deck_section.get_child(current_idx).visible)

    check("standalone comparison tab removed",library.tabs.get_tab_count()==4 and ui.find_child("EquipmentView_2",true,false)==null)
    ui.open_hub_page("forge");await settle()
    library=ui.find_child("HubEquipmentPanel",true,false)
    check("forge standalone",ui.hub_page=="forge" and library!=null and library.tabs.current_tab==2 and not library.tabs.tabs_visible)
    check("equipment views hidden in forge",ui.find_child("HubEquipmentViews",true,false)==null)
    ui.open_hub_page("merchant");await settle()
    check("merchant separate",ui.hub_page=="merchant" and ui.find_child("HubEquipmentPanel",true,false)==null)
    check("merchant buy/sell tabs active",ui.find_child("HubMerchantTabs",true,false)!=null and ui.find_child("SoloDepartureButton",true,false)==null)
    check("merchant stock saved on first opening",ui.run.state.get("hub_stock",[]).size()==3)
    # First merchant visit intentionally generates persisted stock, unlike a pure page switch.
    state=JSON.stringify(ui.run.state)
    save=FileAccess.get_file_as_string(ui.run.save_path)
    ui.open_hub_page("solo");await settle()
    check("solo page separate",ui.hub_page=="solo" and ui.find_child("SoloDepartureButton",true,false)!=null)
    check("solo has region and deck info",ui.find_child("SoloRegionSelector",true,false)!=null and ui.find_child("SoloLoadoutSummary",true,false)!=null)
    check("solo no forge/inventory",ui.find_child("HubEquipmentPanel",true,false)==null)
    ui.open_hub_page("home");await settle()
    check("return home",ui.hub_page=="home")
    check("navigation never saves",state==JSON.stringify(ui.run.state) and save==FileAccess.get_file_as_string(ui.run.save_path))
    var pending=ui.run.state.duplicate(true)
    pending.forge_pending={"uid":str(pending.loadout.main_weapon),"slot":0,"choices":["C001","C002"]}
    ui.run.state=pending
    ui.render();await settle()
    check("pending forces forge",ui.hub_page=="forge" and ui.hub_library.tabs.current_tab==2)
    ui.open_hub_page("home");await settle()
    check("pending blocks leaving forge",ui.hub_page=="forge")
    main.queue_free();await process_frame
    print("HUB_PAGES PASS=%d FAIL=%d"%[passes,fails.size()]);quit(0 if fails.is_empty() else 1)
