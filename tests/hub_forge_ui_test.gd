extends SceneTree
var passed: int=0
var failures: Array=[]
var ui: Region1RunUI
var main
func check(title: String,ok: bool) -> void:
    if ok:passed+=1
    else:failures.append(title);print("FAIL "+title)
func eq(a,b) -> bool:return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func panel() -> HubForgePanel:return ui.find_child("鍛冶屋",true,false)
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
    if not OS.get_environment("APPDATA").contains("step37_runs"):quit(2);return
    root.size=Vector2i(1280,900)
    main=load("res://main.tscn").instantiate();root.add_child(main);await process_frame
    ui=main.region_run_ui;ui.run.save_path="user://forge_fixture.json"
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    check("fixture adoption",ui.run.adopt_initial(helper.make_items(ui.run.roller,517901)));helper.free()
    var state: Dictionary=ui.run.state.duplicate(true);state.base_gold=20000;state.materials=50
    var item: Dictionary=ui.run.roller.generate_item(str(ui.run.roller.get_templates_for_slot("offhand")[-1].EquipmentID),517908)
    var uid: String=str(item.instance_id);state.inventory[uid]=item
    check("fixture commit",ui.run._commit(state));ui.render();await process_frame
    ui.open_hub_page("forge");await process_frame
    var forge: HubForgePanel=panel();forge.selected_uid=uid;forge.refresh_inventory()
    # Inventory focus and bulk selection are separate. Single-click is detail-only.
    var clicked_index: int=-1
    for i in range(forge.paged_rows.size()):
        if str(forge.paged_rows[i].uid)==uid:clicked_index=i;break
    check("forge fixture is on current page",clicked_index>=0)
    if clicked_index>=0:
        forge.selected_uid=""
        forge.refresh_detail()
        var before_selection: String=JSON.stringify(ui.run.state)
        forge.inventory_list.item_selected.emit(clicked_index)
        check("forge click sets focused uid",forge.selected_uid==uid)
        check("forge click renders right detail",forge.detail.get_child_count()>2 and forge.detail.get_child(0).text==HubInventoryQuery.item_name(ui.run.state.inventory[uid]))
        check("forge click shows processing buttons",forge.operation_buttons.size()>=4)
        check("forge click shows selected highlight",forge.inventory_list.get_item_text(clicked_index).contains("▶ 詳細表示"))
        check("forge click shows selected name",forge.focused_selection_label.text.contains(HubInventoryQuery.item_name(ui.run.state.inventory[uid])))
        check("forge click is not bulk select",forge._valid_bulk_uids().is_empty())
        check("modal can open with no preselected items",not forge.bulk_review_button.disabled)
        forge._show_bulk_selection()
        check("modal is an interactive selection window",is_instance_valid(forge.bulk_review_dialog) and forge.bulk_review_dialog.title.contains("対象を選択"))
        check("modal lists uid",forge.bulk_modal_boxes.has(uid))
        if forge.bulk_modal_boxes.has(uid):
            var checkbox: CheckBox=forge.bulk_modal_boxes[uid]
            checkbox.button_pressed=true
            check("modal toggled selection",forge._valid_bulk_uids().has(uid) and forge.bulk_modal_commit.text.contains("1件"))
            check("modal lists planned material",forge.bulk_modal_summary.text.contains("素材"))
            checkbox.button_pressed=false
            check("modal can deselect",forge._valid_bulk_uids().is_empty() and forge.bulk_modal_commit.disabled)
            checkbox.button_pressed=true
        check("modal selection does not mutate save",before_selection==JSON.stringify(ui.run.state))
        if forge.bulk_modal_commit!=null and not forge.bulk_modal_commit.disabled:
            forge.bulk_modal_commit.pressed.emit()
            check("modal commit only opens final confirmation",is_instance_valid(forge.dialog) and forge.dialog.title=="一括分解の最終確認" and ui.run.state.inventory.has(uid))
            check("final confirmation is still non-mutating",before_selection==JSON.stringify(ui.run.state))
            forge.dialog.canceled.emit()
        forge.bulk_review_dialog.hide()
        forge._clear_bulk_selection()
        check("bulk clear leaves detail focus",forge.selected_uid==uid and forge.inventory_list.get_item_text(clicked_index).contains("▶ 詳細表示"))
        check("bulk clear count zero",forge._valid_bulk_uids().is_empty())
        check("forge click does not save/mutate",JSON.stringify(ui.run.state)==before_selection)
    var snapshot: String=JSON.stringify(ui.run.state)
    var bytes: String=FileAccess.get_file_as_string(ui.run.save_path)
    var mtime: int=FileAccess.get_modified_time(ui.run.save_path)
    for row in forge.visible_rows:
        forge.selected_uid=str(row.uid);forge.refresh_detail()
        for group in ["fixed_cards","random_cards"]:
            for i in range(2):check("formal effect in forge",forge.detail.get_node("ForgeCard_"+group+str(i)).text==forge.analyzer.card_description(str(row.item[group][i])))
    forge.selected_uid=uid;forge.refresh_detail()
    forge.request_operation("enhance");check("dialog before mutation",is_instance_valid(forge.dialog) and snapshot==JSON.stringify(ui.run.state))
    forge.dialog.canceled.emit();await process_frame
    check("selection preview cancel no save",snapshot==JSON.stringify(ui.run.state) and bytes==FileAccess.get_file_as_string(ui.run.save_path) and mtime==FileAccess.get_modified_time(ui.run.save_path))
    for blocker in ["gold","material","save","phase","generation","animation","pending"]:
        var before: Dictionary=ui.run.state.duplicate(true)
        if blocker=="gold":ui.run.state.base_gold=0
        if blocker=="material":ui.run.state.materials=0
        if blocker=="save":ui.run.save_blocked=true
        if blocker=="phase":ui.run.state.phase="route"
        if blocker=="generation":main.generation_job=RefCounted.new()
        if blocker=="animation":ui.animation_busy=true
        if blocker=="pending":ui.run.state.forge_pending={"uid":uid,"slot":0,"choices":["C001","C002"]}
        var blocked: String=JSON.stringify(ui.run.state)
        check("disabled reason "+blocker,forge.reason("enhance")!="")
        forge.request_operation("enhance")
        check("blocked stale operation "+blocker,JSON.stringify(ui.run.state)==blocked and bytes==FileAccess.get_file_as_string(ui.run.save_path))
        ui.run.state=before;ui.run.save_blocked=false;main.generation_job=null;ui.animation_busy=false
    var template: Dictionary=ui.run.roller.templates[str(item.equipment_id)]
    var save_path: String=ui.run.save_path
    ui.run.save_path="user://missing_directory/forge.json"
    forge.request_operation("enhance");forge.dialog.confirmed.emit();await process_frame
    check("failed forge preserves state and file",JSON.stringify(ui.run.state)==snapshot and FileAccess.get_file_as_string(save_path)==bytes and ui.run.notice!="")
    check("existing failure notice displayed",forge.menu.get_child(-1).text==ui.run.notice)
    ui.run.save_path=save_path
    var gold: int=int(ui.run.state.base_gold);var materials: int=int(ui.run.state.materials)
    var inventory: Dictionary=ui.run.state.inventory.duplicate(true)
    forge.request_operation("enhance");forge.dialog.confirmed.emit();await process_frame
    check("enhance cost100 material1",int(ui.run.state.base_gold)==gold-100 and int(ui.run.state.materials)==materials-1)
    check("enhance formula",int(ui.run.state.inventory[uid].effective_hp)==int(item.base_hp)+int(template.HP_Per_Enhance) and int(ui.run.state.inventory[uid].enhance_level)==1)
    check("enhance cards and inventory retained",ui.run.state.inventory[uid].cards==item.cards and ui.run.state.inventory.size()==inventory.size())
    forge=panel();forge.selected_uid=uid;forge.refresh_inventory()
    gold=int(ui.run.state.base_gold);materials=int(ui.run.state.materials)
    var sockets: int=int(ui.run.state.inventory[uid].get("socket_count",template.InitialSocketMin))
    if sockets<int(template.SocketCap):
        forge.request_operation("socket");forge.dialog.confirmed.emit();await process_frame
        check("socket exact cost",int(ui.run.state.base_gold)==gold-(250+sockets*150) and int(ui.run.state.materials)==materials-1)
        check("socket increments",int(ui.run.state.inventory[uid].socket_count)==sockets+1)
    else:check("socket fixture at cap",forge.reason("socket")!="")
    # Exercise both random slots and all three resolution options through the real UI.
    for slot in range(2):
        for choice in [-1,0,1]:
            forge=panel();forge.selected_uid=uid;forge.refresh_inventory()
            var before_item: Dictionary=ui.run.state.inventory[uid].duplicate(true)
            gold=int(ui.run.state.base_gold);materials=int(ui.run.state.materials)
            forge.request_operation("reroll",slot)
            check("reroll cost confirmation",forge.dialog.dialog_text.contains("250G") and forge.dialog.dialog_text.contains("戻りません"))
            forge.dialog.confirmed.emit();await process_frame
            check("reroll fee counter",int(ui.run.state.base_gold)==gold-250 and int(ui.run.state.materials)==materials-1 and int(ui.run.state.inventory[uid].reroll_counts[slot])==int(before_item.reroll_counts[slot])+1)
            check("fixed cards untouched before resolve",ui.run.state.inventory[uid].fixed_cards==before_item.fixed_cards and ui.run.state.inventory[uid].random_cards==before_item.random_cards)
            check("pending persisted",not ui.run.state.forge_pending.is_empty())
            var reload=CampaignController.new();reload.save_path=ui.run.save_path
            check("pending reload",reload.load_saved() and eq(reload.state.forge_pending,ui.run.state.forge_pending))
            ui.run=reload;ui.render();await process_frame;forge=panel()
            check("pending screen restored",forge.selected_uid==uid and ui.find_child("HubEquipmentPanel",true,false).tabs.current_tab==2)
            snapshot=JSON.stringify(ui.run.state);bytes=FileAccess.get_file_as_string(ui.run.save_path);mtime=FileAccess.get_modified_time(ui.run.save_path)
            for i in range(2):
                var report: Dictionary=forge.candidate_preview(i)
                check("non-equipped deck unchanged",not report.equipped and report.before.deck==report.after.deck)
                check("candidate fixed unchanged",eq(report.item.fixed_cards,before_item.fixed_cards))
                check("candidate target only",str(report.item.random_cards[1-slot])==str(before_item.random_cards[1-slot]))
            forge.refresh_detail()
            check("candidate previews no write",snapshot==JSON.stringify(ui.run.state) and bytes==FileAccess.get_file_as_string(ui.run.save_path) and mtime==FileAccess.get_modified_time(ui.run.save_path))
            if slot==0 and choice==-1:
                ui.run.save_blocked=true;forge.resolve_choice(0)
                check("pending blocked-save resolution refuses",snapshot==JSON.stringify(ui.run.state) and bytes==FileAccess.get_file_as_string(ui.run.save_path))
                ui.run.save_blocked=false;ui.run.save_path="user://missing_directory/resolve.json";forge.resolve_choice(0)
                check("failed resolve preserves pending",snapshot==JSON.stringify(ui.run.state) and ui.run.notice!="")
                ui.run.save_path=save_path
            var choices: Array=ui.run.state.forge_pending.choices.duplicate()
            forge.resolve_choice(choice);await process_frame
            check("resolve pending cleared",ui.run.state.forge_pending.is_empty())
            check("resolve only random target",str(ui.run.state.inventory[uid].random_cards[slot])==(str(before_item.random_cards[slot]) if choice<0 else str(choices[choice])) and str(ui.run.state.inventory[uid].random_cards[1-slot])==str(before_item.random_cards[1-slot]))
            check("resolve fixed unchanged",eq(ui.run.state.inventory[uid].fixed_cards,before_item.fixed_cards))
            check("keep or candidate no refund",int(ui.run.state.base_gold)==gold-250 and int(ui.run.state.materials)==materials-1 and int(ui.run.state.inventory[uid].reroll_counts[slot])==int(before_item.reroll_counts[slot])+1)
    forge=panel();forge.selected_uid=uid;forge.refresh_inventory()
    check("both random slots at limit",forge.reason("reroll",0)!="" and forge.reason("reroll",1)!="")
    for action in ["enhance","socket"]:
        while forge.reason(action)=="":
            forge.request_operation(action);forge.dialog.confirmed.emit();await process_frame;forge=panel();forge.selected_uid=uid;forge.refresh_inventory()
        check("cap disabled "+action,forge.reason(action).contains("上限"))
    # A worn item has a real preview of its random-card replacement within the24 deck.
    var worn_uid: String=str(ui.run.state.loadout.offhand)
    forge.selected_uid=worn_uid;forge.refresh_inventory()
    check("equipped dismantle refused",forge.reason("dismantle")!="")
    forge.request_operation("reroll",0);forge.dialog.confirmed.emit();await process_frame;forge=panel()
    snapshot=JSON.stringify(ui.run.state);bytes=FileAccess.get_file_as_string(ui.run.save_path)
    for i in range(2):
        var report: Dictionary=forge.candidate_preview(i)
        check("worn replacement actual24",report.equipped and report.before.deck.size()==24 and report.after.deck.size()==24 and report.before.deck!=report.after.deck)
        var replacement_items: Dictionary=ui.run.items_from_state();replacement_items.offhand=report.item
        check("preview SC inspect agrees",report.after.completed_sc==forge.analyzer.roller.inspect_deck(replacement_items).completed_sc)
    check("worn comparison state save immutable",snapshot==JSON.stringify(ui.run.state) and bytes==FileAccess.get_file_as_string(ui.run.save_path))
    forge.resolve_choice(-1);await process_frame;forge=panel();forge.selected_uid=uid;forge.refresh_inventory()
    var loadout: Dictionary=ui.run.state.loadout.duplicate(true)
    var deck: Array=forge.analyzer.analyze(ui.run.items_from_state()).deck.duplicate()
    materials=int(ui.run.state.materials);var expected: int=forge.material_yield(ui.run.state.inventory[uid])
    forge.request_operation("dismantle")
    check("dedicated dismantle dialog UID name yield",forge.dialog.title=="装備分解の確認" and forge.dialog.dialog_text.contains(uid) and forge.dialog.dialog_text.contains(HubInventoryQuery.item_name(item)) and forge.dialog.dialog_text.contains("素材%d"%expected))
    check("before confirm item exists",ui.run.state.inventory.has(uid))
    forge.dialog.confirmed.emit();await process_frame
    check("dismantle removes only target",not ui.run.state.inventory.has(uid) and ui.run.state.inventory.size()==inventory.size()-1)
    check("dismantle materials",int(ui.run.state.materials)==materials+expected)
    check("loadout deck retained",eq(ui.run.state.loadout,loadout) and panel().analyzer.analyze(ui.run.items_from_state()).deck==deck)
    check("dismantle selection cleared",panel().selected_uid=="")
    check("run begin",ui.run.begin(883219));ui.render();await process_frame
    check("forge absent in run",panel()==null)
    check("run core forge refuses",not ui.run.forge(worn_uid,"enhance"))
    check("battle entry",ui.run.choose_route(0) and ui.run.battle!=null)
    var battle=ui.run.battle;var turn: int=battle.turn_number;battle.end_player_turn()
    check("Battle Core turn after forge",battle.turn_number==turn+1 or battle.combat_over)
    main.queue_free();await process_frame
    print("HUB_C PASS=%d FAIL=%d"%[passed,failures.size()]);quit(0 if failures.is_empty() else 1)
