class_name HubEquipmentPanel
extends VBoxContainer

signal equipment_changed(uid: String)

const SLOT_NAMES={"main_weapon":"Main Weapon","offhand":"Offhand","head":"Head","body":"Body","hands":"Hands","feet":"Feet"}
var run: Region1RunController
var analyzer=HubDeckAnalyzer.new()
var filters: Dictionary={}
var selected_uid: String=""
var visible_rows: Array=[]
var paged_rows: Array=[]
var inventory_page: int=0
var inventory_page_size: int=8
var tile_mode: bool=true
var page_label: Label
var previous_page: Button
var next_page: Button
var inventory_list: ItemList
var detail: VBoxContainer
var count_label: Label
var tabs: TabContainer
var comparison=HubEquipmentComparison.new()
var recommendation_box: VBoxContainer
var advisor=HubLoadoutAdvisor.new()
var confirm_buttons: Array[Button]=[]
var change_guard: Callable
var preview: Dictionary={}
var deck_box: VBoxContainer
var slot_buttons: Dictionary={}
var library_title: Label

func card_view(id: String,parent: Node,node_name: String="") -> HubCardView:
    var view=HubCardView.new();view.name=node_name if node_name!="" else "Card_"+id;parent.add_child(view);view.build(id,analyzer);return view

func refresh_after_change(uid: String) -> void:
    selected_uid=uid
    refresh_inventory()
    var stats: Dictionary=analyzer.analyze(run.items_from_state())
    library_title.text="装備ライブラリ　所持%d個 / 装備%d部位 / HP合計%d"%[run.state.inventory.size(),run.state.loadout.size(),int(stats.hp)]
    refresh_deck_tab()
    var forge: HubForgePanel=tabs.get_child(2)
    forge.selected_uid=uid;forge.refresh_inventory()
    if not run.state.forge_pending.is_empty():tabs.current_tab=2

func label(text: String,parent: Node,size: int=16) -> Label:
    var node=Label.new();node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    node.add_theme_font_size_override("font_size",size);parent.add_child(node)
    return node

func build(controller: Region1RunController) -> void:
    run=controller;name="HubEquipmentPanel";size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
    var analysis: Dictionary=analyzer.analyze(run.items_from_state())
    library_title=label("装備ライブラリ　所持%d個 / 装備%d部位 / HP合計%d"%[run.state.inventory.size(),run.state.loadout.size(),int(analysis.hp)],self,22)
    label("選択・検索・比較はプレビューです。装備確定・加工の実行確認・候補確定でのみ装備と保存を更新します。",self)
    tabs=TabContainer.new();tabs.custom_minimum_size.y=200;tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(tabs)
    var warehouse=HBoxContainer.new();warehouse.name="装備倉庫";warehouse.add_theme_constant_override("separation",18);tabs.add_child(warehouse)
    var sidebar=VBoxContainer.new();sidebar.custom_minimum_size.x=480;warehouse.add_child(sidebar)
    var slot_row=HFlowContainer.new();slot_row.name="WarehouseSlots";sidebar.add_child(slot_row)
    for slot in [""]+HubDeckAnalyzer.SLOTS:
        var slot_button=Button.new();slot_button.toggle_mode=true;slot_button.name="Slot_"+str(slot)
        slot_button.pressed.connect(select_slot.bind(str(slot)));slot_row.add_child(slot_button);slot_buttons[str(slot)]=slot_button
    add_filter("部位","slot",HubDeckAnalyzer.SLOTS,sidebar,SLOT_NAMES)
    add_filter("装備の抽選属性","rolled_attribute",analyzer.categories("attribute"),sidebar)
    add_filter("付属カードの属性","card_attribute",analyzer.categories("attribute"),sidebar)
    add_filter("付属カードの武器","card_weapon",analyzer.categories("weapon"),sidebar)
    add_filter("レアリティ","rarity",["Common","Rare","Epic","Legendary"],sidebar)
    add_filter("並び順","sort",["rarity","hp","name"],sidebar,{"rarity":"レアリティ → HP → 装備名","hp":"HP → レアリティ → 装備名","name":"装備名"},false)
    var equipped=CheckButton.new();equipped.name="EquippedOnly";equipped.text="装備中のみ";sidebar.add_child(equipped)
    equipped.toggled.connect(func(on: bool):filters["equipped"]=on;reset_page_and_refresh())
    var search=LineEdit.new();search.name="InventorySearch";search.placeholder_text="装備名 / 個体ID / カードID / 効果";sidebar.add_child(search)
    search.text_changed.connect(func(text: String):filters["search"]=text;reset_page_and_refresh())
    count_label=label("",sidebar)
    _build_page_controls(sidebar)
    inventory_list=ItemList.new();inventory_list.name="InventoryList";inventory_list.custom_minimum_size.y=80;inventory_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;sidebar.add_child(inventory_list)
    inventory_list.icon_mode=ItemList.ICON_MODE_TOP;inventory_list.max_text_lines=3;inventory_list.add_theme_font_size_override("font_size",13)
    inventory_list.max_columns=2
    inventory_list.fixed_column_width=218
    inventory_list.same_column_width=true
    inventory_list.item_selected.connect(func(index: int):selected_uid=str(paged_rows[index].uid);refresh_detail())
    var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;warehouse.add_child(scroll)
    detail=VBoxContainer.new();detail.name="EquipmentDetail";detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.add_theme_constant_override("separation",12);scroll.add_child(detail)
    var deck_scroll=ScrollContainer.new();deck_scroll.name="24枚デッキ分析";deck_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(deck_scroll)
    deck_box=VBoxContainer.new();deck_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;deck_box.add_theme_constant_override("separation",10);deck_scroll.add_child(deck_box)
    recommendation_box=VBoxContainer.new();recommendation_box.name="OwnedLoadoutRecommendations";recommendation_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;recommendation_box.add_theme_constant_override("separation",12)
    deck_box.add_child(recommendation_box)
    refresh_deck_tab()
    refresh_inventory()
    var forge=HubForgePanel.new();forge.change_guard=change_guard;forge.selected_uid=selected_uid;tabs.add_child(forge)
    forge.equipment_changed.connect(func(uid: String):refresh_after_change(uid);equipment_changed.emit(uid))
    forge.build(run)
    if not run.state.forge_pending.is_empty():tabs.current_tab=2

func restore_filters(values: Dictionary) -> void:
    filters=values.duplicate(true)
    for key in ["slot","rolled_attribute","card_attribute","card_weapon","rarity","sort"]:
        var control: OptionButton=find_child("Filter_"+key,true,false)
        if control==null:continue
        for index in range(control.item_count):
            if str(control.get_item_metadata(index))==str(filters.get(key,"")):control.select(index)
    var search: LineEdit=find_child("InventorySearch",true,false)
    if search==null:search=find_child("ForgeSearch",true,false)
    if search!=null:search.text=str(filters.get("search",""))
    var equipped: CheckButton=find_child("EquippedOnly",true,false)
    if equipped!=null:equipped.set_pressed_no_signal(bool(filters.get("equipped",false)))
    reset_page_and_refresh()

func add_filter(title: String,key: String,values: Array,parent: Node,names: Dictionary={},all_option: bool=true) -> void:
    var row=HBoxContainer.new();parent.add_child(row)
    label(title,row,14).custom_minimum_size.x=135
    var select=OptionButton.new();select.name="Filter_"+key;select.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(select)
    if all_option:select.add_item("すべて");select.set_item_metadata(0,"")
    for value in values:
        select.add_item(str(names.get(value,value)));select.set_item_metadata(select.item_count-1,value)
    if not all_option:filters[key]=values[0]
    select.item_selected.connect(func(index: int):filters[key]=str(select.get_item_metadata(index));reset_page_and_refresh())

func _build_page_controls(parent: Node) -> void:
    var row=HBoxContainer.new()
    row.add_theme_constant_override("separation",8)
    parent.add_child(row)
    previous_page=Button.new();previous_page.text="◀ 前ページ";row.add_child(previous_page)
    previous_page.pressed.connect(func():inventory_page=maxi(0,inventory_page-1);refresh_inventory())
    page_label=label("",row,14)
    page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    next_page=Button.new();next_page.text="次ページ ▶";row.add_child(next_page)
    next_page.pressed.connect(func():inventory_page+=1;refresh_inventory())

func reset_page_and_refresh() -> void:
    inventory_page=0
    refresh_inventory()

func select_slot(slot: String) -> void:
    filters["slot"]=slot
    var select: OptionButton=find_child("Filter_slot",true,false)
    for index in range(select.item_count):
        if str(select.get_item_metadata(index))==slot:select.select(index)
    reset_page_and_refresh()

func refresh_inventory() -> void:
    for slot in slot_buttons:
        var count: int=0
        for item in run.state.inventory.values():
            if slot=="" or str(item.get("slot",""))==slot:count+=1
        var title: String={"":"全て","main_weapon":"主武器","offhand":"副装備","head":"頭","body":"胴","hands":"手","feet":"足"}.get(slot,slot)
        slot_buttons[slot].text="%s %d"%[title,count]
        slot_buttons[slot].set_pressed_no_signal(str(filters.get("slot",""))==slot)
    visible_rows=HubInventoryQuery.rows(run.state,filters,analyzer.cards)
    var pages: int=maxi(1,ceili(float(visible_rows.size())/float(inventory_page_size)))
    inventory_page=clampi(inventory_page,0,pages-1)
    var start: int=inventory_page*inventory_page_size
    paged_rows=visible_rows.slice(start,mini(start+inventory_page_size,visible_rows.size()))
    inventory_list.clear()
    count_label.text="%d / %d個（装備個体）"%[visible_rows.size(),run.state.inventory.size()]
    if page_label!=null:page_label.text="%d / %dページ"%[inventory_page+1,pages]
    if previous_page!=null:previous_page.disabled=inventory_page==0
    if next_page!=null:next_page.disabled=inventory_page+1>=pages
    var selected: int=-1
    for row in paged_rows:
        var item: Dictionary=row.item
        var summary: String=item_summary(item,bool(row.equipped))
        inventory_list.add_item(summary,HubCardView.badge(str(item.get("rolled_attribute","")),str(item.get("affinity_weapon",""))))
        var index: int=inventory_list.item_count-1
        inventory_list.set_item_custom_fg_color(index,HubCardView.tone(str(item.get("rarity",""))))
        inventory_list.set_item_metadata(index,row.uid)
        inventory_list.set_item_tooltip(index,HubInventoryQuery.item_name(item)+"\n"+str(row.uid)+"\n"+str(SLOT_NAMES.get(str(item.get("slot","")),item.get("slot","")))+" / "+str(item.get("rarity",""))+" / HP"+str(item.get("effective_hp",item.get("base_hp",0)))+"\n抽選属性 "+str(item.get("rolled_attribute","未設定"))+" / 武器Affinity "+str(item.get("affinity_weapon","未設定")))
        if row.uid==selected_uid:selected=index
    if not run.state.inventory.has(selected_uid):selected_uid=""
    if selected>=0:inventory_list.select(selected)
    inventory_list.get_v_scroll_bar().set_deferred("value",0.0)
    refresh_detail()

func item_summary(item: Dictionary,equipped: bool) -> String:
    if tile_mode:
        var name: String=HubInventoryQuery.item_name(item)
        if name.length()>13:name=name.substr(0,12)+"…"
        return "%s%s\n%s / HP%d / %s\n効果%d · %s · %s"%["◆ " if equipped else "",name,str(item.get("rarity","未設定")),int(item.get("effective_hp",item.get("base_hp",0))),str(SLOT_NAMES.get(str(item.get("slot","")),"未設定")),item.get("special_effects",[]).size(),str(item.get("rolled_attribute","未設定")),str(item.get("affinity_weapon","未設定"))]
    return "%s%s / %s\n%s / HP%d\n属性 %s / 武器 %s"%["◆ 装備中 " if equipped else "",HubInventoryQuery.item_name(item),str(item.get("rarity","未設定")),str(SLOT_NAMES.get(str(item.get("slot","")),"未設定")),int(item.get("effective_hp",item.get("base_hp",0))),str(item.get("rolled_attribute","未設定")),str(item.get("affinity_weapon","未設定"))]

func refresh_detail() -> void:
    confirm_buttons.clear()
    refresh_comparison()
    for child in detail.get_children():detail.remove_child(child);child.queue_free()
    if selected_uid=="" or not run.state.inventory.has(selected_uid):label("左の所持品を選択すると、4カードの正式効果を表示します。",detail,20);return
    var item: Dictionary=run.state.inventory[selected_uid]
    label(HubInventoryQuery.item_name(item),detail,24)
    label("個体ID %s%s"%[selected_uid,"　◆ 装備中" if run.state.loadout.values().has(selected_uid) else ""],detail)
    if bool(preview.get("valid",false)):
        render_inline_comparison()
        add_confirm(detail)
    if str(item.get("instance_id",""))!=selected_uid:label("警告：個体IDが一致しません。",detail)
    var template: Dictionary=analyzer.roller.templates.get(str(item.get("equipment_id","")),{})
    label("%s / %s / HP %d\n装備の抽選属性 %s / 武器Affinity %s\nSocket %d / %d　HP強化 Lv%d"%[str(SLOT_NAMES.get(str(item.get("slot","")),item.get("slot",""))),str(item.get("rarity","")),int(item.get("effective_hp",item.get("base_hp",0))),str(item.get("rolled_attribute","未設定")),str(item.get("affinity_weapon","未設定")),int(item.get("socket_count",template.get("InitialSocketMin",0))),int(template.get("SocketCap",0)),int(item.get("enhance_level",0))],detail)
    label("装備特殊効果（この装備由来4カードのみ）\n"+EquipmentSpecialEffectPolicy.summary(item),detail)
    for group in ["fixed_cards","random_cards"]:
        label("固定2枠" if group=="fixed_cards" else "ランダム2枠",detail,20)
        var ids: Array=item.get(group,[])
        if ids.size()!=2:label("警告：2枠ではありません。",detail)
        for i in range(ids.size()):
            card_view(str(ids[i]),detail)

func blocked_reason() -> String:
    if str(run.state.phase)!="hub":return "ラン中は装備を変更できません。"
    if not run.state.forge_pending.is_empty():return "再抽選候補の選択を先に完了してください。"
    if run.save_blocked:return "保存禁止状態のため装備を変更できません。"
    if change_guard.is_valid() and bool(change_guard.call()):return "生成・演出の完了を待ってください。"
    if not run.state.inventory.has(selected_uid):return "倉庫から装備を選択してください。"
    if run.state.loadout.values().has(selected_uid):return "同じ装備：変化なし。"
    return ""

func _process(_delta: float) -> void:
    if run==null:return
    for button in confirm_buttons:
        if is_instance_valid(button):button.disabled=blocked_reason()!="";button.tooltip_text=blocked_reason()

func add_confirm(parent: Node) -> void:
    var button=Button.new();button.text="装備確定";button.name="ConfirmEquipment";button.custom_minimum_size.y=42;parent.add_child(button)
    button.disabled=blocked_reason()!="";button.tooltip_text=blocked_reason();confirm_buttons.append(button)
    button.pressed.connect(confirm_equipment)
    if blocked_reason()!="":label(blocked_reason(),parent)

func confirm_equipment() -> void:
    # Check again at execution time, including signals from an obsolete/disabled button.
    if not is_inside_tree() or is_queued_for_deletion():return
    var reason: String=blocked_reason()
    if reason!="":label(reason,detail);return
    var uid: String=selected_uid
    if run.equip(uid):refresh_after_change(uid);equipment_changed.emit(uid)
    else:label(run.notice if run.notice!="" else "装備変更に失敗しました。装備は変更されていません。",detail)

func refresh_comparison() -> void:
    preview={}
    if run==null or not run.state.inventory.has(selected_uid):return
    preview=comparison.compare(run.items_from_state(),run.state.inventory[selected_uid])

func render_inline_comparison() -> void:
    if not bool(preview.get("valid",false)):return
    label("同じ部位の装備比較（選択のみでは変更しません）",detail,20)
    var columns=HBoxContainer.new();columns.name="WarehouseSideBySideComparison";columns.add_theme_constant_override("separation",12);detail.add_child(columns)
    var before: Dictionary=preview.before
    var after: Dictionary=preview.after
    var card_details: Array=[]
    for side in ["current","candidate"]:
        var panel=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(panel)
        var box=VBoxContainer.new();box.add_theme_constant_override("separation",5);panel.add_child(box)
        label("現在装備" if side=="current" else "選択した候補",box,19)
        var item: Dictionary=preview[side]
        if item.is_empty():
            label("未装備",box)
            continue
        var template: Dictionary=analyzer.roller.templates.get(str(item.get("equipment_id","")),{})
        var hp: int=int(item.get("effective_hp",item.get("base_hp",0)))
        var socket_count: int=int(item.get("socket_count",template.get("InitialSocketMin",0)))
        label("%s\n%s / HP %d\nSocket %d/%d / Lv %d"%[HubInventoryQuery.item_name(item),str(item.get("rarity","")),hp,socket_count,int(item.get("socket_cap",template.get("SocketCap",0))),int(item.get("enhance_level",0))],box,15)
        label("属性 %s / 武器 %s"%[str(item.get("rolled_attribute","")),str(item.get("affinity_weapon",""))],box,13)
        label("固定：%s\nランダム：%s"%[str(item.get("fixed_cards",[])),str(item.get("random_cards",[]))],box,14)
        var card_box=VBoxContainer.new();card_box.visible=false;card_box.add_theme_constant_override("separation",6);box.add_child(card_box)
        card_details.append(card_box)
        for raw_id in item.get("cards",[]):
            var id: String=str(raw_id)
            var c: Dictionary=analyzer.cards.get(id,{})
            label("%s / Cost %d\n%s"%[id,int(c.get("cost",0)),str(c.get("text","正式効果が見つかりません"))],card_box,13)
    if not card_details.is_empty():
        var show_cards=Button.new();show_cards.name="CompareCardEffectsToggle";show_cards.text="両装備のカード効果を左右で表示 ▼";detail.add_child(show_cards)
        show_cards.pressed.connect(func():
            var open: bool=not card_details[0].visible
            for card_box in card_details:card_box.visible=open
            show_cards.text="カード効果を閉じる ▲" if open else "両装備のカード効果を左右で表示 ▼")
    var metrics=GridContainer.new();metrics.name="WarehouseComparisonMetrics";metrics.columns=4;detail.add_child(metrics)
    for heading in ["比較項目","現在","候補","差分"]:label(heading,metrics,15)
    for entry in [["デッキHP", "hp"],["コンボ完成", "completed_sc"],["孤立ペア", "orphan_pairs"],["Attack", "attack"],["Draw/循環", "cycle"]]:
        var key: String=str(entry[1]);var a: int=int(before.get(key,0));var b: int=int(after.get(key,0))
        label(str(entry[0]),metrics,14)
        label(str(a),metrics,14)
        label(str(b),metrics,14)
        label("%+d"%(b-a),metrics,14)
    label("比較は装備変更前の予測です。正式効果全文は下のカード欄で確認できます。",detail,13)

func refresh_deck_tab() -> void:
    if deck_box==null or run==null:return
    for child in deck_box.get_children():deck_box.remove_child(child);child.queue_free()
    var stats: Dictionary=analyzer.analyze(run.items_from_state())
    # Always show the current deck analysis before any recommended loadouts.
    # render_analysis includes a foldable detailed section below its summary.
    var current_analysis=VBoxContainer.new()
    current_analysis.name="CurrentDeckAnalysis"
    current_analysis.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    current_analysis.add_theme_constant_override("separation",8)
    deck_box.add_child(current_analysis)
    render_analysis(stats,current_analysis)
    deck_box.add_child(HSeparator.new())
    recommendation_box=VBoxContainer.new()
    recommendation_box.name="OwnedLoadoutRecommendations"
    recommendation_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    recommendation_box.add_theme_constant_override("separation",10)
    deck_box.add_child(recommendation_box)
    label("所持装備から選ぶ おすすめ24枚デッキ構成",recommendation_box,23)
    label("装備品の実データと既存のSET/CONSUME分析を使った参考案です。提案の表示では装備・保存は変更されません。実戦での勝率は保証しません。",recommendation_box,14)
    var suggestions: Array=advisor.suggest(run.state.inventory,run.state.loadout,analyzer)
    if suggestions.is_empty():
        label("6部位の装備が揃わないため、24枚構成を提案できません。",recommendation_box,16)
    for i in range(suggestions.size()):
        var rec: Dictionary=suggestions[i]
        var card=PanelContainer.new();card.name="Recommendation_%d"%(i+1);recommendation_box.add_child(card)
        var box=VBoxContainer.new();box.add_theme_constant_override("separation",6);card.add_child(box)
        label("案%d：%s"%[i+1,str(rec.title)],box,20)
        var data: Dictionary=rec.analysis
        label("HP %d / %d枚 / 完成SC %d組 / 孤立ペア %d / 循環 %d / Attack %d"%[int(data.hp),int(data.card_count),int(data.completed_sc),int(data.orphan_pairs),int(data.cycle),int(data.attack)],box,15)
        label("現在から変更する部位：%d / 6"%int(rec.changes),box,14)
        var toggle=Button.new();toggle.text="6部位の装備構成を表示 ▼";box.add_child(toggle)
        var options=VBoxContainer.new();options.visible=false;box.add_child(options)
        var uid_map: Dictionary=rec.uids
        for slot in HubDeckAnalyzer.SLOTS:
            var uid: String=str(uid_map.get(slot,""))
            var item: Dictionary=run.state.inventory.get(uid,{})
            var current: bool=str(run.state.loadout.get(slot,""))==uid
            label("%s：%s / %s / HP%d%s"%[str(SLOT_NAMES[slot]),HubInventoryQuery.item_name(item),str(item.get("rarity","")),int(item.get("effective_hp",item.get("base_hp",0))),"（装備中）" if current else "（変更候補）"],options,14)
            label("　カード：%s"%str(item.get("cards",[])),options,13)
        toggle.pressed.connect(func():options.visible=not options.visible;toggle.text="詳細を閉じる ▲" if options.visible else "6部位の装備構成を表示 ▼")
        var apply=Button.new()
        apply.name="ApplyRecommendedLoadout_%d"%(i+1)
        apply.text="この6部位の構成に一括変更（1回で保存）" if int(rec.changes)>0 else "現在この構成を装備中"
        apply.custom_minimum_size.y=44
        apply.disabled=int(rec.changes)==0 or run.save_blocked or str(run.state.phase)!="hub" or not run.state.forge_pending.is_empty()
        box.add_child(apply)
        # Copy identities now; never use a live UI recommendation dictionary after a rerender.
        var target_uids: Dictionary=uid_map.duplicate(true)
        apply.pressed.connect(_apply_recommended_loadout.bind(target_uids))
    label("提案は参考値です。『一括変更』を押したときだけ6部位をまとめて検証・保存し、24枚デッキを更新します。",recommendation_box,14)

func _apply_recommended_loadout(uids: Dictionary) -> void:
    if not is_inside_tree() or is_queued_for_deletion() or run==null:return
    if change_guard.is_valid() and bool(change_guard.call()):return
    if run.equip_loadout(uids):
        var main_uid: String=str(uids.get("main_weapon",""))
        refresh_after_change(main_uid)
        equipment_changed.emit(main_uid)
    else:
        label(run.notice if run.notice!="" else "一括装備変更に失敗しました。元の装備構成を維持しています。",recommendation_box,14)

func comparison_metric(title: String,before: int,after: int,parent: Node) -> void:
    var key=label(title,parent);key.custom_minimum_size.x=370;key.autowrap_mode=TextServer.AUTOWRAP_OFF
    for value in [str(before),str(after),"%+d"%(after-before)]:
        var cell=label(value,parent);cell.custom_minimum_size.x=130;cell.autowrap_mode=TextServer.AUTOWRAP_OFF
        if value.begins_with("+"):cell.modulate=Color("9de5ba")
        elif value.begins_with("-"):cell.modulate=Color("ff947d")

func render_analysis(analysis: Dictionary,parent: Node) -> void:
    # Important information first, details on demand; no 24-card wall of text.
    label("24枚デッキ　%s"%("完成" if bool(analysis.complete) else "要確認"),parent,24)
    label("%d / 24枚　最大HP %d　不足部位 %s"%[int(analysis.card_count),int(analysis.hp),"なし" if analysis.missing_slots.is_empty() else str(analysis.missing_slots)],parent,19)
    var overview=GridContainer.new();overview.columns=3;overview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(overview)
    for headline in ["完成コンボ（SC） %d組"%int(analysis.completed_sc),"孤立している組 %d"%int(analysis.get("orphan_pairs",0)),"Draw/手札循環 %d枚"%int(analysis.cycle),"Attack %d枚"%int(analysis.attack),"Salvage %d枚"%int(analysis.salvage),"Cost2以上 %d枚"%int(analysis.cost2_plus)]:
        var badge=Label.new();badge.text=headline;badge.add_theme_font_size_override("font_size",17)
        badge.custom_minimum_size=Vector2(190,40);overview.add_child(badge)
    label("主な属性・武器構成（24枚中）",parent,21)
    for field in ["attribute","weapon"]:
        var counts: Dictionary=analysis.distribution[field]
        var active: Array=[]
        for key in counts:
            if int(counts[key])>0:active.append({"name":str(key),"count":int(counts[key])})
        active.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.count)>int(b.count) if int(a.count)!=int(b.count) else str(a.name)<str(b.name))
        label("属性" if field=="attribute" else "武器種",parent,19)
        var grid=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(grid)
        for entry in active:
            var row=HBoxContainer.new();row.custom_minimum_size.x=300;grid.add_child(row)
            label("%s　%d枚（%.0f%%）"%[entry.name,int(entry.count),100.0*float(entry.count)/maxf(1.0,float(analysis.card_count))],row,15).custom_minimum_size.x=165
            var bar=ProgressBar.new();bar.max_value=maxi(1,int(analysis.card_count));bar.value=int(entry.count);bar.show_percentage=false;bar.custom_minimum_size=Vector2(105,14);row.add_child(bar)
            var fill=StyleBoxFlat.new();fill.bg_color=HubCardView.tone(str(entry.name));fill.set_corner_radius_all(3);bar.add_theme_stylebox_override("fill",fill)
    for warning in analysis.warnings:label("注意："+str(warning),parent,15)
    var expand=Button.new();expand.text="コンボ内訳・全カード構成を表示 ▼";parent.add_child(expand)
    var expanded=VBoxContainer.new();expanded.visible=false;expanded.add_theme_constant_override("separation",8);parent.add_child(expanded)
    expand.pressed.connect(func():expanded.visible=not expanded.visible;expand.text="詳細を閉じる ▲" if expanded.visible else "コンボ内訳・全カード構成を表示 ▼")
    label("成立するSET → CONSUME（構造判定）",expanded,19)
    if analysis.completed_pairs.is_empty():label("成立ペアなし",expanded)
    for pair in analysis.completed_pairs:
        label("%s × %s：%s → %s（Cost %s + %s）"%[str(pair.attr),str(pair.weapon),str(pair.set_id),str(pair.con_id),str(pair.cost_set),str(pair.cost_consume)],expanded,15)
    label("片側だけあるコンボ",expanded,19)
    var counts: Dictionary={}
    for id in analysis.deck:counts[str(id)]=int(counts.get(str(id),0))+1
    var orphan_count: int=0
    for pair in analyzer.roller.pairs:
        if str(pair.status)!="SC":continue
        var has_set: bool=counts.has(str(pair.set_id))
        var has_consume: bool=counts.has(str(pair.con_id))
        if has_set==has_consume:continue
        orphan_count+=1
        label("%s × %s：%sが不足"%[str(pair.attr),str(pair.weapon),"CONSUME "+str(pair.con_id) if has_set else "SET "+str(pair.set_id)],expanded,15)
    if orphan_count==0:label("不足している片側ペアはありません。",expanded,15)
    label("装備6部位のカード内容",expanded,19)
    for slot in HubDeckAnalyzer.SLOTS:
        var item: Dictionary=run.items_from_state().get(slot,{})
        label("%s：%s"%[str(SLOT_NAMES[slot]),str(item.get("cards",[]))],expanded,15)
    label("SCはデッキ内のSET/CONSUME所持判定であり、同一ターンの成立を保証しません。",expanded,14)
