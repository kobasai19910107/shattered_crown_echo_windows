extends SceneTree
const OUT="user://test_outputs/"
var passed: int=0
var failures: Array=[]
func check(title: String,ok: bool) -> void:
    if ok:passed+=1
    else:failures.append(title);print("FAIL "+title)
func _initialize() -> void:call_deferred("run_test")
func settle() -> void:
    for i in range(8):await process_frame
func capture(title: String) -> void:
    if DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    check("GPU "+title,root.get_texture().get_image().save_png(OUT+title+".png")==OK)
func run_test() -> void:
    if not (OS.get_environment("APPDATA").contains("step37_runs") or OS.get_environment("SCE_HUB_ISOLATED_TEST")=="1"):quit(2);return
    root.size=Vector2i(1280,900)
    var main=load("res://main.tscn").instantiate();root.add_child(main);await settle()
    var ui: Region1RunUI=main.region_run_ui
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    ui.run.save_path="user://hub_layout_fixture.json";check("fixture adoption",ui.run.adopt_initial(helper.make_items(ui.run.roller,517901)))
    var next: Dictionary=ui.run.state.duplicate(true)
    for i in range(20):
        var items: Dictionary=helper.make_items(ui.run.roller,718301+i*10000)
        for item in items.values():next.inventory[str(item.instance_id)]=item
    helper.free();next.base_gold=5000;next.materials=30;check("126 inventory fixture",ui.run._commit(next))
    ui.render();main.tab_container.current_tab=ui.get_index();await settle()
    ui.open_hub_page("equipment");await settle()
    var panel: HubEquipmentPanel=ui.find_child("HubEquipmentPanel",true,false)
    for i in range(panel.paged_rows.size()):
        if not bool(panel.paged_rows[i].equipped):panel.inventory_list.item_selected.emit(i);break
    await settle()
    check("missing fields not inferred",panel.item_summary({"name":"fixture","base_hp":1},false).contains("未設定"))
    var snapshot: String=JSON.stringify(ui.run.state)
    var bytes: String=FileAccess.get_file_as_string(ui.run.save_path)
    check("outer is non-scroll container",ui.get_class()=="VBoxContainer" and not ui.page_scroll.visible)
    for tab in range(panel.tabs.get_tab_count()):
        panel.tabs.current_tab=tab;await settle()
        print("LAYOUT tab%d ui=%s content=%s tabs=%s"%[tab,str(ui.get_global_rect()),str(ui.content.get_global_rect()),str(panel.tabs.get_global_rect())])
        check("viewport fit tab%d"%tab,ui.content.get_global_rect().end.y<=900 and panel.tabs.get_global_rect().end.y<=900 and panel.tabs.get_global_rect().end.x<=1280 and panel.tabs.size.y>200)
        if tab==3:
            var legacy: VBoxContainer=panel.tabs.get_child(3).get_child(0)
            for child in legacy.get_children():
                if child is Label:check("legacy horizontal caption",child.size.x>400 and child.size.y<100)
        await capture("tab%d"%tab)
    panel.tabs.current_tab=0;await settle()
    check("inventory 2-column page not endless scroll",panel.inventory_list.max_columns==2 and panel.inventory_list.item_count==8 and panel.visible_rows.size()==126)
    check("page has next navigation",not panel.next_page.disabled)
    for i in range(panel.paged_rows.size()):
        var row: Dictionary=panel.paged_rows[i]
        check("tile attribute and weapon",panel.inventory_list.get_item_text(i).contains(str(row.item.rolled_attribute)) and panel.inventory_list.get_item_text(i).contains(str(row.item.affinity_weapon)))
    panel.next_page.pressed.emit();await settle()
    check("page navigation",panel.inventory_page==1 and panel.inventory_list.item_count==8)
    panel.previous_page.pressed.emit();await settle()
    check("return first page",panel.inventory_page==0)
    var detail_scroll: ScrollContainer=panel.detail.get_parent()
    detail_scroll.scroll_vertical=100000;await settle()
    check("detail internal scroll",detail_scroll.scroll_vertical>0 and panel.detail.size.x>=400)
    var selected: Dictionary=ui.run.state.inventory[panel.selected_uid]
    var detail_text: String=""
    for child in panel.detail.get_children():
        if child is Label:detail_text+=child.text
    check("detail real attribute affinity",detail_text.contains(str(selected.rolled_attribute)) and detail_text.contains(str(selected.affinity_weapon)))
    panel.tabs.current_tab=0;await settle()
    var grid: GridContainer=panel.detail.find_child("WarehouseComparisonMetrics",true,false)
    var columns: HBoxContainer=panel.detail.find_child("WarehouseSideBySideComparison",true,false)
    check("inline comparison two columns",grid!=null and grid.columns==4 and columns!=null and columns.get_child_count()==2)
    var compare_scroll: ScrollContainer=panel.detail.get_parent()
    compare_scroll.scroll_vertical=100000;await settle()
    check("warehouse detail scroll keeps comparison",compare_scroll.scroll_vertical>0)
    await capture("comparison_inline")
    var forge: HubForgePanel=ui.find_child("鍛冶屋",true,false)
    panel.tabs.current_tab=2;forge.selected_uid=panel.selected_uid;forge.refresh_inventory();await settle()
    check("forge shares item summary",forge.inventory_list.get_item_text(0).contains(" / "))
    var forge_text: String=""
    for child in forge.detail.get_children():
        if child is Label:forge_text+=child.text
    check("forge attribute affinity",forge_text.contains(str(selected.rolled_attribute)) and forge_text.contains(str(selected.affinity_weapon)))
    await capture("forge_selected")
    check("layout actions no state save write",snapshot==JSON.stringify(ui.run.state) and bytes==FileAccess.get_file_as_string(ui.run.save_path))
    # Rendering-only fixture: longer cleared-region buttons and a multiline notice.
    var completed: Dictionary=ui.run.state.duplicate(true)
    completed.region_progress=[4,4,4,4,4,4];completed.bosses=4;completed.campaign_complete=true;completed.region2_unlocked=true
    ui.run.state=completed;ui.run.notice="表示確認用の通知です。\nこの通知は保存や正式仕様を変更しません。"
    ui.render();await settle()
    panel=ui.find_child("HubEquipmentPanel",true,false)
    check("completed campaign with notice fits",ui.content.get_global_rect().end.y<=900 and panel.tabs.get_global_rect().end.y<=900 and panel.tabs.size.y>=200)
    await capture("completed_notice")
    main.queue_free();await process_frame
    print("HUB_LAYOUT PASS=%d FAIL=%d"%[passed,failures.size()]);quit(0 if failures.is_empty() else 1)

