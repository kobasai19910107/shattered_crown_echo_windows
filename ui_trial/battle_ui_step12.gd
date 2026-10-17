extends Control
## STEP12: R1-B01 13-layer anatomical-hierarchy visual-only boss rig; all other enemies use STEP9. Battle Core unchanged.
## Project root must contain official scripts and data as on the 2026-10-16 Web Solo branch.
const HERO_SCRIPT = preload("res://ui_trial/actors/actor3h.gd")
const ENEMY_SCRIPT = preload("res://ui_trial/actors/boss_b01_rig_step12.gd")
const FX_SCRIPT = preload("res://ui_trial/vfx/attribute_fx.gd")
const BG = preload("res://ui_trial/assets/battle_background.webp")
const PORTRAIT = preload("res://ui_trial/assets/cutin_temp.webp")
const STAGE := Vector2(1280.0, 720.0)
const GOLD := Color("d7b57e")
const WHITE := Color("f4ede5")
const DIM := Color("abb5c6")
const INK := Color(0.031,0.044,0.077,0.95)
var stage: Control
var hero
var fx
var actors: Array[Node2D] = []
var enemy_huds: Array[Control] = []
var enemy_mini_fills: Array[ColorRect] = []
var enemy_buttons: Array[Button] = []
var card_buttons: Array[Button] = []
var mode_buttons: Dictionary = {}
var selected_index: int = -1
var tier: String = "mob"
var busy: bool = false
var speed: float = 1.0
var status: Label
var hero_status: Label
var enemy_main_label: Label
var intent_label: Label
var turn_label: Label
var mana_label: Label
var selection_label: Label
var hero_hp_fill: ColorRect
var enemy_hp_fill: ColorRect
var cutin: Control
var cutin_title: Label
var damage_text: Label
var field_layer: Control
var _acting_target: int = -1
var _current_animation: String = ""
var _last_attribute: String = "物理"
var _last_damage: int = 0
var battle: BattleController
var event_log: Array[Dictionary] = []
var card_page: int = 0
const VISIBLE_CARDS := 5
const PRESETS := {"mob":"standard_trio", "elite":"armored_pair", "boss":"boss_solo"}
var hand_prev: Button
var hand_next: Button
var pile_info: Label
var trait_info: Label
var current_title: String = ""
var salvage_popup: PopupPanel
var event_playback: Array = []
var _running_action: bool = false
var campaign_mode: bool = false
var campaign_changed: Callable = Callable()
var campaign_old_ui: Callable = Callable()
var campaign_route_ui: Callable = Callable()
var campaign_buttons: Array[Button] = []
var campaign_kind: String = "battle"
var enemy_id_cache: Array[String] = []
var shown_phase_cache: Array[int] = []
var phase_banner: Control
var phase_heading: Label
var phase_portrait: TextureRect
var scene_backdrop: TextureRect
const REGION_TINT := ["a2bac1","5aaf83","e66a4e","6bcbf7","edce8e","a78bfa"]

func _ready() -> void:
    battle = BattleController.new()
    battle.presentation_event.connect(_capture_event)
    stage = Control.new()
    stage.size = STAGE
    stage.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(stage)
    _scale_stage()
    resized.connect(_scale_stage)
    _background()
    _make_field()
    _make_hud()
    _make_cards()
    _make_cutin()
    _create_hero()
    _set_tier("mob")

func _scale_stage() -> void:
    if stage == null:return
    var factor: float = minf(size.x / STAGE.x, size.y / STAGE.y)
    stage.scale = Vector2(factor,factor)
    stage.position = (size-STAGE*factor)*0.5

func _panel(parent: Node, pos: Vector2, extent: Vector2, fill: Color, edge: Color=Color.GRAY) -> PanelContainer:
    var p := PanelContainer.new()
    p.position = pos
    p.size = extent
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = edge
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    p.add_theme_stylebox_override("panel",style)
    parent.add_child(p)
    return p

func _label(parent: Node, value: String, font_size: int, tint: Color, pos: Vector2, extent: Vector2) -> Label:
    var l := Label.new()
    l.text = value
    l.position = pos
    l.size = extent
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color",tint)
    parent.add_child(l)
    return l

func _bar(parent: Node, pos: Vector2, extent: Vector2, fill: Color) -> ColorRect:
    var back := ColorRect.new()
    back.color = Color("151824")
    back.position = pos
    back.size = extent
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(back)
    var current := ColorRect.new()
    current.position = pos+Vector2(2,2)
    current.size = extent - Vector2(4,4)
    current.color = fill
    current.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(current)
    return current

func _button(parent: Node, title: String, pos: Vector2, extent: Vector2, action: Callable, accent: bool=false) -> Button:
    var b := Button.new()
    b.text = title
    b.position = pos
    b.size = extent
    b.add_theme_font_size_override("font_size",17)
    b.add_theme_color_override("font_color",WHITE)
    var flat := StyleBoxFlat.new()
    flat.bg_color = Color("3b2735") if accent else Color("222c40")
    flat.border_color = Color("d69f67") if accent else Color("74839c")
    flat.set_border_width_all(2 if accent else 1)
    flat.set_corner_radius_all(8)
    b.add_theme_stylebox_override("normal",flat)
    var hover := flat.duplicate() as StyleBoxFlat
    hover.bg_color = Color("604052") if accent else Color("39465c")
    b.add_theme_stylebox_override("hover",hover)
    parent.add_child(b)
    b.pressed.connect(action)
    return b

func _background() -> void:
    var backdrop := TextureRect.new()
    backdrop.texture = BG
    backdrop.size = STAGE
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(backdrop)
    scene_backdrop=backdrop
    var filter := ColorRect.new()
    filter.color = Color(0.02,0.028,0.055,0.24)
    filter.size = STAGE
    filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(filter)

func _make_field() -> void:
    field_layer = Control.new()
    field_layer.position = Vector2.ZERO
    field_layer.size = STAGE
    field_layer.mouse_filter = Control.MOUSE_FILTER_PASS
    stage.add_child(field_layer)
    _panel(field_layer,Vector2(25,100),Vector2(520,35),Color(0.025,0.039,0.070,0.79),Color("656074"))
    _label(field_layer,"STEP 12 ・ R1-B01可動リグ / 実戦闘連動",16,DIM,Vector2(36,107),Vector2(490,28))
    _panel(field_layer,Vector2(525,101),Vector2(235,36),Color(0.025,0.039,0.070,0.75),Color("656074"))
    _label(field_layer,"戦闘プリセット切替",16,GOLD,Vector2(545,108),Vector2(216,27))
    for i in range(3):
        var mode: String = ["mob","elite","boss"][i]
        var name: String = ["モブ","エリート","ボス"][i]
        mode_buttons[mode] = _button(stage,name,Vector2(771+109*i,100),Vector2(103,37),_set_tier.bind(mode))
    fx = Node2D.new()
    fx.set_script(FX_SCRIPT)
    fx.z_index = 8
    field_layer.add_child(fx)
    damage_text = _label(field_layer,"",30,Color("ffd59a"),Vector2(820,325),Vector2(290,70))
    damage_text.visible = false

func _make_hud() -> void:
    _panel(stage,Vector2(0,0),Vector2(1280,96),Color(0.015,0.024,0.044,0.93),Color("8c6d53"))
    _label(stage,"SHATTERED CROWN ECHO",28,WHITE,Vector2(26,9),Vector2(450,38))
    _label(stage,"P1  / Battle Core",17,GOLD,Vector2(30,51),Vector2(290,28))
    hero_hp_fill = _bar(stage,Vector2(200,60),Vector2(195,15),Color("b74351"))
    hero_status = _label(stage,"",15,WHITE,Vector2(202,38),Vector2(408,25))
    enemy_main_label = _label(stage,"",17,WHITE,Vector2(633,6),Vector2(510,30))
    enemy_hp_fill = _bar(stage,Vector2(630,40),Vector2(550,15),Color("bd4b55"))
    intent_label = _label(stage,"",15,Color("ffd3ac"),Vector2(634,64),Vector2(390,25))
    turn_label = _label(stage,"",16,WHITE,Vector2(1186,65),Vector2(90,26))

func _make_cards() -> void:
    _panel(stage,Vector2(0,509),Vector2(1280,211),INK,Color("947356"))
    pile_info = _label(stage,"実デッキ / 実手札",13,DIM,Vector2(22,514),Vector2(325,25))
    trait_info = _label(stage,"",13,DIM,Vector2(450,515),Vector2(550,26))
    _panel(stage,Vector2(26,559),Vector2(113,120),Color("0e2546"),Color("6bc1f4"))
    mana_label = _label(stage,"Mana",23,Color("b3e9ff"),Vector2(41,575),Vector2(97,80))
    mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    for i in range(VISIBLE_CARDS):
        var bx := 164.0 + 166.0*i
        var btn := _button(stage,"",Vector2(bx,548),Vector2(156,145),_card_pressed.bind(i),false)
        btn.add_theme_font_size_override("font_size",15)
        btn.clip_text = true
        card_buttons.append(btn)
    hand_prev = _button(stage,"◀ 手札",Vector2(175,513),Vector2(96,32),_switch_page.bind(-1))
    hand_next = _button(stage,"手札 ▶",Vector2(283,513),Vector2(96,32),_switch_page.bind(1))
    _button(stage,"使用",Vector2(1005,552),Vector2(112,43),_use_selected)
    _button(stage,"解除",Vector2(1127,552),Vector2(110,43),_clear_selection)
    _button(stage,"ターン終了",Vector2(1004,604),Vector2(232,65),_end_turn,true)
    selection_label = _label(stage,"カード選択 → 敵指定 / 自分向けは再タップ",14,DIM,Vector2(163,689),Vector2(1020,25))
    status = _label(stage,"",14,Color("f1ce99"),Vector2(34,465),Vector2(1200,33))
    status.text = "実際のBattle Coreを使用する独立試作です。"

func _make_cutin() -> void:
    cutin = Control.new()
    cutin.size = Vector2(485,225)
    cutin.position = Vector2(-510,169)
    cutin.modulate.a = 0.0
    cutin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin.z_index = 15
    stage.add_child(cutin)
    var back := ColorRect.new()
    back.color = Color(0.12,0.02,0.04,0.88)
    back.size = cutin.size
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin.add_child(back)
    var art := TextureRect.new()
    art.texture = PORTRAIT
    art.size = cutin.size
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin.add_child(art)
    var shade := ColorRect.new()
    shade.position = Vector2(0,177)
    shade.size = Vector2(485,48)
    shade.color = Color(0.08,0.02,0.05,0.88)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin.add_child(shade)
    cutin_title = _label(cutin,"",27,Color("ffe4c3"),Vector2(26,184),Vector2(450,39))
    phase_banner=Control.new()
    phase_banner.position=Vector2(365,165)
    phase_banner.size=Vector2(555,190)
    phase_banner.modulate.a=0.0
    phase_banner.visible=false
    phase_banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
    phase_banner.z_index=18
    stage.add_child(phase_banner)
    _panel(phase_banner,Vector2(0,0),Vector2(555,190),Color(0.07,0.02,0.07,0.92),Color("d5aa76"))
    phase_portrait=TextureRect.new()
    phase_portrait.position=Vector2(12,7)
    phase_portrait.size=Vector2(170,165)
    phase_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    phase_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    phase_portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
    phase_banner.add_child(phase_portrait)
    phase_heading=_label(phase_banner,"",25,GOLD,Vector2(191,54),Vector2(351,104))
    phase_heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _create_hero() -> void:
    hero = Node2D.new()
    hero.set_script(HERO_SCRIPT)
    hero.position = Vector2(311,504)
    hero.scale = Vector2(0.63,0.63)
    field_layer.add_child(hero)
    hero.impact_frame.connect(_hero_impact)

func _enemy_base(index: int) -> Vector2:
    if tier == "mob": return Vector2(826.0 + index*140.0, 505.0)
    if tier == "elite": return Vector2(850.0 + index*245.0, 506.0)
    return Vector2(940.0, 506.0)

func _set_tier(next_tier: String) -> void:
    if busy or _running_action or not PRESETS.has(next_tier):return
    tier = next_tier
    selected_index = -1
    card_page = 0
    event_log.clear()
    if not campaign_mode:
        battle.start_battle(20261016,[],str(PRESETS[tier]))
    event_log.clear() # ignore initial draw notifications; no gameplay mutation
    _rebuild_enemy_visuals()
    _refresh_hud()
    status.text = ("本編ランのBattle Coreと同期中。演出のみを変更します。" if campaign_mode
        else "実戦闘データ: %s / seed=20261016 / 本編進行への保存なし" % str(PRESETS[tier]))

func _rebuild_enemy_visuals() -> void:
    for a in actors:
        if is_instance_valid(a):a.queue_free()
    for hud in enemy_huds:
        if is_instance_valid(hud):hud.queue_free()
    for button in enemy_buttons:
        if is_instance_valid(button):button.queue_free()
    actors.clear()
    enemy_id_cache.clear()
    shown_phase_cache.clear()
    enemy_huds.clear()
    enemy_mini_fills.clear()
    enemy_buttons.clear()
    if scene_backdrop!=null and battle.get_enemy_count()>0:
        var first_id: String=str(battle.get_enemy(0).get("id",""))
        var first_region: int=clampi(int(first_id.substr(1,1)) if first_id.begins_with("R") else 1,1,6)
        scene_backdrop.modulate=Color.WHITE.lerp(Color(REGION_TINT[first_region-1]),0.20)
    for i in range(battle.get_enemy_count()):
        var a := Node2D.new()
        a.set_script(ENEMY_SCRIPT)
        var enemy_data: Dictionary=battle.get_enemy(i)
        a.call("configure_region",enemy_data,tier)
        enemy_id_cache.append(str(enemy_data.get("id","")))
        shown_phase_cache.append(int(enemy_data.get("phase_index",0)))
        a.position = _enemy_base(i)
        a.scale = Vector2(0.63,0.63) if tier=="mob" else (Vector2(0.88,0.88) if tier=="elite" else Vector2(1.07,1.07))
        field_layer.add_child(a)
        actors.append(a)
        var x: float = _enemy_base(i).x
        var w: float = 120.0 if tier=="mob" else (185.0 if tier=="elite" else 245.0)
        var y: float = 291.0 if tier=="mob" else (207.0 if tier=="elite" else 142.0)
        var info := Control.new()
        info.position = Vector2(x-w*0.5,y)
        info.size = Vector2(w,66)
        info.mouse_filter = Control.MOUSE_FILTER_IGNORE
        field_layer.add_child(info)
        enemy_huds.append(info)
        _panel(info,Vector2(0,0),Vector2(w,64),Color(0.015,0.025,0.05,0.82),Color("98675f"))
        _label(info,"",12,WHITE,Vector2(6,2),Vector2(w-12,47))
        enemy_mini_fills.append(_bar(info,Vector2(9,54),Vector2(w-18,7),Color("c45761")))
        var click := Button.new()
        click.position = Vector2(x-(86 if tier=="mob" else 128),y+64)
        click.size = Vector2(172 if tier=="mob" else 256,maxf(20.0,506.0-(y+64.0)))
        click.flat = true
        click.focus_mode = Control.FOCUS_NONE
        click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        field_layer.add_child(click)
        click.pressed.connect(_enemy_pressed.bind(i))
        enemy_buttons.append(click)

func bind_campaign_battle(source_battle: BattleController, kind: String,
        on_changed: Callable, on_old_ui: Callable, on_route_ui: Callable) -> void:
    # Rebind an existing *live* campaign BattleController. Do not start/reset it.
    if source_battle == null or not is_instance_valid(stage):
        return
    if battle != null and battle.presentation_event.is_connected(_capture_event):
        battle.presentation_event.disconnect(_capture_event)
    battle = source_battle
    if not battle.presentation_event.is_connected(_capture_event):
        battle.presentation_event.connect(_capture_event)
    campaign_mode = true
    campaign_kind = kind
    campaign_changed = on_changed
    campaign_old_ui = on_old_ui
    campaign_route_ui = on_route_ui
    for button in mode_buttons.values():
        (button as Button).visible = false
    if campaign_buttons.is_empty():
        campaign_buttons.append(_button(stage, "従来UIに戻す", Vector2(768,100),
            Vector2(210,37), _return_to_old_ui))
        campaign_buttons.append(_button(stage, "進行画面", Vector2(985,100),
            Vector2(190,37), _return_to_route_ui))
    for button in campaign_buttons:
        button.visible = true
    _set_tier({"battle":"mob", "elite":"elite", "boss":"boss"}.get(kind, "mob"))
    # Do not reflect any prototype deck/state into the campaign.
    event_log.clear()
    selected_index = -1
    card_page = 0
    _refresh_hud()

func _return_to_old_ui() -> void:
    if busy: return
    if campaign_old_ui.is_valid(): campaign_old_ui.call()

func _return_to_route_ui() -> void:
    if busy: return
    if campaign_route_ui.is_valid(): campaign_route_ui.call()

func _campaign_checkpoint() -> void:
    if campaign_mode and campaign_changed.is_valid():
        campaign_changed.call()

func _refresh_hud() -> void:
    if battle == null:return
    var identity_changed: bool=actors.size()!=battle.get_enemy_count()
    if not identity_changed:
        for enemy_index in range(battle.get_enemy_count()):
            if enemy_index>=enemy_id_cache.size() or enemy_id_cache[enemy_index]!=str(battle.get_enemy(enemy_index).get("id","")):
                identity_changed=true
                break
    if identity_changed:_rebuild_enemy_visuals()
    var max_hp: int = maxi(1,battle.player_max_hp)
    hero_status.text = "HP %d/%d  Block %d" % [battle.player_hp,max_hp,battle.player_block]
    hero_hp_fill.size.x = 191.0*clampf(float(battle.player_hp)/float(max_hp),0.0,1.0)
    var total_hp: int = 0
    var total_max_hp: int = 0
    var alive_names: Array[String] = []
    var intents: Array[String] = []
    for i in range(battle.get_enemy_count()):
        var e: Dictionary = battle.get_enemy(i)
        total_hp += maxi(0,int(e.get("hp",0)))
        total_max_hp += maxi(1,int(e.get("max_hp",1)))
        if int(e.get("hp",0)) > 0:
            alive_names.append(str(e.get("name","Enemy")))
            intents.append(str(i+1)+":"+battle.get_enemy_intent_display_label(i))
    enemy_main_label.text = " / ".join(alive_names) + "  HP %d/%d" % [total_hp,total_max_hp]
    enemy_hp_fill.size.x = 546.0*clampf(float(total_hp)/float(maxi(1,total_max_hp)),0.0,1.0)
    intent_label.text = "Intent: " + (" | ".join(intents) if not intents.is_empty() else "戦闘終了")
    intent_label.tooltip_text = intent_label.text
    turn_label.text = "TURN %d" % battle.turn_number
    mana_label.text = "Mana\n%d / %d" % [battle.current_mana,BattleController.BASE_MANA]
    pile_info.text = "山札 %d / 捨て札 %d / 手札 %d" % [battle.draw_pile.size(),battle.discard_pile.size(),battle.hand.size()]
    var active: Array[String] = []
    for t in battle.weapon_traits:
        if bool(battle.weapon_traits[t]):active.append(str(t)+" ON")
    for t in battle.attribute_traits:
        if int(battle.attribute_traits[t])>0:active.append(str(t)+" "+str(battle.attribute_traits[t]))
    trait_info.text = " / ".join(active).substr(0,85)
    var max_page: int = maxi(0,int(ceil(float(battle.hand.size())/float(VISIBLE_CARDS)))-1)
    card_page = mini(card_page,max_page)
    hand_prev.disabled = busy or card_page<=0
    hand_next.disabled = busy or card_page>=max_page
    for i in range(VISIBLE_CARDS):
        var idx: int = card_page*VISIBLE_CARDS+i
        var btn: Button = card_buttons[i]
        if idx < battle.hand.size():
            var card: Dictionary = battle.hand[idx]
            btn.visible = true
            var title: String = _card_title(card)
            var role: String = str(card.get("role", ""))
            var effect: String = str(card.get("text", ""))
            btn.text = "◆ %s  %s\n%s / %s\n────────\n%s" % [battle.get_cost_preview_text(idx),title,str(card.get("attribute","")),role,effect.substr(0,48)]
            btn.tooltip_text = "%s\n%s" % [str(card.get("display_name",title)),effect]
            btn.disabled = busy or battle.combat_over or (not battle.is_hand_selection_active() and not battle.can_use_card(idx))
            btn.modulate = Color("ffe5ba") if idx==selected_index else Color.WHITE
        else:
            btn.text = ""
            btn.visible = false
    for i in range(enemy_huds.size()):
        if i >= battle.get_enemy_count():continue
        var e: Dictionary = battle.get_enemy(i)
        var hud: Control = enemy_huds[i]
        if not is_instance_valid(hud):continue
        hud.modulate.a = 0.3 if int(e.get("hp",0))<=0 else 1.0
        # First text label is the panel's second child.
        var hlabel: Label = hud.get_child(1) as Label
        if hlabel != null:
            hlabel.text = "%d %s  HP%d  B%d\n%s" % [i+1,str(e.get("name","")),int(e.get("hp",0)),int(e.get("block",0)),battle.get_enemy_intent_display_label(i)]
            hlabel.tooltip_text=hlabel.text
        var rect: ColorRect = enemy_mini_fills[i]
        var fill_w: float = 102.0 if tier == "mob" else (167.0 if tier=="elite" else 227.0)
        rect.size.x = fill_w*clampf(float(e.get("hp",0))/float(maxi(1,int(e.get("max_hp",1)))),0.0,1.0)
        actors[i].modulate.a = 0.32 if int(e.get("hp",0))<=0 else 1.0
        # The actor does not choose a phase. Follow the actual Core's phase index only.
        if i<shown_phase_cache.size() and int(e.get("phase_index",0))<shown_phase_cache[i]:
            shown_phase_cache[i]=int(e.get("phase_index",0))
        enemy_buttons[i].disabled = busy or not battle.is_enemy_target_valid(i)
    if battle.combat_over:
        status.text = ("勝利。進行画面へ移ります。" if battle.victory else "敗北。進行画面へ移ります。") if campaign_mode else ("勝利！" if battle.victory else "敗北。上の敵種別で再開できます。")
    elif battle.is_hand_selection_active():
        status.text = battle.get_hand_selection_prompt()

func _card_pressed(slot: int) -> void:
    if busy or battle.combat_over:return
    var idx: int = card_page*VISIBLE_CARDS+slot
    if idx<0 or idx>=battle.hand.size():return
    if battle.is_hand_selection_active():
        if battle.is_salvage_selection_active():
            _show_salvage_choices()
            return
        if battle.select_hand_for_pending(idx):
            selected_index=-1
            _refresh_hud()
            if battle.is_salvage_selection_active():_show_salvage_choices()
            _campaign_checkpoint()
        return
    if not battle.can_use_card(idx):return
    if selected_index==idx:
        if battle.get_effective_target_type(idx)!="enemy":
            _perform_card(idx,-1)
        else:
            _clear_selection()
        return
    selected_index=idx
    var c: Dictionary=battle.hand[idx]
    selection_label.text = "%s / %s / %s ｜ %s" % [_card_title(c),str(c.get("attribute","")),battle.get_cost_preview_text(idx),str(c.get("text",""))]
    selection_label.tooltip_text = selection_label.text
    status.text = "敵1体は敵をタップ。自分/対象不要はカード再タップまたは使用。"
    _refresh_hud()

func _clear_selection() -> void:
    if busy or battle.is_hand_selection_active():return
    selected_index=-1
    selection_label.text="カード選択 → 敵指定 / 自分向けは再タップ"
    _refresh_hud()

func _use_selected() -> void:
    if busy or battle.combat_over or selected_index<0:return
    if battle.get_effective_target_type(selected_index)=="enemy":
        status.text="敵をタップして攻撃対象を確定してください。"
        return
    _perform_card(selected_index,-1)

func _enemy_pressed(index: int) -> void:
    if busy or battle.combat_over or not battle.is_enemy_target_valid(index):return
    if selected_index<0 or selected_index>=battle.hand.size():
        status.text="まず使用するカードを選択してください。"
        return
    if battle.get_effective_target_type(selected_index)!="enemy":
        status.text="このカードは敵対象ではありません。"
        return
    _perform_card(selected_index,index)

func _perform_card(index: int,target_index: int) -> void:
    if busy or battle.combat_over or not battle.can_use_card(index):return
    var card: Dictionary = battle.hand[index].duplicate(true)
    var finisher: bool = str(card.get("role",""))=="決着技"
    var attribute: String = str(card.get("attribute","物理"))
    var weapon: String = str(card.get("weapon","片手剣"))
    var old_count: int = event_log.size()
    var phases_before: Array[int] = _snapshot_phases()
    if not battle.use_card(index,target_index):
        status.text="カード使用条件を満たしません。"
        _refresh_hud()
        return
    busy = true
    selected_index=-1
    _current_animation="card"
    event_playback=event_log.slice(old_count)
    _acting_target=target_index
    _last_attribute=attribute
    _last_damage=0
    for ev in event_playback:
        if str(ev.get("kind",""))=="enemy_hit" and int(ev.get("enemy",-1))==target_index:
            _last_damage+=int(ev.get("hp_loss",0))
    hero.set_weapon(weapon)
    _refresh_hud()
    status.text="Battle Core解決済み: %s / 演出を再生中" % _card_title(card)
    await _show_cutin(_card_title(card),finisher)
    if str(card.get("card_type",""))=="attack":
        await hero.play_weapon_action(weapon,finisher,speed)
    else:
        await hero.play_weapon_skill(weapon,speed)
        fx.position=hero.position+Vector2(20,-105)
        fx.play(attribute,false,2,speed)
    await _animate_phase_changes(phases_before)
    _acting_target=-1
    _current_animation=""
    busy=false
    _refresh_hud()
    if battle.is_salvage_selection_active():_show_salvage_choices()
    elif battle.is_hand_selection_active():status.text=battle.get_hand_selection_prompt()
    elif not battle.combat_over:status.text="カード使用完了。次のカードを選択できます。"
    _campaign_checkpoint()

func _show_cutin(card_name: String,finisher: bool) -> void:
    cutin_title.text=card_name
    cutin.position=Vector2(-500,170)
    cutin.modulate.a=0.0
    var enter:=create_tween().set_parallel(true)
    enter.tween_property(cutin,"position",Vector2(39,170),0.24/speed if finisher else 0.14/speed)
    enter.tween_property(cutin,"modulate:a",0.95,0.21/speed if finisher else 0.13/speed)
    await enter.finished
    await get_tree().create_timer((0.18 if finisher else 0.05)/speed).timeout
    var exit:=create_tween().set_parallel(true)
    exit.tween_property(cutin,"position",Vector2(-510,170),0.22/speed if finisher else 0.11/speed)
    exit.tween_property(cutin,"modulate:a",0.0,0.20/speed if finisher else 0.11/speed)
    await exit.finished

func _hero_impact() -> void:
    if _current_animation!="card":return
    var seen: Dictionary = {}
    for ev in event_playback:
        if str(ev.get("kind",""))!="enemy_hit":continue
        var idx: int=int(ev.get("enemy",-1))
        if idx<0 or idx>=actors.size():continue
        if not seen.has(idx):
            seen[idx] = {"hp":0,"block":0}
        seen[idx]["hp"] = int(seen[idx]["hp"])+int(ev.get("hp_loss",0))
        seen[idx]["block"] = int(seen[idx]["block"])+int(ev.get("block_loss",0))
    for idx in seen.keys():
        if is_instance_valid(actors[idx]): actors[idx].call("play_hit",speed)
        fx.position=_enemy_base(idx)+Vector2(-24,-106)
        fx.play(_last_attribute,false,2,speed)
    if seen.is_empty():return
    var first_idx: int=int(seen.keys()[0])
    damage_text.text="HP −%d / Block −%d" % [int(seen[first_idx]["hp"]),int(seen[first_idx]["block"])]
    damage_text.position=_enemy_base(first_idx)+Vector2(-70,-160)
    damage_text.visible=true
    damage_text.modulate.a=1.0
    var float_up:=create_tween().set_parallel(true)
    float_up.tween_property(damage_text,"position:y",damage_text.position.y-40,0.45/speed)
    float_up.tween_property(damage_text,"modulate:a",0.0,0.45/speed)
    await float_up.finished
    damage_text.visible=false

func _end_turn() -> void:
    if busy or battle.combat_over or battle.is_hand_selection_active() or selected_index>=0:return
    busy=true
    _current_animation="enemy"
    var before_events: int=event_log.size()
    var phases_before: Array[int]=_snapshot_phases()
    battle.end_player_turn()
    event_playback=event_log.slice(before_events)
    _refresh_hud()
    status.text="敵フェーズの確定結果をアニメーション再生中"
    for ev in event_playback:
        if str(ev.get("kind",""))!="enemy_action":continue
        var idx: int=int(ev.get("enemy",-1))
        if idx<0 or idx>=actors.size():continue
        if not is_instance_valid(actors[idx]):continue
        var action_type: String=str(ev.get("action",""))
        if action_type=="attack":
            if tier=="boss":
                await _show_boss_attack_cutin(idx)
            await actors[idx].play_attack(speed)
            hero.play_hit(speed)
        else:
            fx.position=_enemy_base(idx)+Vector2(-20,-100)
            fx.play("秘術",false,2,speed)
            await get_tree().create_timer(0.15/maxf(0.35,speed)).timeout
    await _animate_phase_changes(phases_before)
    _current_animation=""
    busy=false
    _refresh_hud()
    if not battle.combat_over:status.text="TURN %d：次の手札からカードを選択。" % battle.turn_number
    _campaign_checkpoint()

func _all_dead() -> bool:
    for enemy in battle.enemies:
        if int(enemy.get("hp",0))>0:return false
    return true


func _card_title(c: Dictionary) -> String:
    var name: String=str(c.get("display_name",c.get("id","?")))
    # Preserve actual data name without inventing card titles.
    return name.substr(0,30)

func _switch_page(shift: int) -> void:
    if busy:return
    var max_page: int=maxi(0,int(ceil(float(battle.hand.size())/float(VISIBLE_CARDS)))-1)
    card_page=clampi(card_page+shift,0,max_page)
    _refresh_hud()

func _capture_event(ev: Dictionary) -> void:
    if event_log.size()>512:event_log.pop_front()
    event_log.append(ev.duplicate(true))

func _show_salvage_choices() -> void:
    if not battle.is_salvage_selection_active():return
    if salvage_popup != null and is_instance_valid(salvage_popup):
        salvage_popup.queue_free()
    salvage_popup=PopupPanel.new()
    stage.add_child(salvage_popup)
    var root := VBoxContainer.new()
    salvage_popup.add_child(root)
    var label:=Label.new()
    label.text="捨て札から回収するカードを選択"
    root.add_child(label)
    for index in battle.get_salvage_selectable_indices():
        var b:=Button.new()
        var card: Dictionary=battle.discard_pile[index]
        b.text="%s  / %s" % [str(card.get("id","")),_card_title(card)]
        root.add_child(b)
        b.pressed.connect(_select_salvage.bind(index))
    salvage_popup.popup_centered(Vector2i(490,280))

func _select_salvage(index: int) -> void:
    if not battle.is_salvage_selection_active():return
    if battle.select_discard_for_pending(index):
        if salvage_popup!=null and is_instance_valid(salvage_popup):salvage_popup.hide()
        _refresh_hud()
        if battle.is_salvage_selection_active():_show_salvage_choices()
        elif battle.is_hand_selection_active():status.text=battle.get_hand_selection_prompt()
        _campaign_checkpoint()


# STEP8 presentation-only functions. Phase transitions are checked against the real Core state.
func _snapshot_phases() -> Array[int]:
    var result: Array[int]=[]
    if battle==null:return result
    for e in battle.enemies:
        result.append(int(e.get("phase_index",0)))
    return result

func _animate_phase_changes(before: Array[int]) -> void:
    if battle==null:return
    # Multiple enemies and multi-transition effects are allowed; no invented transitions.
    for i in range(mini(before.size(),battle.get_enemy_count())):
        var enemy: Dictionary=battle.get_enemy(i)
        var new_phase: int=int(enemy.get("phase_index",0))
        if new_phase<=before[i]:continue
        if not enemy.has("phase_hp"):continue
        if i>=actors.size() or not is_instance_valid(actors[i]):continue
        await _show_phase_banner(i,new_phase)
        await actors[i].play_phase_change(new_phase,speed)
        if i<shown_phase_cache.size():shown_phase_cache[i]=new_phase
    _refresh_hud()

func _show_phase_banner(index: int, phase_index: int) -> void:
    var enemy: Dictionary=battle.get_enemy(index)
    var id: String=str(enemy.get("id",""))
    var region: int=clampi(int(id.substr(1,1)) if id.begins_with("R") else 1,1,6)
    var phase_total: int=enemy.get("phase_hp",[]).size()
    var image_path: String="res://ui_trial/assets/regions/R%d/boss_head.png"%region
    if id.begins_with("R1-"):
        var unique_head: String="res://ui_trial/assets/region1_unique/"+id+"/head.png"
        if ResourceLoader.exists(unique_head):image_path=unique_head
    if ResourceLoader.exists(image_path):phase_portrait.texture=load(image_path)
    phase_portrait.modulate=Color(REGION_TINT[region-1])
    phase_heading.text="BOSS PHASE\n%s\n%d / %d"%[str(enemy.get("name","Boss")),phase_index+1,phase_total]
    phase_banner.visible=true
    phase_banner.modulate.a=0.0
    phase_banner.position=Vector2(365,156)
    var intro:=create_tween().set_parallel(true)
    intro.tween_property(phase_banner,"modulate:a",1.0,0.19/maxf(speed,0.4))
    intro.tween_property(phase_banner,"position:y",165.0,0.19/maxf(speed,0.4))
    await intro.finished
    await get_tree().create_timer(0.23/maxf(speed,0.4)).timeout
    var outro:=create_tween()
    outro.tween_property(phase_banner,"modulate:a",0.0,0.19/maxf(speed,0.4))
    await outro.finished
    phase_banner.visible=false

func _show_boss_attack_cutin(index: int) -> void:
    if index<0 or index>=battle.get_enemy_count():return
    var enemy: Dictionary=battle.get_enemy(index)
    var id: String=str(enemy.get("id",""))
    var region: int=clampi(int(id.substr(1,1)) if id.begins_with("R") else 1,1,6)
    var image_path: String="res://ui_trial/assets/regions/R%d/boss_head.png"%region
    if ResourceLoader.exists(image_path):phase_portrait.texture=load(image_path)
    phase_portrait.modulate=Color(REGION_TINT[region-1])
    phase_heading.text="BOSS ATTACK\n"+str(enemy.get("name","Boss"))
    phase_banner.visible=true
    phase_banner.modulate.a=0.0
    var t:=create_tween()
    t.tween_property(phase_banner,"modulate:a",0.88,0.13/maxf(speed,0.4))
    t.tween_interval(0.10/maxf(speed,0.4))
    t.tween_property(phase_banner,"modulate:a",0.0,0.15/maxf(speed,0.4))
    await t.finished
    phase_banner.visible=false
