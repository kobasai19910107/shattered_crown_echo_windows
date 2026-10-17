class_name HubForgePanel
extends HubEquipmentPanel

var menu: VBoxContainer
var operation_buttons: Array[Button]=[]
var dialog: ConfirmationDialog
var pool_dialog: AcceptDialog
var bulk_hint: Label
var bulk_selected_uids: Dictionary={}
var restoring_bulk_selection: bool=false
var focused_selection_label: Label
var bulk_review_dialog: AcceptDialog
var bulk_review_button: Button
var bulk_execute_button: Button
var bulk_modal_summary: Label
var bulk_modal_commit: Button
var bulk_modal_boxes: Dictionary={}

func build(controller: Region1RunController) -> void:
    run=controller;name="鍛冶屋";size_flags_horizontal=Control.SIZE_EXPAND_FILL
    label("鍛冶屋 — 選択・比較だけでは保存されません",self,22)
    var columns=HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",16);add_child(columns)
    var sidebar=VBoxContainer.new();sidebar.custom_minimum_size.x=330;columns.add_child(sidebar)
    inventory_page_size=8
    tile_mode=false
    label("部位別タブ",sidebar,16)
    var slot_row=HFlowContainer.new();slot_row.name="ForgeSlotTabs";sidebar.add_child(slot_row)
    for slot in [""]+HubDeckAnalyzer.SLOTS:
        var slot_button=Button.new();slot_button.name="ForgeSlot_"+(slot if slot!="" else "all")
        slot_button.toggle_mode=true
        slot_button.pressed.connect(select_slot.bind(str(slot)))
        slot_row.add_child(slot_button)
        slot_buttons[str(slot)]=slot_button
    add_filter("部位","slot",HubDeckAnalyzer.SLOTS,sidebar,SLOT_NAMES)
    add_filter("レアリティ","rarity",Region1RunController.RARITIES,sidebar)
    add_filter("並び順","sort",["rarity","hp","name"],sidebar,{"rarity":"レアリティ順","hp":"HP順","name":"装備名順"},false)
    var search=LineEdit.new();search.name="ForgeSearch";search.placeholder_text="装備名 / UID / カードID";sidebar.add_child(search)
    search.text_changed.connect(func(text: String):filters.search=text;reset_page_and_refresh())
    count_label=label("",sidebar,14)
    focused_selection_label=label("▶ 詳細表示中：なし",sidebar,15)
    focused_selection_label.name="ForgeFocusedItem"
    focused_selection_label.modulate=Color("90d7ff")
    _build_page_controls(sidebar)
    inventory_list=ItemList.new();inventory_list.name="ForgeInventory";inventory_list.custom_minimum_size.y=80;inventory_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_child(inventory_list)
    inventory_list.icon_mode=ItemList.ICON_MODE_TOP;inventory_list.max_text_lines=3;inventory_list.add_theme_font_size_override("font_size",14)
    # Main inventory selects only the detailed item; bulk selection lives in a modal.
    inventory_list.select_mode=ItemList.SELECT_SINGLE
    inventory_list.max_columns=1
    inventory_list.item_selected.connect(_focus_forge_item)
    # Also allow clicking an already-highlighted row to refresh focus.
    inventory_list.item_clicked.connect(_on_forge_item_clicked)
    label("一覧クリック＝詳細表示のみ。分解する品は別ウィンドウで選択します。",sidebar,12)
    bulk_hint=label("分解候補：0件",sidebar,13)
    bulk_hint.name="ForgeBulkSelectionSummary"
    bulk_hint.modulate=Color("ffcf9b")
    bulk_review_button=Button.new()
    bulk_review_button.name="ForgeBulkSelectionReview"
    bulk_review_button.text="対象一覧を見る・分解を選択"
    bulk_review_button.custom_minimum_size.y=42
    sidebar.add_child(bulk_review_button)
    bulk_review_button.pressed.connect(_show_bulk_selection)
    detail=scroll_box(columns,"ForgeDetail",1.0)
    menu=scroll_box(columns,"ForgeMenu",1.0)
    if not run.state.forge_pending.is_empty():selected_uid=str(run.state.forge_pending.uid)
    refresh_inventory()

func scroll_box(parent: Node,title: String,ratio: float) -> VBoxContainer:
    var scroll=ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_stretch_ratio=ratio;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(scroll)
    var box=VBoxContainer.new();box.name=title;box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",12);scroll.add_child(box);return box

func refresh_inventory() -> void:
    super.refresh_inventory()
    _update_bulk_hint()
    _refresh_forge_focus_visuals()
    # A pending choice remains visible even if inventory filters hide its item.
    if not run.state.forge_pending.is_empty():selected_uid=str(run.state.forge_pending.uid);refresh_detail()

# Keep detail focus separate from the multi-select set used for bulk dismantling.
# A normal click must always update the right-hand item and forge operations.
func _focus_forge_item(index: int) -> void:
    if index<0 or index>=paged_rows.size():return
    var uid: String=str(paged_rows[index].uid)
    if not run.state.inventory.has(uid):return
    if selected_uid==uid and detail.get_child_count()>1:
        _refresh_forge_focus_visuals()
        return
    selected_uid=uid
    _refresh_forge_focus_visuals()
    refresh_detail()

func _on_forge_item_clicked(index: int, _position: Vector2, mouse_button_index: int) -> void:
    if mouse_button_index==MOUSE_BUTTON_LEFT:
        _focus_forge_item(index)

func _refresh_forge_focus_visuals() -> void:
    if inventory_list==null or run==null:return
    var selected_name: String=""
    if run.state.inventory.has(selected_uid):
        selected_name=HubInventoryQuery.item_name(run.state.inventory[selected_uid])
    if focused_selection_label!=null:
        focused_selection_label.text="▶ 詳細表示中："+selected_name if selected_name!="" else "▶ 詳細表示中：なし（装備をクリック）"
    for i in range(paged_rows.size()):
        if i>=inventory_list.item_count:break
        var row: Dictionary=paged_rows[i]
        var uid: String=str(row.uid)
        var focused: bool=uid==selected_uid
        inventory_list.set_item_text(i,("▶ 詳細表示  " if focused else "")+item_summary(row.item,bool(row.equipped)))
        inventory_list.set_item_custom_fg_color(i,Color("90d7ff") if focused else HubCardView.tone(str(row.item.get("rarity",""))))
        inventory_list.set_item_custom_bg_color(i,Color("34475b") if focused else Color.TRANSPARENT)

func refresh_detail() -> void:
    operation_buttons.clear()
    detail.get_parent().visible=run.state.forge_pending.is_empty()
    for box in [detail,menu]:
        for child in box.get_children():box.remove_child(child);child.queue_free()
    label("所持 %dG / 素材%d"%[int(run.state.base_gold),int(run.state.materials)],menu,20)
    if not run.state.inventory.has(selected_uid):label("左の所持装備を選択してください。",detail,20);return
    var item: Dictionary=run.state.inventory[selected_uid]
    var template: Dictionary=run.roller.templates.get(str(item.equipment_id),{})
    label(HubInventoryQuery.item_name(item),detail,22)
    label("抽選属性 %s / 武器Affinity %s"%[str(item.get("rolled_attribute","未設定")),str(item.get("affinity_weapon","未設定"))],detail)
    label("UID %s\n%s / %s%s\nHP %d / 強化 Lv%d/%d"%[selected_uid,SLOT_NAMES[str(item.slot)],str(item.rarity)," / 装備中" if run.state.loadout.values().has(selected_uid) else "",int(item.get("effective_hp",item.base_hp)),int(item.get("enhance_level",0)),int(template.get("EnhanceCap",0))],detail)
    var sockets: int=int(item.get("socket_count",template.get("InitialSocketMin",0)))
    var cap: int=int(template.get("SocketCap",0))
    label("Socket %d/%d　%s%s"%[sockets,cap,"● ".repeat(sockets),"○ ".repeat(maxi(0,cap-sockets))],detail)
    label("特殊効果 %d/%d（カード4枚限定）\n再抽選 通算 %d/3（残り%d回・回数回復なし）\n%s"%[item.get("special_effects",[]).size(),int(item.get("special_effect_slots",0)),int(item.get("special_reroll_count",0)),maxi(0,3-int(item.get("special_reroll_count",0))),EquipmentSpecialEffectPolicy.summary(item)],detail)
    for group in ["fixed_cards","random_cards"]:
        label("固定2枠（再抽選不可）" if group=="fixed_cards" else "ランダム2枠",detail,20)
        for i in range(item[group].size()):
            if group=="random_cards":label("枠%d：使用%d/3 / 残り%d回"%[i+1,int(item.reroll_counts[i]),maxi(0,3-int(item.reroll_counts[i]))],detail)
            card_view(str(item[group][i]),detail,"ForgeCard_"+group+str(i))
    if not run.state.forge_pending.is_empty():render_pending();return
    var level: int=int(item.get("enhance_level",0))
    var enhanced_hp: int=int(item.base_hp)+(level+1)*int(template.get("HP_Per_Enhance",0))
    separator("HP強化")
    label("HP強化：Lv%d → %d / 上限%d\nHP %d → %d\n費用 %dG / 素材1"%[level,level+1,int(template.get("EnhanceCap",0)),int(item.get("effective_hp",item.base_hp)),enhanced_hp,100*(level+1)],menu)
    operation("HP強化を確認","enhance")
    separator("ソケット拡張")
    if cap==0:
        label("Common装備のソケット上限は0です。拡張できません。",menu)
    else:
        label("Socket拡張：%d → %d / 上限%d\n費用 %dG / 素材1 / 成功率100%%"%[sockets,sockets+1,cap,250+sockets*150],menu)
        operation("Socket拡張を確認","socket")
    separator("カード再抽選：ランダム2枠")
    for i in range(2):
        label("ランダム枠%d：使用%d → %d / 3\n残り%d回 / 費用250G / 素材1\n抽選後の候補は実行後に表示します。"%[i+1,int(item.reroll_counts[i]),int(item.reroll_counts[i])+1,maxi(0,3-int(item.reroll_counts[i]))],menu)
        var pool=Button.new()
        pool.text="枠%dの変更候補一覧を見る（抽選前・無料）"%(i+1)
        menu.add_child(pool)
        pool.pressed.connect(_show_reroll_pool.bind(i))
        operation("ランダム枠%d 再抽選を確認"%(i+1),"reroll",i)
    label("現状維持でもGold・素材・再抽選回数は戻りません。",menu)
    separator("特殊効果再抽選（装備ごと合計3回）")
    label("選んだ特殊効果1つを候補2択と比較。現状維持も選べます。\n3回の枠は装備全体で共通・回復しません。費用250G/素材1。",menu)
    var affixes: Array=item.get("special_effects",[])
    if affixes.is_empty():label("再抽選可能な特殊効果がありません。",menu)
    for effect_index in range(affixes.size()):
        var effect_id: String=str(affixes[effect_index].get("effect_id", ""))
        label("枠%d：%s %s"%[effect_index+1,effect_id,str(EquipmentSpecialEffectPolicy.NAMES.get(effect_id,"旧効果"))],menu)
        operation("特殊効果枠%dを再抽選（候補2択）"%(effect_index+1),"special_reroll",effect_index)
    separator("装備分解")
    label("分解する装備の選択と最終確認は、左側の「対象一覧を見る・分解を選択」から行います。",menu,14)
    label("この装備の分解獲得素材：+%d（装備中は選択不可）"%material_yield(item),menu,14)

func separator(title: String) -> void:
    menu.add_child(HSeparator.new())
    var heading=label(title,menu,20);heading.modulate=Color("78bcff")

func material_yield(item: Dictionary) -> int:
    return Region1RunController.RARITIES.find(str(item.rarity))+1

func reason(action: String,slot: int=-1) -> String:
    if str(run.state.phase)!="hub":return "ラン中は加工できません。"
    if run.save_blocked:return "保存不能状態です。"
    if change_guard.is_valid() and bool(change_guard.call()):return "生成・演出中です。"
    if action=="resolve":return "" if not run.state.forge_pending.is_empty() else "選択待ちの候補がありません。"
    if not run.state.forge_pending.is_empty():return "候補選択または現状維持を先に確定してください。"
    if not run.state.inventory.has(selected_uid):return "装備を選択してください。"
    var item: Dictionary=run.state.inventory[selected_uid]
    var template: Dictionary=run.roller.templates[str(item.equipment_id)]
    var cost: int=250
    if action=="dismantle":return "装備中は分解できません。" if run.state.loadout.values().has(selected_uid) else ""
    if action=="enhance":
        var level: int=int(item.get("enhance_level",0))
        if level>=int(template.EnhanceCap):return "強化上限です。"
        cost=100*(level+1)
    elif action=="socket":
        var count: int=int(item.get("socket_count",template.InitialSocketMin))
        if count>=int(template.SocketCap):return "Socket上限です。"
        cost=250+count*150
    elif action=="reroll":
        if slot<0 or slot>1 or int(item.reroll_counts[slot])>=3:return "再抽選回数上限です。"
    elif action=="special_reroll":
        var effects: Array=item.get("special_effects",[])
        if int(item.get("special_reroll_count",0))>=3:return "特殊効果再抽選は通算3回までです。"
        if slot<0 or slot>=effects.size():return "特殊効果枠がありません。"
        var pool: Array[String]=EquipmentSpecialEffectPolicy.eligible_ids(item)
        for entry in effects:
            if entry is Dictionary:pool.erase(str(entry.get("effect_id","")))
        if pool.size()<2:return "異なる新候補が2件ありません。"
    if int(run.state.base_gold)<cost:return "Goldが不足しています。"
    if int(run.state.materials)<1:return "素材が不足しています。"
    return ""

func operation(text: String,action: String,slot: int=-1) -> Button:
    if action!="resolve":
        var item: Dictionary=run.state.inventory[selected_uid]
        var template: Dictionary=run.roller.templates[str(item.equipment_id)]
        var cost: int=250
        if action=="enhance":cost=100*(int(item.get("enhance_level",0))+1)
        if action=="socket":cost=250+int(item.get("socket_count",template.InitialSocketMin))*150
        if action=="dismantle":cost=0
        label("Gold %d → %d / 素材 %d → %d"%[int(run.state.base_gold),int(run.state.base_gold)-cost,int(run.state.materials),int(run.state.materials)+(material_yield(item) if action=="dismantle" else -1)],menu,14)
    var button=Button.new();button.text=text;button.custom_minimum_size.y=42;button.set_meta("action",action);button.set_meta("slot",slot);menu.add_child(button);operation_buttons.append(button)
    button.disabled=reason(action,slot)!="";button.tooltip_text=reason(action,slot)
    if button.disabled:label(reason(action,slot),menu,14)
    button.pressed.connect(func():
        if action=="resolve":resolve_choice(slot)
        else:request_operation(action,slot))
    return button

func _process(_delta: float) -> void:
    if run==null:return
    for button in operation_buttons:
        if is_instance_valid(button):
            var why: String=reason(str(button.get_meta("action")),int(button.get_meta("slot")))
            button.disabled=why!="";button.tooltip_text=why

func request_operation(action: String,slot: int=-1) -> void:
    if not is_inside_tree() or is_queued_for_deletion() or reason(action,slot)!="":return
    if is_instance_valid(dialog):dialog.queue_free()
    var uid: String=selected_uid
    var snapshot: String=JSON.stringify(run.state.inventory[uid])
    var item: Dictionary=run.state.inventory[uid]
    var template: Dictionary=run.roller.templates[str(item.equipment_id)]
    var text: String="%s\nUID %s\n"%[HubInventoryQuery.item_name(item),uid]
    if action=="dismantle":text+="この非装備品を分解します。元に戻せません。素材%dを獲得。"%material_yield(item)
    elif action=="enhance":
        var level: int=int(item.get("enhance_level",0))
        text+="HP %d → %d / Lv%d → %d\n%dG・素材1を消費。"%[int(item.get("effective_hp",item.base_hp)),int(item.base_hp)+(level+1)*int(template.HP_Per_Enhance),level,level+1,100*(level+1)]
    elif action=="socket":
        var count: int=int(item.get("socket_count",template.InitialSocketMin))
        text+="Socket %d → %d / 上限%d / 成功率100%%\n%dG・素材1を消費。"%[count,count+1,int(template.SocketCap),250+count*150]
    elif action=="special_reroll":
        text+="特殊効果枠%d / 装備通算%d → %d回（上限3・回復なし）\n250G・素材1を消費。候補2つか現状維持を選択できます。"%[slot+1,int(item.get("special_reroll_count",0)),int(item.get("special_reroll_count",0))+1]
    else:text+="ランダム枠%d / 使用%d → %d回（上限3）\n250G・素材1を消費。現状維持でも費用・回数は戻りません。"%[slot+1,int(item.reroll_counts[slot]),int(item.reroll_counts[slot])+1]
    dialog=ConfirmationDialog.new();dialog.name="ForgeConfirmation";dialog.dialog_text=text;dialog.title="装備分解の確認" if action=="dismantle" else "加工の確認";dialog.ok_button_text="実行";add_child(dialog)
    dialog.get_cancel_button().text="取消"
    var current_dialog: ConfirmationDialog=dialog
    dialog.confirmed.connect(func():
        if is_inside_tree() and not is_queued_for_deletion() and selected_uid==uid and reason(action,slot)=="" and JSON.stringify(run.state.inventory[uid])==snapshot:
            if run.forge(uid,action,slot):equipment_changed.emit(uid if run.state.inventory.has(uid) else "")
            else:label(run.notice if run.notice!="" else "加工できませんでした。状態は保持されています。",menu)
        current_dialog.queue_free())
    dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(620,230))

func candidate_preview(index: int) -> Dictionary:
    var pending: Dictionary=run.state.forge_pending
    var item: Dictionary=run.state.inventory[str(pending.uid)].duplicate(true)
    var old_id: String=str(item.random_cards[int(pending.slot)])
    var new_id: String=str(pending.choices[index])
    item.random_cards[int(pending.slot)]=new_id;item.cards=item.fixed_cards+item.random_cards
    var before_items: Dictionary=run.items_from_state()
    var after_items: Dictionary=before_items.duplicate(true)
    var equipped: bool=str(run.state.loadout.get(str(item.slot),""))==str(pending.uid)
    if equipped:after_items[str(item.slot)]=item
    return {"old_id":old_id,"new_id":new_id,"equipped":equipped,"before":analyzer.analyze(before_items),"after":analyzer.analyze(after_items),"item":item}

func render_pending() -> void:
    var pending: Dictionary=run.state.forge_pending
    if str(pending.get("kind","card"))=="special_effect":
        label("特殊効果枠%d：新候補2択＋現状維持"%(int(pending.effect_index)+1),menu,22)
        label("装備全体で通算%d/3回使用済み。現状維持でも消費済み回数・費用は戻りません。"%int(run.state.inventory[str(pending.uid)].get("special_reroll_count",0)),menu)
        var current: Dictionary=run.state.inventory[str(pending.uid)]
        var old_id: String=str(current.special_effects[int(pending.effect_index)].get("effect_id",""))
        label("現在：%s　%s\n%s"%[old_id,str(EquipmentSpecialEffectPolicy.NAMES.get(old_id,"旧効果")),str(EquipmentSpecialEffectPolicy.DETAILS.get(old_id,""))],menu)
        for i in range(2):
            var effect_id: String=str(pending.choices[i])
            label("候補%s：%s %s\n%s"%["A" if i==0 else "B",effect_id,str(EquipmentSpecialEffectPolicy.NAMES.get(effect_id,"")),str(EquipmentSpecialEffectPolicy.DETAILS.get(effect_id,""))],menu)
            operation("候補%sへ変更を確定"%("A" if i==0 else "B"),"resolve",i)
        operation("現状維持を確定（回数は戻りません）","resolve",-1)
        return
    label("ランダム枠%d：候補選択待ち（保存済み）"%(int(pending.slot)+1),menu,22)
    label("Gold・素材・回数は抽選時に消費済み。現状維持でも戻りません。候補比較だけでは保存しません。",menu)
    var original_menu: VBoxContainer=menu
    var columns=VBoxContainer.new();columns.add_theme_constant_override("separation",16);menu.add_child(columns)
    for i in range(2):
        menu=VBoxContainer.new();menu.custom_minimum_size.x=0;menu.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(menu)
        var report: Dictionary=candidate_preview(i)
        var old: Dictionary=analyzer.cards[report.old_id]
        var card: Dictionary=analyzer.cards[report.new_id]
        label("候補%s"%["A" if i==0 else "B"],menu,22)
        card_view(str(report.new_id),menu)
        label("種別 %s → %s / 役割 %s → %s\n属性 %s → %s / 武器 %s → %s"%[old.card_type,card.card_type,old.role,card.role,old.attribute,card.attribute,old.weapon,card.weapon],menu)
        label("%s\n24枚内 %s：%d → %d枚 / %s：%d → %d枚\n完成SC %d → %d / 孤立差分 %d → %d"%["装備中：対象1枚だけ仮交換" if report.equipped else "未装備：現在の24枚デッキは変化しません",old.attribute,int(report.before.distribution.attribute[old.attribute]),int(report.after.distribution.attribute[old.attribute]),card.attribute,int(report.before.distribution.attribute[card.attribute]),int(report.after.distribution.attribute[card.attribute]),int(report.before.completed_sc),int(report.after.completed_sc),int(report.before.orphan),int(report.after.orphan)],menu)
        var before_pairs: Array=[];var after_pairs: Array=[]
        for pair in report.before.completed_pairs:before_pairs.append(str(pair.set_id)+"→"+str(pair.con_id))
        for pair in report.after.completed_pairs:after_pairs.append(str(pair.set_id)+"→"+str(pair.con_id))
        var gained: Array=[];var lost: Array=[]
        for pair in after_pairs:
            if not before_pairs.has(pair):gained.append(pair)
        for pair in before_pairs:
            if not after_pairs.has(pair):lost.append(pair)
        label("SC成立追加 %s / 不成立化 %s\n構造判定であり実戦コンボ成功の保証ではありません。"%[str(gained),str(lost)],menu)
        operation("候補%sを確定"%("A" if i==0 else "B"),"resolve",i)
    menu=original_menu
    operation("現状維持を確定（費用・回数は返却されません）","resolve",-1)

func resolve_choice(index: int) -> void:
    if not is_inside_tree() or is_queued_for_deletion() or reason("resolve")!="":return
    var uid: String=str(run.state.forge_pending.uid)
    if run.resolve_forge(index):equipment_changed.emit(uid)
    else:label(run.notice if run.notice!="" else "候補の確定に失敗しました。選択待ちを保持しています。",menu)



func _reroll_pool(slot: int) -> Array[String]:
    # Mirrors the current forge eligibility predicate without touching RNG or save.
    var result: Array[String]=[]
    if not run.state.inventory.has(selected_uid) or slot<0 or slot>1:return result
    var item: Dictionary=run.state.inventory[selected_uid]
    var keys: Array=run.roller.cards.keys()
    keys.sort()
    for cid in keys:
        if item.cards.has(cid):continue
        var trial: Dictionary=item.duplicate(true)
        trial.random_cards[slot]=cid
        trial.cards=trial.fixed_cards+trial.random_cards
        if str(item.slot)=="main_weapon" and (str(run.roller.cards[cid].weapon)!=str(item.affinity_weapon) or str(run.roller.cards[cid].attr)==str(item.rolled_attribute)):continue
        if run.roller.validate_item(trial):result.append(str(cid))
    return result

func _show_reroll_pool(slot: int) -> void:
    if not run.state.inventory.has(selected_uid):return
    if is_instance_valid(pool_dialog):pool_dialog.queue_free()
    var options: Array[String]=_reroll_pool(slot)
    pool_dialog=AcceptDialog.new()
    pool_dialog.title="ランダム枠%d：変更候補プール（%d種類）"%[slot+1,options.size()]
    pool_dialog.ok_button_text="閉じる"
    add_child(pool_dialog)
    var wrapper=VBoxContainer.new();pool_dialog.add_child(wrapper)
    label("この一覧は抽選対象プールです。直接選択はできず、250Gと素材1でランダムに2候補が提示されます。",wrapper,14)
    var columns=HBoxContainer.new();wrapper.add_child(columns)
    var list=ItemList.new();list.custom_minimum_size=Vector2(300,380);columns.add_child(list)
    var card_detail=RichTextLabel.new();card_detail.custom_minimum_size=Vector2(450,380);card_detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(card_detail)
    for id in options:
        var card: Dictionary=analyzer.cards.get(id,{})
        list.add_item("%s / Cost%s / %s × %s"%[id,str(card.get("cost","?")),str(card.get("attribute","?")),str(card.get("weapon","?"))])
    list.item_selected.connect(func(index: int):card_detail.text=analyzer.card_description(options[index]))
    if not options.is_empty():list.select(0);card_detail.text=analyzer.card_description(options[0])
    pool_dialog.popup_centered(Vector2i(840,510))

func _valid_bulk_uids() -> Array[String]:
    var result: Array[String]=[]
    if run==null:return result
    for value in bulk_selected_uids.keys():
        var uid: String=str(value)
        if not run.state.inventory.has(uid) or run.state.loadout.values().has(uid):continue
        result.append(uid)
    result.sort()
    return result

func _bulk_names_and_yield() -> Dictionary:
    var uids: Array[String]=_valid_bulk_uids()
    var names: Array[String]=[]
    var total: int=0
    for uid in uids:
        var item: Dictionary=run.state.inventory[uid]
        names.append(HubInventoryQuery.item_name(item))
        total+=material_yield(item)
    return {"uids":uids,"names":names,"materials":total}

func _update_bulk_hint() -> void:
    var data: Dictionary=_bulk_names_and_yield()
    var n: int=data.uids.size()
    if bulk_hint!=null:
        bulk_hint.text="分解候補：0件（サブウィンドウで選択）" if n==0 else "分解候補：%d件 / 獲得予定素材 +%d"%[n,int(data.materials)]
    # Viewing all items is always possible, even when no item is selected.
    if bulk_review_button!=null:bulk_review_button.disabled=false
    if bulk_execute_button!=null:bulk_execute_button.visible=false

func _clear_bulk_selection() -> void:
    bulk_selected_uids.clear()
    for value in bulk_modal_boxes.values():
        var checkbox: CheckBox=value
        if is_instance_valid(checkbox):checkbox.set_pressed_no_signal(false)
    _refresh_bulk_modal_summary()
    _update_bulk_hint()

func _refresh_bulk_modal_summary() -> void:
    var data: Dictionary=_bulk_names_and_yield()
    if bulk_modal_summary!=null and is_instance_valid(bulk_modal_summary):
        bulk_modal_summary.text="選択：%d件　獲得予定素材：+%d\n装備中の品は選択できません。閉じても分解はされません。"%[data.uids.size(),int(data.materials)]
    if bulk_modal_commit!=null and is_instance_valid(bulk_modal_commit):
        bulk_modal_commit.text="選択した%d件の分解を確認"%data.uids.size()
        bulk_modal_commit.disabled=data.uids.is_empty()
    _update_bulk_hint()

func _toggle_bulk_modal_uid(checked: bool,uid: String) -> void:
    if run==null:return
    if checked and run.state.inventory.has(uid) and not run.state.loadout.values().has(uid):
        bulk_selected_uids[uid]=true
    else:
        bulk_selected_uids.erase(uid)
    _refresh_bulk_modal_summary()

func _bulk_modal_set_all(checked: bool) -> void:
    if run==null:return
    for uid_value in run.state.inventory.keys():
        var uid: String=str(uid_value)
        if run.state.loadout.values().has(uid):continue
        if checked:bulk_selected_uids[uid]=true
        else:bulk_selected_uids.erase(uid)
    for uid_value in bulk_modal_boxes.keys():
        var uid: String=str(uid_value)
        var checkbox: CheckBox=bulk_modal_boxes[uid]
        if is_instance_valid(checkbox):checkbox.set_pressed_no_signal(bulk_selected_uids.has(uid))
    _refresh_bulk_modal_summary()

func _show_bulk_selection() -> void:
    if run==null:return
    if is_instance_valid(bulk_review_dialog):bulk_review_dialog.queue_free()
    bulk_modal_boxes.clear()
    bulk_review_dialog=AcceptDialog.new()
    bulk_review_dialog.name="ForgeBulkSelectionList"
    bulk_review_dialog.title="一括分解：対象を選択"
    bulk_review_dialog.ok_button_text="閉じる（分解しない）"
    add_child(bulk_review_dialog)
    var wrapper=VBoxContainer.new()
    wrapper.add_theme_constant_override("separation",10)
    bulk_review_dialog.add_child(wrapper)
    bulk_modal_summary=label("",wrapper,16)
    var tools=HBoxContainer.new();tools.add_theme_constant_override("separation",8);wrapper.add_child(tools)
    var all_button=Button.new();all_button.text="未装備品を全選択";tools.add_child(all_button)
    all_button.pressed.connect(_bulk_modal_set_all.bind(true))
    var clear_button=Button.new();clear_button.text="選択を全解除";tools.add_child(clear_button)
    clear_button.pressed.connect(_bulk_modal_set_all.bind(false))
    var scroll=ScrollContainer.new()
    scroll.name="ForgeBulkCandidateScroll"
    scroll.custom_minimum_size=Vector2(660,420)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    wrapper.add_child(scroll)
    var rows=VBoxContainer.new();rows.name="ForgeBulkCandidateRows";rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation",5);scroll.add_child(rows)
    var uids: Array[String]=[]
    for value in run.state.inventory.keys():uids.append(str(value))
    uids.sort()
    var available: int=0
    for uid in uids:
        var item: Dictionary=run.state.inventory[uid]
        var equipped: bool=run.state.loadout.values().has(uid)
        if not equipped:available+=1
        var checkbox=CheckBox.new()
        checkbox.name="BulkSelect_"+uid
        checkbox.text="%s [%s / %s / HP%d]　素材+%d%s"%[HubInventoryQuery.item_name(item),str(SLOT_NAMES.get(str(item.get("slot","")),"")),str(item.get("rarity","")),int(item.get("effective_hp",item.get("base_hp",0))),material_yield(item),"（装備中・選択不可）" if equipped else ""]
        checkbox.button_pressed=bulk_selected_uids.has(uid) and not equipped
        checkbox.disabled=equipped
        checkbox.tooltip_text="UID: "+uid
        checkbox.toggled.connect(_toggle_bulk_modal_uid.bind(uid))
        rows.add_child(checkbox)
        bulk_modal_boxes[uid]=checkbox
    if available==0:label("分解可能な未装備品がありません。",rows,15)
    bulk_modal_commit=Button.new()
    bulk_modal_commit.name="ForgeBulkReviewCommit"
    bulk_modal_commit.custom_minimum_size.y=44
    wrapper.add_child(bulk_modal_commit)
    bulk_modal_commit.pressed.connect(func():
        if is_instance_valid(bulk_review_dialog):bulk_review_dialog.hide()
        _request_bulk_dismantle())
    _refresh_bulk_modal_summary()
    bulk_review_dialog.popup_centered(Vector2i(760,650))

func _request_bulk_dismantle() -> void:
    if run==null:return
    if str(run.state.phase)!="hub" or run.save_blocked or not run.state.forge_pending.is_empty() or (change_guard.is_valid() and bool(change_guard.call())):
        if bulk_hint!=null:bulk_hint.text="ラン中・保存不可・再抽選待機中は分解できません。"
        return
    var data: Dictionary=_bulk_names_and_yield()
    var selected: Array[String]=data.uids
    var names: Array[String]=[]
    var total: int=int(data.materials)
    for uid in selected:
        names.append("・"+HubInventoryQuery.item_name(run.state.inventory[uid])+" ["+uid+"]")
    if selected.is_empty():
        if bulk_hint!=null:bulk_hint.text="分解対象がありません。未装備品を選択してください。"
        return
    if is_instance_valid(dialog):dialog.queue_free()
    var snapshot: String=JSON.stringify(run.state.inventory)
    dialog=ConfirmationDialog.new()
    dialog.title="一括分解の最終確認"
    dialog.ok_button_text="%d個を分解"%selected.size()
    dialog.dialog_text="次の%d装備を一括分解します。取り消せません。\n%s\n\n獲得素材：+%d\n装備中の装備は対象外です。"%[selected.size(),"\n".join(names),total]
    add_child(dialog)
    var confirmation: ConfirmationDialog=dialog
    dialog.confirmed.connect(func():
        if not is_inside_tree() or is_queued_for_deletion():return
        if str(run.state.phase)!="hub" or run.save_blocked or not run.state.forge_pending.is_empty():return
        if change_guard.is_valid() and bool(change_guard.call()):return
        if JSON.stringify(run.state.inventory)!=snapshot:return
        if run.dismantle_many(selected):
            bulk_selected_uids.clear()
            selected_uid=""
            equipment_changed.emit("")
        elif bulk_hint!=null:bulk_hint.text="一括分解を保存できませんでした。装備は維持されています。"
        confirmation.queue_free())
    dialog.canceled.connect(dialog.queue_free)
    dialog.popup_centered(Vector2i(680,mini(660,210+selected.size()*22)))
