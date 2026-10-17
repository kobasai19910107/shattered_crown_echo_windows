extends Control
## Standalone visual trial scene. Existing main.tscn and BattleController are unchanged.
const HeroScript = preload("res://ui_trial/actors/actor3h.gd")
const MobScript = preload("res://ui_trial/actors/mob_chibi.gd")
const STAGE_SIZE := Vector2(1280, 720)

var stage_canvas: Control
var hero
var mob
var cutin: Control
var cutin_label: Label
var popup: Label
var helper_label: Label
var busy: bool = false
var anim_speed: float = 1.0
var effect_buttons: Array[Button] = []

func _ready() -> void:
    stage_canvas = Control.new()
    stage_canvas.size = STAGE_SIZE
    stage_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(stage_canvas)
    _fit_stage()
    resized.connect(_fit_stage)
    _add_background()
    _add_world()
    _add_hud()
    _add_cutin()
    _add_cards()

func _fit_stage() -> void:
    if stage_canvas == null:
        return
    var factor: float = minf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
    stage_canvas.scale = Vector2(factor, factor)
    stage_canvas.position = (size - STAGE_SIZE * factor) * 0.5

func _add_background() -> void:
    var background := TextureRect.new()
    background.texture = load("res://ui_trial/assets/battle_background.webp")
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.offset_left = 0
    background.offset_top = 0
    background.offset_right = 0
    background.offset_bottom = 0
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_canvas.add_child(background)
    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.02, 0.05, 0.13)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_canvas.add_child(shade)

func _add_world() -> void:
    hero = Node2D.new()
    hero.set_script(HeroScript)
    hero.position = Vector2(270, 525)
    hero.scale = Vector2(0.68, 0.68)
    stage_canvas.add_child(hero)
    hero.impact_frame.connect(_on_impact)

    mob = Node2D.new()
    mob.set_script(MobScript)
    mob.position = Vector2(885, 525)
    mob.scale = Vector2(0.94, 0.94)
    stage_canvas.add_child(mob)

    popup = _label("", 32, Color("ffe2a7"), Vector2(902, 280), Vector2(230, 56))
    popup.visible = false

func _panel(rect: Rect2, color: Color) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.position = rect.position
    panel.size = rect.size
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(8)
    style.border_color = Color(0.72, 0.58, 0.43, 0.42)
    style.set_border_width_all(1)
    panel.add_theme_stylebox_override("panel", style)
    stage_canvas.add_child(panel)
    return panel

func _label(value: String, point_size: int, tint: Color, pos: Vector2, dims: Vector2) -> Label:
    var lbl := Label.new()
    lbl.text = value
    lbl.position = pos
    lbl.size = dims
    lbl.add_theme_font_size_override("font_size", point_size)
    lbl.add_theme_color_override("font_color", tint)
    lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_canvas.add_child(lbl)
    return lbl

func _add_hud() -> void:
    _panel(Rect2(0, 0, 1280, 98), Color(0.025, 0.035, 0.060, 0.88))
    _label("SHATTERED CROWN ECHO", 27, Color("efe1d5"), Vector2(36, 13), Vector2(440, 37))
    _label("UI ANIMATION TRIAL   /   3-HEAD ACTOR", 13, Color("a9aabe"), Vector2(38, 58), Vector2(405, 30))
    _label("P1  ◆ HP 48/48  ◆ Mana 3/3", 21, Color("a7d9fb"), Vector2(460, 19), Vector2(420, 33))
    _label("NORMAL MOB     [Intent: Attack]", 21, Color("f3b2ac"), Vector2(853, 19), Vector2(418, 33))
    _label("Intent・HPは表示例（実ゲームの戦闘数値と未接続）", 12, Color("c3b6bd"), Vector2(858, 58), Vector2(418, 23))
    _label("プレイヤー：3頭身 / パーツ分割", 19, Color("f1e5df"), Vector2(130, 365), Vector2(315, 28))
    _label("通常モブ：小型 / 共通モーション", 19, Color("f1e5df"), Vector2(730, 340), Vector2(380, 30))

func _add_cutin() -> void:
    cutin = Control.new()
    cutin.position = Vector2(-580, 120)
    cutin.size = Vector2(650, 330)
    cutin.modulate.a = 0.0
    cutin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_canvas.add_child(cutin)
    var plate := ColorRect.new()
    plate.size = Vector2(630, 300)
    plate.color = Color(0.12, 0.025, 0.05, 0.92)
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin.add_child(plate)
    var portrait := TextureRect.new()
    portrait.position = Vector2(6, 6)
    portrait.size = Vector2(384, 286)
    portrait.texture = load("res://ui_trial/assets/cutin_temp.webp")
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin.add_child(portrait)
    cutin_label = Label.new()
    cutin_label.position = Vector2(392, 180)
    cutin_label.size = Vector2(237, 90)
    cutin_label.add_theme_font_size_override("font_size", 30)
    cutin_label.add_theme_color_override("font_color", Color("ffe3bd"))
    cutin.add_child(cutin_label)

func _add_cards() -> void:
    _panel(Rect2(0, 552, 1280, 168), Color(0.02, 0.027, 0.046, 0.94))
    _label("VISUAL TEST  /  カード効果・Mana消費は行いません", 16, Color("a9b9cf"), Vector2(34, 568), Vector2(800, 26))
    _make_button("通常Attack\nショートカットイン", 55.0, "normal")
    _make_button("魔法Skill\nショートカットイン", 330.0, "skill")
    _make_button("Finisher\n大型カットイン", 605.0, "finisher")
    _make_button("速度を切替\n通常 / 高速", 880.0, "speed")
    helper_label = _label("待機アニメーション再生中", 17, Color("edc9a3"), Vector2(55, 675), Vector2(1060, 34))

func _make_button(title: String, x: float, action: String) -> void:
    var btn := Button.new()
    btn.position = Vector2(x, 605)
    btn.size = Vector2(235, 61)
    btn.text = title
    btn.add_theme_font_size_override("font_size", 19)
    btn.add_theme_color_override("font_color", Color("f7e4d8"))
    var style := StyleBoxFlat.new()
    style.bg_color = Color("35293e") if action == "finisher" else Color("26354a")
    style.border_color = Color("bd5d5f") if action == "finisher" else Color("788ba7")
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    btn.add_theme_stylebox_override("normal", style)
    btn.add_theme_stylebox_override("hover", style)
    stage_canvas.add_child(btn)
    effect_buttons.append(btn)
    btn.pressed.connect(func(): _handle_action(action))

func _handle_action(action: String) -> void:
    if action == "speed":
        anim_speed = 2.0 if anim_speed == 1.0 else 1.0
        helper_label.text = "演出速度：%s" % ("高速" if anim_speed > 1.0 else "通常")
        return
    if busy:
        return
    _play_visual(action)

func _play_visual(action: String) -> void:
    busy = true
    for btn in effect_buttons:
        if btn.text.find("速度") == -1:
            btn.disabled = true
    var is_finisher: bool = action == "finisher"
    var duration: float = (0.75 if is_finisher else 0.28) / anim_speed
    cutin_label.text = "紅蓮の斬華" if is_finisher else ("魔導の構え" if action == "skill" else "一閃")
    helper_label.text = "カットイン → 3頭身アニメ → 被弾エフェクト"
    cutin.position = Vector2(-580, 135)
    cutin.modulate.a = 0.0
    var into := create_tween()
    into.set_parallel(true)
    into.tween_property(cutin, "position", Vector2(35, 135), duration * 0.60)
    into.tween_property(cutin, "modulate:a", 1.0, duration * 0.45)
    await into.finished
    await get_tree().create_timer(duration * 0.40).timeout
    var out := create_tween()
    out.set_parallel(true)
    out.tween_property(cutin, "position", Vector2(-580, 135), duration * 0.35)
    out.tween_property(cutin, "modulate:a", 0.0, duration * 0.35)
    await hero.play_attack(is_finisher, anim_speed)
    helper_label.text = "待機アニメーション再生中 / 戦闘ロジックは無変更"
    busy = false
    for btn in effect_buttons:
        btn.disabled = false

func _on_impact() -> void:
    mob.play_hit(anim_speed)
    popup.text = "VISUAL HIT!"
    popup.position = Vector2(875, 300)
    popup.modulate.a = 1.0
    popup.visible = true
    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(popup, "position", Vector2(875, 250), 0.40 / anim_speed)
    t.tween_property(popup, "modulate:a", 0.0, 0.40 / anim_speed)
    await t.finished
    popup.visible = false
