extends SceneTree

# godot --headless --path . --script res://tests/ui_feedback_smoke_test.gd
# Isolated fixture, never uses or changes campaign's default save file.
var checks: int=0
var failures: int=0

func test(ok: bool, description: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error("UI FEEDBACK FAIL: "+description)
    else:print("UI FEEDBACK PASS: "+description)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var run=Region1RunController.new()
    run.save_path="user://ui_feedback_isolated_test.json"
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    var items: Dictionary=helper.make_items(run.roller,517901)
    test(run.adopt_initial(items),"six equipped fixture items")
    var next: Dictionary=run.state.duplicate(true)
    for i in range(12):
        var result: Dictionary=helper.make_items(run.roller,617901+i*10000)
        for item in result.values():
            next.inventory[str(item.instance_id)]=item
    next.base_gold=20000
    next.materials=50
    test(run._commit(next),"unworn fixture inventory")
    var panel=HubEquipmentPanel.new()
    root.add_child(panel)
    panel.build(run)
    await process_frame
    test(panel.inventory_list.max_columns==2,"two-column warehouse")
    test(panel.inventory_list.item_count==8 and panel.visible_rows.size()>8,"paged warehouse")
    panel.next_page.pressed.emit()
    test(panel.inventory_page==1,"page change")
    var forge: HubForgePanel=panel.tabs.get_child(2)
    test(forge.inventory_list.select_mode==ItemList.SELECT_MULTI,"forge multi selection")
    var unwear: Array[String]=[]
    for uid in run.state.inventory:
        if not run.state.loadout.values().has(uid):unwear.append(str(uid))
    test(unwear.size()>=2,"two or more unworn pieces")
    forge.selected_uid=unwear[0]
    var pool_before: String=JSON.stringify(run.state)
    var pool: Array[String]=forge._reroll_pool(0)
    test(JSON.stringify(run.state)==pool_before,"eligibility preview does not mutate run state")
    var valid_pool: bool=true
    for id in pool:
        if run.state.inventory[unwear[0]].cards.has(id):valid_pool=false
    test(valid_pool,"pool excludes already attached card IDs")
    var mixed: Array[String]=[unwear[0],str(run.state.loadout.main_weapon)]
    test(not run.dismantle_many(mixed) and JSON.stringify(run.state)==pool_before,"atomic batch rejects worn equipment")
    var valid_uids: Array[String]=[unwear[0],unwear[1]]
    var expected: int=int(run.state.materials)
    for uid in valid_uids:
        expected+=Region1RunController.RARITIES.find(str(run.state.inventory[uid].rarity))+1
    test(run.dismantle_many(valid_uids),"atomic multi dismantle commits once")
    test(int(run.state.materials)==expected,"material yield sum")
    test(not run.state.inventory.has(valid_uids[0]) and not run.state.inventory.has(valid_uids[1]),"both pieces removed")
    test(run.state.loadout.size()==6,"all equipped pieces preserved")
    panel.free()
    helper.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(run.save_path))
    print("UI FEEDBACK Smoke: %d PASS / %d FAIL"%[checks-failures,failures])
    quit(0 if failures==0 else 1)
