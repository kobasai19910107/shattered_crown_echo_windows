class_name CoopLobbyUI
extends ScrollContainer

const CardButton=preload("res://scripts/playtest_card_button.gd")
var owner_node
var session: CoopCodeSession
var content: VBoxContainer
var state_box: VBoxContainer
var code: LineEdit
var nickname: LineEdit
var seed: SpinBox
var eos_status: Label
var transport: OptionButton
var status_label: Label
var selected_enemy: int=0
var retained: Array=[]
var enemy_buttons: Array=[]
var presentation: BattlePresentation
var previous_fight: Dictionary={}
var player_labels: Array=[]
var display_serial: int=0
var coop_management_open: bool=false
var coop_player_details_open: bool=false


func build(owner_control) -> void:
    owner_node=owner_control
    presentation=BattlePresentation.new();owner_node.add_child(presentation)
    name="オンライン協力"
    horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    follow_focus=true
    clip_contents=true
    size_flags_horizontal=Control.SIZE_EXPAND_FILL
    size_flags_vertical=Control.SIZE_EXPAND_FILL
    content=VBoxContainer.new()
    content.name="CoopLobbyRoot"
    content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",12)
    add_child(content)
    var title=Label.new()
    title.text="SHATTERED CROWN ECHO — 2人協力ロビー"
    title.add_theme_font_size_override("font_size",27)
    content.add_child(title)
    paragraph("ここでP1とP2が集合します。装備と24枚デッキを確認し、2人の準備完了後に、この画面から冒険へ出発できます。",content)
    var connection=_cooperation_panel(content,"CoopConnectionPanel",Color("637e9c"))
    paragraph("01  接続・部屋作成 / コード参加",connection)
    var connection_row=HFlowContainer.new()
    connection_row.add_theme_constant_override("h_separation",8)
    connection_row.add_theme_constant_override("v_separation",6)
    connection.add_child(connection_row)
    transport=OptionButton.new()
    transport.add_item("Web版：コード中継（公開WSSサーバーが必要）")
    transport.disabled=true
    connection_row.add_child(transport)
    paragraph("Web版ではWindows専用EOSを無効化しています。公開WSS中継サーバーを設定するまでは協力接続できません。",connection)
    var row=HFlowContainer.new()
    row.name="CoopConnectActions"
    row.add_theme_constant_override("h_separation",8)
    row.add_theme_constant_override("v_separation",6)
    connection.add_child(row)
    nickname=LineEdit.new();nickname.placeholder_text="プレイヤー名（任意）";nickname.max_length=20;nickname.custom_minimum_size.x=175;row.add_child(nickname)
    button("部屋を作る / 保存から再開",func():session.host_code(personal_items(),"",nickname.text),row,true)
    code=LineEdit.new();code.placeholder_text="6文字の参加コード";code.max_length=20;code.custom_minimum_size.x=155;row.add_child(code)
    button("コードで参加 / 再接続",func():session.join_code(code.text,personal_items(),"",nickname.text),row,true)
    button("切断・停止",func():session.close();session.status="切断しました。協力保存は保持しています。";render(),row,true)
    button("拠点ホームへ戻る",func():owner_node.region_run_ui.open_hub_page("home");owner_node.tab_container.current_tab=owner_node.region_run_ui.get_index(),row,true)
    status_label=Label.new();status_label.name="CoopConnectionStatus";status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;connection.add_child(status_label)
    seed=SpinBox.new();seed.name="CoopSeedSelector";seed.min_value=1;seed.max_value=999999999;seed.value=20261010;seed.prefix="協力ラン Seed ";seed.visible=false;content.add_child(seed)
    state_box=VBoxContainer.new();state_box.name="CoopLobbyState";state_box.add_theme_constant_override("separation",12);content.add_child(state_box)
    session=CoopCodeSession.new();add_child(session);session.changed.connect(render)
    render()

func _cooperation_panel(parent: Node,panel_name: String,accent: Color) -> VBoxContainer:
    var frame=PanelContainer.new()
    frame.name=panel_name
    frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var style=StyleBoxFlat.new()
    style.bg_color=Color("20242a")
    style.border_color=accent
    style.border_width_left=2
    style.border_width_top=1
    style.border_width_right=1
    style.border_width_bottom=1
    style.corner_radius_top_left=8
    style.corner_radius_top_right=8
    style.corner_radius_bottom_left=8
    style.corner_radius_bottom_right=8
    frame.add_theme_stylebox_override("panel",style)
    parent.add_child(frame)
    var margin=MarginContainer.new()
    for side in ["left","top","right","bottom"]:
        margin.add_theme_constant_override("margin_"+side,12)
    frame.add_child(margin)
    var inner=VBoxContainer.new()
    inner.add_theme_constant_override("separation",7)
    margin.add_child(inner)
    return inner

func _cooperation_title(text: String,parent: Node) -> Label:
    var label=paragraph(text,parent)
    label.add_theme_font_size_override("font_size",19)
    return label

# Browser build deliberately omits the EOS native transport.  The previous
# WSS relay transport remains available after separately configuring a server.
func _select_transport(_index: int) -> void:
    return

func personal_items() -> Dictionary:
    return owner_node.region_run_ui.run.items_from_state()

func paragraph(text: String,parent: Node=null) -> Label:
    var label=Label.new()
    label.text=text
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    (state_box if parent==null else parent).add_child(label)
    return label

func button(text: String,action: Callable,parent: Node=null,always: bool=false) -> Button:
    var b=Button.new();b.text=text;b.custom_minimum_size.y=40
    b.disabled=not always and not session.connected_ok
    b.pressed.connect(action)
    (state_box if parent==null else parent).add_child(b)
    return b

func command(cmd: Dictionary) -> void:
    session.command(cmd)

func _cooperation_member_card(view: Dictionary,seat_index: int,confirmed: Array,parent: Node) -> void:
    var members: Array=view.get("members",[])
    var names: Array=view.get("player_names",["ホスト","参加者"])
    var info: Dictionary=members[seat_index] if seat_index<members.size() else {}
    var inventory: Dictionary=info.get("inventory",{})
    var loadout: Dictionary=info.get("loadout",{})
    var equipped: int=0
    var total_cards: int=0
    var card_lines: Array[String]=[]
    var labels: Dictionary={"main_weapon":"武器","offhand":"オフハンド","head":"頭","body":"胴","hands":"手","feet":"足"}
    for slot in Region1RunController.SLOTS:
        var uid: String=str(loadout.get(slot,""))
        if uid!="" and inventory.has(uid):
            var item: Dictionary=inventory[uid]
            equipped+=1
            total_cards+=item.get("cards",[]).size()
            card_lines.append("%s：%s（%d枚）"%[str(labels.get(slot,slot)),str(item.get("rarity","-")),item.get("cards",[]).size()])
        else:
            card_lines.append("%s：未登録"%str(labels.get(slot,slot)))
    var connected: bool=session.connected_ok
    var waiting: bool=seat_index==1 and not connected
    var ready: bool=connected and seat_index<confirmed.size() and bool(confirmed[seat_index])
    var panel=_cooperation_panel(parent,"CoopPlayerCardP%d"%(seat_index+1),Color("4a997d") if ready else Color("677b95"))
    _cooperation_title("P%d  %s%s"%[seat_index+1,str(names[seat_index]) if seat_index<names.size() else "参加者","  / ホスト" if seat_index==0 else "  / ゲスト"],panel)
    var state: String="準備完了 ✓" if ready else ("参加待ち" if waiting else ("接続済み・準備待ち" if connected else "保存状態・接続待ち"))
    paragraph("接続・準備："+state,panel)
    paragraph("装備  %d / 6部位    デッキ  %d / 24枚"%[equipped,total_cards],panel)
    if coop_player_details_open:
        for line in card_lines:paragraph(line,panel)
    if not info.is_empty() and str(view.get("phase",""))=="hub":
        var progress: Array=info.get("region_progress",[])
        var active: int=clampi(int(info.get("active_region",0)),0,5)
        var cleared: int=int(progress[active]) if active<progress.size() else 0
        paragraph("協力進行：Region %d  %d / 4 Boss"%[active+1,cleared],panel)

func _cooperation_ready_panel(view: Dictionary,mine: int,confirmed: Array) -> void:
    var wrap=_cooperation_panel(state_box,"CoopReadyPanel",Color("ae8f50"))
    _cooperation_title("02  2人の装備と準備完了",wrap)
    var players=HBoxContainer.new()
    players.name="CoopPlayerCards"
    players.add_theme_constant_override("separation",12)
    wrap.add_child(players)
    for i in range(2):
        var card=VBoxContainer.new()
        card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        players.add_child(card)
        _cooperation_member_card(view,i,confirmed,card)
    var detail=button("6部位の装備詳細を閉じる ▲" if coop_player_details_open else "6部位の装備詳細を表示 ▼",func():coop_player_details_open=not coop_player_details_open;render(),wrap,true)
    detail.name="CoopPlayerDetailsToggle"
    if not session.connected_ok:
        paragraph("P2の参加待ちです。ホストは参加コードを友人へ伝えてください。両者の接続後に準備できます。",wrap)
    elif not confirmed.all(func(v):return bool(v)):
        paragraph("2人が各自の画面で準備完了すると、冒険先を選べます。",wrap)
        if mine<confirmed.size() and not bool(confirmed[mine]):
            var ready=button("自分の装備・24枚を確認して準備完了",command.bind({"op":"ready"}),wrap)
            ready.name="CoopReadyButton"
        else:
            paragraph("あなたは準備完了です。相手の準備を待っています。",wrap)
    else:
        paragraph("✓ P1・P2ともに準備完了。協力冒険の出発操作に進めます。",wrap)

func _cooperation_departure_waiting(connected: bool,confirmed: Array) -> void:
    var wrap=_cooperation_panel(state_box,"CoopDeparturePanel",Color("686868"))
    _cooperation_title("03  協力ダンジョンへ出発",wrap)
    if not connected:
        paragraph("P2の参加待ち：2人が接続すると準備完了に進めます。",wrap)
    elif not confirmed.all(func(v):return bool(v)):
        paragraph("P1・P2の準備完了待ち：両方の準備後に地域選択と出発操作が有効になります。",wrap)
    else:
        paragraph("出発準備を確認しています。",wrap)
    var launch=button("2人で冒険へ出発（準備完了後に有効）",func():pass,wrap,true)
    launch.name="CoopLaunchWaitingButton"
    launch.disabled=true

func _cooperation_departure_panel(view: Dictionary,mine: int,member: Dictionary) -> void:
    var wrap=_cooperation_panel(state_box,"CoopDeparturePanel",Color("b69c55"))
    _cooperation_title("03  協力ダンジョンへ出発",wrap)
    var region_index: int=clampi(int(member.get("active_region",0)),0,5)
    var region_progress: Array=member.get("region_progress",[])
    var cleared: int=int(region_progress[region_index]) if region_index<region_progress.size() else 0
    paragraph("現在の冒険先：%s   /   %d / 4 Boss"%[RegionCatalog.title(region_index),cleared],wrap)
    var proposal: Dictionary=view.get("proposal",{})
    if not proposal.is_empty():
        var kind: String=str(proposal.get("kind",""))
        var value: int=int(proposal.get("value",0))
        var proposed: String=RegionCatalog.title(value) if kind=="region" and value>=0 and value<6 else ("協力冒険の出発（Seed %d）"%value if kind=="begin" else "次の進行")
        paragraph("ホストの提案："+proposed,wrap)
        if mine==1:
            var confirm=button("提案を承認" if kind=="region" else "2人で冒険に出発（承認）",command.bind({"op":"confirm"}),wrap)
            confirm.name="CoopConfirmProposalButton"
        else:
            paragraph("P2の承認待ちです。承認後、同じダンジョンへ進みます。",wrap)
            button("提案を取り消す",command.bind({"op":"cancel_proposal"}),wrap)
        return
    if mine==1:
        paragraph("ホストが地域と出発を提案します。P2が承認すると2人で進行します。",wrap)
        return
    var choice=OptionButton.new()
    choice.name="CoopRegionSelector"
    choice.custom_minimum_size.x=340
    wrap.add_child(choice)
    for i in range(6):
        choice.add_item(RegionCatalog.title(i),i)
        var unlocked: bool=i==0 or (i-1<region_progress.size() and int(region_progress[i-1])>=4)
        choice.set_item_disabled(i,not unlocked)
    choice.select(region_index)
    var change=button("冒険地域を変更（P2に確認）",func():_propose_selected_region(choice,region_index),wrap)
    change.name="CoopRegionProposalButton"
    change.disabled=region_progress.size()<6
    seed.visible=true
    seed.reparent(wrap)
    var launch=button("2人で冒険へ出発（P2に確認）",func():command({"op":"propose","kind":"begin","value":int(seed.value)}),wrap)
    launch.name="CoopLaunchProposalButton"
    launch.disabled=cleared>=4 or not member.get("forge_pending",{}).is_empty()
    if cleared>=4:paragraph("このRegionは攻略済みです。次のRegionを選んでください。",wrap)

func _propose_selected_region(choice: OptionButton,current_region: int) -> void:
    var selected: int=choice.get_selected_id()
    if selected!=current_region:command({"op":"propose","kind":"region","value":selected})

func _cooperation_management(member: Dictionary) -> void:
    var box=_cooperation_panel(state_box,"CoopEquipmentManagement",Color("5c6772"))
    var toggle=button("協力保存の装備・鍛冶管理を閉じる ▲" if coop_management_open else "協力保存の装備・鍛冶管理を開く ▼",func():coop_management_open=not coop_management_open;render(),box)
    toggle.name="CoopManageToggle"
    if not coop_management_open and member.get("forge_pending",{}).is_empty():return
    paragraph("ここで変更できるのは協力キャンペーン用の装備のみです。ソロ拠点の装備・保存とは別管理です。",box)
    if not member.get("forge_pending",{}).is_empty():
        paragraph("再抽選結果の選択が必要です。完了すると出発できます。",box)
        var choices: Array=member.forge_pending.get("choices",[])
        for i in range(mini(2,choices.size())):button("候補%d：%s"%[i+1,str(choices[i])],command.bind({"op":"forge_select","index":i}),box)
        button("元のカードを維持",command.bind({"op":"forge_select","index":-1}),box)
        return
    if not coop_management_open:return
    var inventory: Dictionary=member.get("inventory",{})
    var loadout: Dictionary=member.get("loadout",{})
    var uids: Array=inventory.keys();uids.sort()
    for uid in uids:
        var item: Dictionary=inventory[uid]
        paragraph("%s%s / %s / HP%d / %s"%["【装備中】" if loadout.values().has(uid) else "",str(item.slot),str(item.rarity),int(item.get("effective_hp",item.base_hp)),str(item.cards)],box)
        var row=HFlowContainer.new();box.add_child(row)
        button("装備",command.bind({"op":"equip","uid":uid}),row)
        button("HP強化 %dG / 素材1"%(100*(int(item.get("enhance_level",0))+1)),command.bind({"op":"forge","uid":uid,"action":"enhance"}),row)
        button("Socket拡張 %dG / 素材1"%(250+150*int(item.get("socket_count",0))),command.bind({"op":"forge","uid":uid,"action":"socket"}),row)
        for slot in range(2):button("ランダム%d再抽選 250G / 素材1"%(slot+1),command.bind({"op":"forge","uid":uid,"action":"reroll","slot":slot}),row)
        button("分解（装備中は不可）",func():confirm_dismantle(str(uid)),row)

func render() -> void:
    if status_label==null:return
    status_label.text=session.status
    if seed.get_parent()!=content:seed.reparent(content)
    seed.visible=false
    for child in state_box.get_children():
        state_box.remove_child(child)
        child.queue_free()
    enemy_buttons.clear();player_labels.clear()
    display_serial+=1
    if str(session.view.get("phase",""))!="battle":
        var was_battle: bool=not previous_fight.is_empty()
        previous_fight.clear();presentation.clear_effects()
        if was_battle and is_visible_in_tree():
            var phase_name: String=str(session.view.get("phase",""))
            if phase_name in ["reward","defeat"]:presentation._popup("協力戦闘："+("勝利" if phase_name=="reward" else "敗北"),Vector2(650,220),Color("ffd17c"))
    var view: Dictionary=session.view
    if view.is_empty():
        var empty=_cooperation_panel(state_box,"CoopWaitingPanel",Color("62788b"))
        _cooperation_title("P1が部屋を作成 / P2が参加コードを入力",empty)
        paragraph("各自の個人拠点で6部位の装備を選んでください。参加後はここで2人の準備状況を確認できます。",empty)
        paragraph("ソロのダンジョン出発画面に移動する必要はありません。",empty)
        _cooperation_departure_waiting(false,[false,false])
        return
    var mine: int=int(view.get("seat",session.seat))
    var confirmed: Array=view.get("confirmed",[false,false])
    var room=_cooperation_panel(state_box,"CoopRoomHeader",Color("628eaf"))
    _cooperation_title("協力ルーム  /  あなたはP%d（%s）"%[mine+1,"ホスト" if session.hosting else "ゲスト"],room)
    if session.hosting and session.room_code!="":
        paragraph("参加コード：%s"%session.room_code,room)
        var copy=button("6文字の参加コードをコピー",func():DisplayServer.clipboard_set(session.room_code),room,true)
        copy.name="CoopCopyRoomCodeButton"
    elif session.room_code!="":
        paragraph("参加先コード：%s"%session.room_code,room)
    var phase: String=str(view.get("phase",""))
    if phase=="hub" or not session.connected_ok or not confirmed.all(func(v):return bool(v)):
        _cooperation_ready_panel(view,mine,confirmed)
    else:
        paragraph("P1 / P2 — 協力キャンペーン進行中",state_box)
    if not session.connected_ok or not confirmed.all(func(v):return bool(v)):
        # A newly created host room has phase="lobby" until P2 registers.
        # Keep section 03 visible as disabled in both pre-adventure phases.
        if phase in ["lobby","hub"]:
            _cooperation_departure_waiting(session.connected_ok,confirmed)
        return
    var members: Array=view.get("members",[])
    if mine<0 or mine>=members.size():return
    var member: Dictionary=members[mine]
    if phase=="hub":
        _cooperation_departure_panel(view,mine,member)
        _cooperation_management(member)
        return
    paragraph("協力キャンペーン進行中 — この画面から引き続き2人で操作できます。")
    for i in range(mini(2,members.size())):
        var m: Dictionary=members[i]
        paragraph("P%d — %s　拠点 %dG / 素材%d　進行%s"%[i+1,str(m.phase),int(m.base_gold),int(m.materials),str(m.region_progress)])
    if not view.get("proposal",{}).is_empty():
        var proposal: Dictionary=view.proposal
        paragraph("ホストの提案：%s %s"%[str(proposal.kind),str(proposal.value)])
        if mine==1:button("提案を確認して進む",command.bind({"op":"confirm"}))
        else:button("提案を取り消す",command.bind({"op":"cancel_proposal"}))
    if phase=="battle": render_battle(view,mine)
    else:
        if not member.run.is_empty(): paragraph("あなたのラン：HP%d/%d　%dG　素材%d　戦利品%d"%[int(member.run.hp),int(member.run.max_hp),int(member.run.gold),int(member.run.materials),member.run.bag.size()])
        if str(member.phase)=="route":
            if view.members.all(func(m):return str(m.phase)=="route") and mine==0 and view.proposal.is_empty():
                for i in range(member.run.routes.size()): button("道：%sを提案"%str(member.run.routes[i]),command.bind({"op":"propose","kind":"route","value":i}))
            else: paragraph("相手の報酬・施設操作、またはホストの道の提案を待っています。")
        elif str(member.phase)=="reward":
            paragraph("候補にマウスを合わせると、装備特殊効果と4枚のカード詳細を確認できます。")
            var offer_row=HBoxContainer.new()
            offer_row.name="CoopRewardEquipmentPreview"
            offer_row.add_theme_constant_override("separation",14)
            state_box.add_child(offer_row)
            var choices=VBoxContainer.new()
            choices.custom_minimum_size.x=380
            choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
            offer_row.add_child(choices)
            var hover_panel=EquipmentOfferHoverPanel.new()
            offer_row.add_child(hover_panel)
            for i in range(member.run.rewards.size()):
                var offer_item: Dictionary=member.run.rewards[i]
                var b=button("報酬：%s"%EquipmentOfferHoverPanel.offer_button_text(offer_item,i),command.bind({"op":"reward","index":i}),choices)
                b.custom_minimum_size.y=82
                b.mouse_entered.connect(hover_panel.show_item.bind(offer_item.duplicate(true)))
                b.focus_entered.connect(hover_panel.show_item.bind(offer_item.duplicate(true)))
            button("装備報酬を受け取らずに進む",command.bind({"op":"reward","index":-1}),choices)
        elif str(member.phase)=="service": render_service(member)
        elif str(member.phase)=="defeat":
            paragraph("両者戦闘不能。Bodyの容量以内で持ち帰る戦利品を選択してください（選択：%s）。"%str(retained))
            for i in range(member.run.bag.size()):
                button("%s%s"%["✓ " if retained.has(i) else "",item_text(member.run.bag[i])],func():
                    if retained.has(i): retained.erase(i)
                    elif retained.size()<int(member.run.body_cap): retained.append(i)
                    render())
            button("選択して拠点へ",func():command({"op":"defeat","indices":retained.duplicate()});retained.clear())
    if phase!="hub": button("両者で拠点へ帰還を要求",command.bind({"op":"retreat"}))

func item_text(item: Dictionary) -> String:
    if item.is_empty(): return "購入済み"
    return "%s / %s / HP%d / %s / %s"%[str(item.slot),str(item.rarity),int(item.get("effective_hp",item.base_hp)),str(item.cards),EquipmentSpecialEffectPolicy.brief(item)]

func confirm_dismantle(uid: String) -> void:
    var dialog=ConfirmationDialog.new(); dialog.dialog_text="この協力用装備を分解して素材にします。"; add_child(dialog)
    dialog.confirmed.connect(func():command({"op":"forge","uid":uid,"action":"dismantle"});dialog.queue_free())
    dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()

func render_service(member: Dictionary) -> void:
    var kind: String=str(member.run.kind)
    paragraph("施設：%s。購入効果はあなた自身に適用します。"%kind)
    if kind=="shop":
        if str(member.run.get("shop_npc","merchant"))=="priest":
            paragraph("僧侶 — 回復と次戦支援",state_box)
            for entry in [["heal","35%回復 90G",90],["full_heal","全回復 220G",220],["block","次戦Block4 60G",60],["attack","次戦Attack支援 60G",60],["draw","次戦Draw1 60G",60]]:
                var action=button(str(entry[1]),command.bind({"op":"service","action":entry[0]}))
                action.disabled=not session.connected_ok or int(member.run.gold)<int(entry[2]) or (int(member.run.hp)>=int(member.run.max_hp) if str(entry[0]) in ["heal","full_heal"] else member.run.support.has(str(entry[0])))
        else:
            paragraph("遺品商 — 装備と商品更新",state_box)
            var shop_row=HBoxContainer.new()
            shop_row.name="CoopMerchantEquipmentPreview"
            shop_row.add_theme_constant_override("separation",14)
            state_box.add_child(shop_row)
            var choices=VBoxContainer.new()
            choices.custom_minimum_size.x=380
            choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
            shop_row.add_child(choices)
            var hover_panel=EquipmentOfferHoverPanel.new()
            shop_row.add_child(hover_panel)
            for i in range(member.run.stock.size()):
                var stock_item: Dictionary=member.run.stock[i]
                var buy=button("売り切れ" if stock_item.is_empty() else "280G：%s"%EquipmentOfferHoverPanel.offer_button_text(stock_item,i),command.bind({"op":"service","action":"buy","index":i}),choices)
                buy.disabled=not session.connected_ok or stock_item.is_empty() or int(member.run.gold)<280
                if not stock_item.is_empty():
                    buy.custom_minimum_size.y=82
                    buy.mouse_entered.connect(hover_panel.show_item.bind(stock_item.duplicate(true)))
                    buy.focus_entered.connect(hover_panel.show_item.bind(stock_item.duplicate(true)))
            var refresh=button("商品更新 70G",command.bind({"op":"service","action":"refresh"}),choices)
            refresh.disabled=not session.connected_ok or int(member.run.gold)<70
        button("施設を出る",command.bind({"op":"service","action":"leave"}))
    elif kind=="rest": button("35%回復して進む",command.bind({"op":"service","action":"heal"}))
    elif kind=="event":
        for entry in [["heal","20%回復"],["gold","80G獲得"],["material","素材2獲得"]]:button(str(entry[1]),command.bind({"op":"service","action":entry[0]}))

func render_battle(view: Dictionary,mine: int) -> void:
    var fight: Dictionary=view.combat
    var me: Dictionary=fight.players[mine]
    var can_act: bool=int(fight.active)==mine and int(me.hp)>0 and not bool(fight.finished)
    paragraph("ラウンド%d — P%dの行動 / クリックで敵を選び、カードを使用"%[int(fight.round),int(fight.active)+1])
    var auto=CheckButton.new(); auto.text="自分のオートバトル"; auto.set_pressed_no_signal(bool(view.auto[mine])); state_box.add_child(auto)
    auto.toggled.connect(func(enabled):command({"op":"auto","enabled":enabled}))
    var options=HFlowContainer.new();state_box.add_child(options)
    var vfx=OptionButton.new();options.add_child(vfx)
    for option in ["VFX 通常","VFX 軽量","VFX OFF"]:vfx.add_item(option)
    vfx.select(2-BattlePresentation.quality)
    vfx.item_selected.connect(func(index):BattlePresentation.quality=2-index;presentation.clear_effects())
    button("演出スキップ",presentation.clear_effects,options,true)
    can_act=can_act and not bool(view.auto[mine])
    for i in range(2):
        var player: Dictionary=fight.players[i]
        var player_label=paragraph("P%d　HP%d/%d　Mana%d　Block%d%s\n武器 %s / 属性 %s / 状態 %s"%[i+1,int(player.hp),int(player.max_hp),int(player.mana),int(player.block),"　戦闘不能" if int(player.hp)==0 else "",active_values(player.weapon_traits),active_values(player.attribute_traits),active_values(player.status)])
        player_labels.append(player_label)
    var grid=GridContainer.new(); grid.columns=3; state_box.add_child(grid)
    selected_enemy=clampi(selected_enemy,0,maxi(0,fight.enemies.size()-1))
    for i in range(fight.enemies.size()):
        var enemy: Dictionary=fight.enemies[i]
        var targets: Array=fight.intents[i].targets
        var b=button("%s%s\nHP%d/%d　Block%d\n%s → %s"%["▶ " if i==selected_enemy else "",str(enemy.id),int(enemy.hp),int(enemy.max_hp),int(enemy.block),str(fight.intents[i].intent.get("label",fight.intents[i].intent.get("name","Intent"))),str(targets)],func():selected_enemy=i;render(),grid)
        b.custom_minimum_size=Vector2(270,120); b.icon=MonsterPortrait.texture_for(str(enemy.id)); b.expand_icon=true
        b.disabled=int(enemy.hp)<=0; enemy_buttons.append(b)
    var pending: String=str(me.pending.get("mode",""))
    if pending!="": paragraph("必須選択：%s　残り%d枚"%[pending,int(me.pending.get("remaining",1))])
    var hand_grid=GridContainer.new(); hand_grid.columns=5; state_box.add_child(hand_grid)
    var cards: Array=me.discard if pending=="salvage" else me.hand
    var icons={"mana":owner_node._get_ui_icon("mana"),"attack":owner_node._get_ui_icon("attack"),"block":owner_node._get_ui_icon("block")}
    for i in range(cards.size()):
        var card: Dictionary=cards[i]
        var info: Dictionary=me.cards_info[i] if pending!="salvage" else {"cost":0,"usable":true,"target":"none"}
        var b=CardButton.new(); b.hand_index=i; b.custom_minimum_size=Vector2(200,230)
        b.configure(card,int(info.cost),icons,false,pending!="",bool(info.usable))
        b.mark_attribute_condition(BattleCardPreview.public_condition(card,me,fight.enemies[selected_enemy]))
        if str(info.target)=="enemy":b.role_label.text+=" / 対象#%d"%(selected_enemy+1)
        b.tooltip_text=WeaponTraitCardDescription.combined_text(card)+"\n対象#%d。協力画面の数値は基本値です。最終予測値は未提供。"%(selected_enemy+1); b.disabled=not can_act or (pending=="" and not bool(info.usable)); hand_grid.add_child(b)
        b.card_clicked.connect(func(index):
            var kind: String="salvage" if pending=="salvage" else ("select" if pending!="" else "card")
            var target: int=selected_enemy if str(info.target)=="enemy" else -1
            command({"op":"combat","action":{"kind":kind,"index":index,"id":str(card.id),"target":target}}))
    button("自分のターンを終了",command.bind({"op":"combat","action":{"kind":"end","index":-1,"id":"~END","target":-1}})).disabled=not can_act or pending!=""
    paragraph("相手の手札：%s\n自分の山札%d / 捨て札%d / Power%d"%[str(fight.players[1-mine].hand.map(func(c):return c.id)),int(me.draw_count),me.discard.size(),me.power.size()])
    if str(me.notice)!="": paragraph(str(me.notice))
    var log=RichTextLabel.new(); log.custom_minimum_size.y=160; log.bbcode_enabled=false; state_box.add_child(log)
    log.text="\n".join(me.logs)
    var old: Dictionary=previous_fight.duplicate(true)
    previous_fight=fight.duplicate(true)
    if not old.is_empty() and JSON.stringify(old)!=JSON.stringify(fight):
        _present_confirmed.call_deferred(old,fight.duplicate(true),display_serial)

func _present_confirmed(before: Dictionary,after: Dictionary,serial: int) -> void:
    await get_tree().process_frame
    if serial!=display_serial or not is_visible_in_tree():return
    var points: Array=[]
    for enemy in enemy_buttons:points.append(enemy.get_global_rect().get_center()-presentation.global_position)
    for seat in range(mini(before.players.size(),after.players.size())):
        var a: Dictionary=before.players[seat].duplicate(true);var b: Dictionary=after.players[seat].duplicate(true)
        a.enemies=before.enemies if seat==0 else [];b.enemies=after.enemies if seat==0 else []
        var point: Vector2=player_labels[seat].get_global_rect().get_center()-presentation.global_position if seat<player_labels.size() else Vector2(160,160)
        # Confirmed snapshots only: no inferred individual Hit or unknown Draw order.
        presentation.show_changes(a,b,points,point,point,enemy_buttons)



func active_values(values: Dictionary) -> String:
    var parts: PackedStringArray=[]
    for key in values:
        if values[key] is bool:
            if values[key]: parts.append(str(key)+" ON")
        elif int(values[key])>0: parts.append(str(key)+" "+str(values[key]))
    return "なし" if parts.is_empty() else " / ".join(parts)
