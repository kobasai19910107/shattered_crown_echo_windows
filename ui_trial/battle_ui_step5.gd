extends Control
## STEP5: three-tier encounter layout demonstration, isolated from the real BattleController.
## All HP, Mana, Intent, and damage shown here are dummy UI state.
const HERO_SCRIPT = preload("res://ui_trial/actors/actor3h.gd")
const ENEMY_SCRIPT = preload("res://ui_trial/actors/enemy_tier.gd")
const FX_SCRIPT = preload("res://ui_trial/vfx/attribute_fx.gd")
const BG = preload("res://ui_trial/assets/battle_background.webp")
const PORTRAIT = preload("res://ui_trial/assets/cutin_temp.webp")
const STAGE := Vector2(1280.0, 720.0)
const DEMO_CARDS := [
    {"title":"斬撃", "cost":1, "kind":"attack", "weapon":"片手剣", "attribute":"物理", "damage":12, "detail":"敵1体へ攻撃。"},
    {"title":"防御", "cost":1, "kind":"skill", "weapon":"片手剣", "attribute":"地", "block":8, "detail":"自分にBlock8。"},
    {"title":"炎の刃", "cost":1, "kind":"attack", "weapon":"片手剣", "attribute":"炎", "damage":16, "detail":"敵1体に炎の攻撃。"},
    {"title":"紅蓮の一閃", "cost":2, "kind":"attack", "weapon":"刀", "attribute":"炎", "damage":26, "finisher":true, "detail":"デモ用Finisher。敵1体に攻撃。"},
    {"title":"魔力整律", "cost":0, "kind":"skill", "weapon":"魔法剣", "attribute":"秘術", "block":3, "detail":"自分にBlock3。"}
]
const TIER_INFO := {
    "mob":{"title":"通常モブ戦", "name":"灰の小鬼", "hp":32, "attack":5, "intent":"攻撃 5"},
    "elite":{"title":"エリート戦", "name":"黒鉄の騎士", "hp":140, "attack":13, "intent":"攻撃 13"},
    "boss":{"title":"ボス戦", "name":"灰冠の災竜", "hp":480, "attack":22, "intent":"大技 22"}
}
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
var enemy_hp: Array[int] = []
var card_buttons: Array[Button] = []
var mode_buttons: Dictionary = {}
var selected_index: int = -1
var tier: String = "mob"
var mana: int = 3
var hp: int = 48
var block: int = 0
var turn: int = 1
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

func _ready() -> void:
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
    _panel(field_layer,Vector2(25,100),Vector2(410,35),Color(0.025,0.039,0.070,0.75),Color("656074"))
    _label(field_layer,"STEP 5 ・ 3頭身アニメ / 試作画面",16,DIM,Vector2(36,107),Vector2(390,28))
    _panel(field_layer,Vector2(525,101),Vector2(235,36),Color(0.025,0.039,0.070,0.75),Color("656074"))
    _label(field_layer,"シーン切替（表示デモ）",16,GOLD,Vector2(545,108),Vector2(216,27))
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
    _label(stage,"P1  銀冠の剣士",17,GOLD,Vector2(30,51),Vector2(290,28))
    hero_hp_fill = _bar(stage,Vector2(200,60),Vector2(195,15),Color("b74351"))
    hero_status = _label(stage,"HP 48/48    Block 0",15,WHITE,Vector2(202,38),Vector2(246,25))
    enemy_main_label = _label(stage,"灰の小鬼  /  HP 32",18,WHITE,Vector2(633,6),Vector2(510,30))
    enemy_hp_fill = _bar(stage,Vector2(630,40),Vector2(550,15),Color("bd4b55"))
    intent_label = _label(stage,"Intent  攻撃 5",17,Color("ffd3ac"),Vector2(634,64),Vector2(360,25))
    turn_label = _label(stage,"TURN 1",16,WHITE,Vector2(1186,65),Vector2(90,26))

func _make_cards() -> void:
    _panel(stage,Vector2(0,509),Vector2(1280,211),INK,Color("947356"))
    _label(stage,"DEMO  /  戦闘処理は未接続・表示数値は仮",13,DIM,Vector2(30,514),Vector2(600,25))
    _panel(stage,Vector2(26,559),Vector2(113,120),Color("0e2546"),Color("6bc1f4"))
    mana_label = _label(stage,"Mana\n3 / 3",23,Color("b3e9ff"),Vector2(41,575),Vector2(97,80))
    mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var base_x := 164.0
    for i in DEMO_CARDS.size():
        var c: Dictionary = DEMO_CARDS[i]
        var bx := base_x + 166.0*i
        var btn := _button(stage,"",Vector2(bx,548),Vector2(156,145),_card_pressed.bind(i),bool(c.get("finisher",false)))
        btn.text = "◆ %d   %s\n\n%s\n%s" % [int(c.cost),str(c.title),str(c.attribute),"Finisher" if bool(c.get("finisher",false)) else ("Attack" if str(c.kind)=="attack" else "Skill")]
        btn.add_theme_font_size_override("font_size",16)
        card_buttons.append(btn)
    _button(stage,"使用",Vector2(1005,552),Vector2(112,43),_use_selected)
    _button(stage,"解除",Vector2(1127,552),Vector2(110,43),_clear_selection)
    _button(stage,"ターン終了",Vector2(1004,604),Vector2(232,65),_end_turn,true)
    selection_label = _label(stage,"カード選択 → 対象選択 / 自分向けは再タップで使用",14,DIM,Vector2(163,689),Vector2(1020,25))
    status = _label(stage,"",15,Color("f1ce99"),Vector2(34,465),Vector2(1060,33))
    status.text = "モブ戦を表示しています。下のカードから演出を試してください。"

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

func _create_hero() -> void:
    hero = Node2D.new()
    hero.set_script(HERO_SCRIPT)
    hero.position = Vector2(311,504)
    hero.scale = Vector2(0.63,0.63)
    field_layer.add_child(hero)
    hero.impact_frame.connect(_hero_impact)

func _enemy_base(index: int) -> Vector2:
    if tier == "mob": return Vector2(826.0 + index*140.0, 505.0)
    return Vector2(940.0, 506.0)

func _set_tier(next_tier: String) -> void:
    if busy:return
    tier = next_tier
    mana = 3
    hp = 48
    block = 0
    turn = 1
    selected_index = -1
    var count: int = 3 if tier == "mob" else 1
    var base_hp: int = int(TIER_INFO[tier].hp)
    enemy_hp.clear()
    for i in range(count):enemy_hp.append(base_hp)
    for enemy in actors:
        if is_instance_valid(enemy):enemy.queue_free()
    for hud in enemy_huds:
        if is_instance_valid(hud):hud.queue_free()
    for b in enemy_buttons:
        if is_instance_valid(b):b.queue_free()
    actors.clear()
    enemy_huds.clear()
    enemy_mini_fills.clear()
    enemy_buttons.clear()
    for i in range(count):
        var actor := Node2D.new()
        actor.set_script(ENEMY_SCRIPT)
        actor.call("configure",tier)
        actor.position = _enemy_base(i)
        actor.scale = Vector2(0.63,0.63) if tier=="mob" else (Vector2(1.0,1.0) if tier=="elite" else Vector2(1.07,1.07))
        field_layer.add_child(actor)
        actors.append(actor)
        var x: float = _enemy_base(i).x
        var w: float = 120.0 if tier=="mob" else 245.0
        var y: float = 291.0 if tier=="mob" else (207.0 if tier=="elite" else 142.0)
        var info := Control.new()
        info.position = Vector2(x-w*0.5,y)
        info.size = Vector2(w,53)
        info.mouse_filter = Control.MOUSE_FILTER_IGNORE
        field_layer.add_child(info)
        enemy_huds.append(info)
        _panel(info,Vector2(0,0),Vector2(w,51),Color(0.015,0.025,0.05,0.74),Color("98675f"))
        _label(info,"%d  ⚔ %s" % [i+1,str(TIER_INFO[tier].intent)],14,WHITE,Vector2(8,2),Vector2(w-12,24))
        enemy_mini_fills.append(_bar(info,Vector2(9,31),Vector2(w-18,9),Color("c45761")))
        var click := Button.new()
        click.position = Vector2(x-(86 if tier=="mob" else 152),y+43)
        click.size = Vector2(172 if tier=="mob" else 304,507.0-(y+43.0))
        click.flat = true
        click.text = ""
        click.focus_mode = Control.FOCUS_NONE
        click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        field_layer.add_child(click)
        click.pressed.connect(_enemy_pressed.bind(i))
        enemy_buttons.append(click)
    _refresh_hud()
    status.text = "%sを表示中（戦闘演出デモ・本編未接続）" % str(TIER_INFO[tier].title)

func _refresh_hud() -> void:
    hero_status.text = "HP %d/48    Block %d" % [hp,block]
    hero_hp_fill.size = Vector2(191.0*clampf(float(hp)/48.0,0.0,1.0),hero_hp_fill.size.y)
    var base_hp: int = int(TIER_INFO[tier].hp)
    var active_hp: int = 0
    for value in enemy_hp:active_hp += value
    enemy_main_label.text = "%s  /  HP %d/%d" % [str(TIER_INFO[tier].name),active_hp,base_hp*enemy_hp.size()]
    enemy_hp_fill.size = Vector2(546.0*clampf(float(active_hp)/float(maxi(1,base_hp*enemy_hp.size())),0.0,1.0),enemy_hp_fill.size.y)
    intent_label.text = "Intent: %s" % str(TIER_INFO[tier].intent)
    turn_label.text = "TURN %d" % turn
    mana_label.text = "Mana\n%d / 3" % mana
    for i in card_buttons.size():
        var btn: Button = card_buttons[i]
        var cost: int = int(DEMO_CARDS[i].cost)
        btn.disabled = cost > mana or busy
        btn.modulate = Color("ffe5ba") if i==selected_index else Color.WHITE
    for i in enemy_huds.size():
        var hud: Control = enemy_huds[i]
        if is_instance_valid(hud):
            hud.modulate.a = 0.3 if enemy_hp[i]<=0 else 1.0
            var hp_fill: ColorRect = enemy_mini_fills[i]
            var fill_w: float = 102.0 if tier == "mob" else 227.0
            hp_fill.size = Vector2(fill_w*clampf(float(enemy_hp[i])/float(maxi(base_hp,1)),0.0,1.0),hp_fill.size.y)
            actors[i].modulate.a = 0.32 if enemy_hp[i]<=0 else 1.0
    for i in enemy_buttons.size():enemy_buttons[i].disabled=busy or enemy_hp[i]<=0

func _card_pressed(index: int) -> void:
    if busy or int(DEMO_CARDS[index].cost)>mana:return
    if selected_index==index:
        if str(DEMO_CARDS[index].kind)=="skill":
            _perform_card(index,-1)
        else:
            _clear_selection()
        return
    selected_index=index
    var card: Dictionary = DEMO_CARDS[index]
    selection_label.text = "%s / %s / Cost %d  ｜  %s" % [str(card.title),str(card.attribute),int(card.cost),str(card.detail)]
    status.text = "敵対象はモンスターをタップ。自分対象は同じカードを再タップ、または使用を押してください。"
    _refresh_hud()

func _clear_selection() -> void:
    if busy:return
    selected_index=-1
    selection_label.text="カード選択 → 対象選択 / 自分向けは再タップで使用"
    _refresh_hud()

func _use_selected() -> void:
    if selected_index<0 or busy:return
    if str(DEMO_CARDS[selected_index].kind)=="skill":
        _perform_card(selected_index,-1)
    else:
        status.text="敵をタップして攻撃対象を確定してください。"

func _enemy_pressed(index: int) -> void:
    if selected_index<0 or busy or enemy_hp[index]<=0:
        status.text="カードを選択してから敵をタップしてください。"
        return
    var card: Dictionary=DEMO_CARDS[selected_index]
    if str(card.kind)!="attack":return
    _perform_card(selected_index,index)

func _perform_card(index: int, target_index: int) -> void:
    if busy:return
    var card: Dictionary = DEMO_CARDS[index]
    if int(card.cost)>mana:return
    busy=true
    _acting_target=target_index
    _current_animation="card"
    _last_attribute=str(card.attribute)
    _last_damage=int(card.get("damage",0))
    mana-=int(card.cost)
    selected_index=-1
    _refresh_hud()
    status.text="演出中：%s / デモ戦闘結果の表示" % str(card.title)
    var finisher: bool=bool(card.get("finisher",false))
    hero.set_weapon(str(card.weapon))
    await _show_cutin(str(card.title),finisher)
    if str(card.kind)=="attack":
        await hero.play_weapon_action(str(card.weapon),finisher,speed)
        # Actor's impact signal plays hit feedback; UI-demo values change exactly once here.
        if target_index>=0 and target_index<enemy_hp.size():
            enemy_hp[target_index]=maxi(0,enemy_hp[target_index]-int(card.get("damage",0)))
    else:
        await hero.play_weapon_skill(str(card.weapon),speed)
        block+=int(card.get("block",0))
        fx.position=hero.position+Vector2(20,-105)
        fx.play(str(card.attribute),false,2,speed)
    _acting_target=-1
    _current_animation=""
    busy=false
    status.text="デモ：%sの演出が完了。" % str(card.title)
    _refresh_hud()
    if _all_dead():status.text="演出デモの敵を撃破。上の敵種別を切り替えるとリセットできます。"

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
    if _current_animation!="card" or _acting_target<0 or _acting_target>=actors.size():return
    if actors[_acting_target] == null:return
    actors[_acting_target].call("play_hit",speed)
    fx.position=_enemy_base(_acting_target)+Vector2(-24,-106)
    fx.play(_last_attribute,false,2,speed)
    damage_text.text="−%d" % _last_damage
    damage_text.position=_enemy_base(_acting_target)+Vector2(-57,-160)
    damage_text.visible=true
    damage_text.modulate.a=1.0
    var float_up:=create_tween().set_parallel(true)
    float_up.tween_property(damage_text,"position:y",damage_text.position.y-40,0.45/speed)
    float_up.tween_property(damage_text,"modulate:a",0.0,0.45/speed)
    await float_up.finished
    damage_text.visible=false

func _end_turn() -> void:
    if busy:return
    if _all_dead():
        status.text="敵がいません。上の戦闘種別ボタンで再開できます。"
        return
    busy=true
    selected_index=-1
    _current_animation="enemy"
    _refresh_hud()
    status.text="敵フェーズ：Intent順の演出（表示用ダミー）"
    for i in actors.size():
        if enemy_hp[i]<=0:continue
        var enemy_actor: Variant = actors[i]
        await enemy_actor.play_attack(speed)
        hero.play_hit(speed)
        var attack: int=int(TIER_INFO[tier].attack)
        var absorbed: int=mini(block,attack)
        block-=absorbed
        hp=maxi(0,hp-(attack-absorbed))
    if hp>0:
        turn+=1
        mana=3
        block=0
        status.text="TURN %d：Manaを3に更新（デモのみ）。" % turn
    else:
        status.text="デモ用HPが0。戦闘種別を切り替えてリセットしてください。"
    _current_animation=""
    busy=false
    _refresh_hud()

func _all_dead() -> bool:
    for value in enemy_hp:
        if value>0:return false
    return true
