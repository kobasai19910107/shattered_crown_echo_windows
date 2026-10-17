extends Control
## STEP15 VISUAL QA ONLY.  Existing BattleCore, campaign, EOS and save data remain untouched.
const PLAYER_SCRIPT = preload("res://ui_trial/actors/actor3h.gd")
const BOSS_SCRIPT = preload("res://ui_trial/actors/boss_b01_rig_step19.gd")
const BACKDROP = preload("res://ui_trial/assets/battle_background.webp")
const DESIGN := Vector2(1280.0, 720.0)
const GOLD := Color("e8c48e")
const LIGHT := Color("f3eae0")
const MUTED := Color("c8d4dc")
const HERO_POS := Vector2(292.0, 526.0)
const BOSS_POS := Vector2(805.0, 528.0)
const RESULT_FILE := "user://step19_b01_visual_qa.json"

var stage: Control
var hero: Node2D
var boss: Node2D
var hero_scale: float = 0.58
var boss_scale: float = 1.52
var speed: float = 2.0
var busy: bool = false
var num_runs: int = 0
var max_reset_error: float = 0.0
var warnings: Array[String] = []
var qa_label: Label
var ratio_label: Label
var progress_label: Label
var buttons: Array[Button] = []
var _poll_accum: float = 0.0

func _ready() -> void:
    stage = Control.new()
    stage.size = DESIGN
    stage.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(stage)
    resized.connect(_layout)
    _layout()
    _make_environment()
    hero = PLAYER_SCRIPT.new()
    hero.position = HERO_POS
    hero.scale = Vector2.ONE * hero_scale
    stage.add_child(hero)
    hero.set_rest_position(HERO_POS)
    hero.set_weapon("片手剣")
    boss = BOSS_SCRIPT.new()
    boss.position = BOSS_POS
    boss.scale = Vector2.ONE * boss_scale
    stage.add_child(boss)
    boss.configure_region({"id":"R1-B01","phase_index":0}, "boss")
    boss.set_rest_position(BOSS_POS)
    _make_interface()
    _refresh_metrics()
    _set_button_state(false)

func _layout() -> void:
    if not is_instance_valid(stage):
        return
    var k: float = minf(maxf(1.0,size.x) / DESIGN.x, maxf(1.0,size.y) / DESIGN.y)
    stage.scale = Vector2.ONE * k
    stage.position = (size - DESIGN * k) * 0.5

func _process(delta: float) -> void:
    _poll_accum += delta
    if _poll_accum >= 0.18:
        _poll_accum = 0.0
        _refresh_metrics()

func _make_environment() -> void:
    var bg := TextureRect.new()
    bg.texture = BACKDROP
    bg.position = Vector2.ZERO
    bg.size = DESIGN
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(bg)
    var shade := ColorRect.new()
    shade.size = DESIGN
    shade.color = Color(0.015,0.023,0.045,0.45)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(shade)
    _rect(Vector2(0,535),Vector2(1280,185),Color(0.04,0.06,0.10,0.92))
    _rect(Vector2(0,0),Vector2(1280,93),Color(0.025,0.039,0.065,0.96))
    _rect(Vector2(22,106),Vector2(475,177),Color(0.027,0.041,0.075,0.88))
    _rect(Vector2(505,106),Vector2(751,46),Color(0.027,0.041,0.075,0.88))
    var baseline := ColorRect.new()
    baseline.position = Vector2(10,529)
    baseline.size = Vector2(1260,2)
    baseline.color = Color(0.9,0.7,0.43,0.42)
    baseline.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(baseline)

func _rect(pos: Vector2, extent: Vector2, fill: Color) -> void:
    var panel := PanelContainer.new()
    panel.position = pos
    panel.size = extent
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = Color(0.72,0.62,0.49,0.38)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    panel.add_theme_stylebox_override("panel",style)
    stage.add_child(panel)

func _text(value: String, pos: Vector2, size_px: int, color: Color, width: float = 1000.0) -> Label:
    var l := Label.new()
    l.text = value
    l.position = pos
    l.size = Vector2(width,43)
    l.add_theme_font_size_override("font_size",size_px)
    l.add_theme_color_override("font_color",color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(l)
    return l

func _make_interface() -> void:
    _text("SHATTERED CROWN ECHO",Vector2(23,10),30,LIGHT,390)
    _text("STEP 19 — R1-B01 関節内側描画・30動作QA",Vector2(27,51),19,GOLD,620)
    _text("演出専用 / HP・カード効果・敵Intent・セーブは変更しません",Vector2(666,17),16,MUTED,600)
    _text("R1-B01 破城の角獣  |  3頭身プレイヤー比較",Vector2(525,111),19,LIGHT,704)
    _text("連続モーション・復帰位置の検査",Vector2(32,111),19,GOLD,420)
    _make_button("突進",Vector2(32,157),Vector2(104,46),"attack")
    _make_button("咆哮",Vector2(143,157),Vector2(104,46),"roar")
    _make_button("被弾",Vector2(254,157),Vector2(104,46),"hit")
    _make_button("剣士攻撃",Vector2(365,157),Vector2(114,46),"hero")
    _make_button("10周連続検証",Vector2(32,218),Vector2(175,46),"cycle")
    _make_button("1x / 2x / 3x",Vector2(216,218),Vector2(143,46),"speed")
    _make_button("関節点",Vector2(365,218),Vector2(114,46),"debug")
    _text("SIZE",Vector2(28,544),15,GOLD,100)
    _make_button("小 1.25",Vector2(28,575),Vector2(114,49),"size_small")
    _make_button("標準 1.52",Vector2(149,575),Vector2(123,49),"size_normal")
    _make_button("大 1.64",Vector2(279,575),Vector2(122,49),"size_big")
    _make_button("新規描画 ON/OFF",Vector2(411,575),Vector2(135,49),"art")
    _make_button("関節点 ON/OFF",Vector2(553,575),Vector2(163,49),"retouch")
    _make_button("10周レポート保存",Vector2(723,575),Vector2(215,49),"save")
    _make_button("動作リセット",Vector2(946,575),Vector2(172,49),"reset")
    _text("※ STEP19: 形状から描き直した統一モデル。手描き高精細な最終原画ではありません",Vector2(30,650),15,MUTED,950)
    _text("Mana 3/3",Vector2(1118,576),23,Color("9fd5fb"),150)
    qa_label = _text("試験状態を計算しています",Vector2(527,158),17,LIGHT,710)
    ratio_label = _text("",Vector2(527,192),17,GOLD,740)
    progress_label = _text("位置・角度の初期値を保存し、演出後のズレを記録",Vector2(527,232),15,MUTED,720)
    _text("P1：3頭身 / 片手剣",Vector2(185,491),17,LIGHT,290)
    _text("BOSS：同一原画13透過パーツ（比較切替）",Vector2(796,491),17,LIGHT,440)

func _make_button(value:String, pos:Vector2, extent:Vector2, action:String) -> void:
    var b:=Button.new()
    b.text=value
    b.position=pos
    b.size=extent
    b.add_theme_font_size_override("font_size",17)
    b.pressed.connect(_action.bind(action))
    stage.add_child(b)
    buttons.append(b)

func _set_button_state(locked:bool) -> void:
    for button in buttons:
        button.disabled=locked

func _collect_sprites(node:Node, target:Array[Sprite2D]) -> void:
    if node is Sprite2D and (node as Sprite2D).is_visible_in_tree():
        target.append(node as Sprite2D)
    for child in node.get_children():
        _collect_sprites(child,target)

func _bounds(target:Node) -> Rect2:
    var sprites:Array[Sprite2D]=[]
    _collect_sprites(target,sprites)
    var left:float=1.0e8
    var right:float=-1.0e8
    var top:float=1.0e8
    var bottom:float=-1.0e8
    for s in sprites:
        var rect:Rect2=s.get_rect()
        for corner in [rect.position,rect.position+Vector2(rect.size.x,0),rect.position+rect.size,rect.position+Vector2(0,rect.size.y)]:
            var p:Vector2=(stage.get_global_transform().affine_inverse() * s.to_global(corner))
            left=minf(left,p.x)
            right=maxf(right,p.x)
            top=minf(top,p.y)
            bottom=maxf(bottom,p.y)
    if right<=left or bottom<=top:
        return Rect2()
    return Rect2(Vector2(left,top),Vector2(right-left,bottom-top))

func _refresh_metrics() -> void:
    if not is_instance_valid(hero) or not is_instance_valid(boss) or not is_instance_valid(qa_label):
        return
    var hero_box:Rect2=_bounds(hero)
    var boss_box:Rect2=_bounds(boss)
    var visual_ratio:float=boss_box.size.y/maxf(1.0,hero_box.size.y)
    ratio_label.text="見た目の高さ：P1 %dpx / Boss %dpx  =  %.2f倍" % [roundi(hero_box.size.y),roundi(boss_box.size.y),visual_ratio]
    var problematic: Array[String]=[]
    if boss_box.position.y<94.0:problematic.append("ボスがHUD領域へ侵入")
    if boss_box.end.y>552.0:problematic.append("ボスがカード領域へ侵入")
    if boss_box.end.x>1260.0:problematic.append("ボス右端が見切れる")
    if hero_box.position.y<94.0 or hero_box.end.y>552.0:problematic.append("剣士が戦闘枠からはみ出す")
    if hero_box.intersects(boss_box):problematic.append("両キャラの矩形が重複")
    var warning_str:String=" / ".join(problematic) if not problematic.is_empty() else "配置範囲はおおむね適正"
    qa_label.text="速度 %.0fx　完走 %d動作　復帰最大誤差 %.3fpx" % [speed,num_runs,max_reset_error]
    progress_label.text=warning_str

func _reset_error() -> float:
    if not is_instance_valid(boss):return 1.0e6
    var e:float=boss.position.distance_to(BOSS_POS)
    e=maxf(e,absf(boss._b01_root.rotation_degrees) if is_instance_valid(boss._b01_root) else 0.0)
    if is_instance_valid(boss._b01_root):
        e=maxf(e,boss._b01_root.position.length())
        e=maxf(e,boss._b01_root.scale.distance_to(Vector2.ONE))
    e=maxf(e,absf(boss.modulate.r-1.0))
    e=maxf(e,absf(boss.modulate.g-1.0))
    e=maxf(e,absf(boss.modulate.b-1.0))
    for key in boss._b01_default.keys():
        var joint:Node2D=boss._b01_joints.get(key)
        if is_instance_valid(joint):
            e=maxf(e,joint.position.distance_to(boss._b01_default[key]))
    return e

func _record_motion(label:String) -> void:
    num_runs+=1
    var err:float=_reset_error()
    max_reset_error=maxf(max_reset_error,err)
    if err>2.5:
        warnings.append("%s: 復帰誤差 %.3f" % [label,err])
    _refresh_metrics()

func _action(action:String) -> void:
    if busy or not is_instance_valid(boss) or not is_instance_valid(hero):return
    busy=true
    _set_button_state(true)
    match action:
        "attack":
            await boss.play_attack(speed)
            _record_motion("突進")
        "roar":
            await boss.play_roar(speed)
            _record_motion("咆哮")
        "hit":
            await boss.play_hit(speed)
            _record_motion("被弾")
        "hero":
            await hero.play_weapon_action("片手剣",false,speed)
        "cycle":
            for i in range(10):
                await boss.play_attack(speed)
                _record_motion("突進#%d"%(i+1))
                await boss.play_roar(speed)
                _record_motion("咆哮#%d"%(i+1))
                await boss.play_hit(speed)
                _record_motion("被弾#%d"%(i+1))
            _save_report()
        "size_small":boss_scale=1.25
        "size_normal":boss_scale=1.52
        "size_big":boss_scale=1.64
        "speed":speed=1.0 if speed>=3.0 else speed+1.0
        "debug":boss.set_debug_pivots(not boss._step12_debug_enabled)
        "retouch":boss.set_debug_pivots(not boss._step12_debug_enabled)
        "art":boss.set_anatomical_redraw(not boss._step19_enabled)
        "save":_save_report()
        "reset":
            boss.position=BOSS_POS
            boss.modulate=Color.WHITE
            boss._reset_joints()
            hero.set_rest_position(HERO_POS)
    boss.scale=Vector2.ONE*boss_scale
    busy=false
    _set_button_state(false)
    _refresh_metrics()

func _save_report() -> void:
    var h:Rect2=_bounds(hero)
    var b:Rect2=_bounds(boss)
    var report:Dictionary={
        "test":"R1-B01 visual only STEP19",
        "boss_id":"R1-B01",
        "completed_actions":num_runs,
        "max_rest_error_px":max_reset_error,
        "errors":warnings.duplicate(),
        "hero_size_pixels":[roundi(h.size.x),roundi(h.size.y)],
        "boss_size_pixels":[roundi(b.size.x),roundi(b.size.y)],
        "boss_to_hero_height_ratio":snappedf(b.size.y/maxf(1.0,h.size.y),0.01),
        "boss_scale":boss_scale,
        "animation_speed":speed,
        "drawn_sprite_count":boss._b01_joints.size(),
        "redraw_enabled":boss._step19_enabled,
        "pass_rest_reset":max_reset_error<=2.5 and warnings.is_empty(),
        "note":"Visual metrics only; no actual BattleCore or performance benchmark."
    }
    var file:=FileAccess.open(RESULT_FILE,FileAccess.WRITE)
    if file==null:
        progress_label.text="レポート保存失敗："+RESULT_FILE
        return
    file.store_string(JSON.stringify(report,"  "))
    file.close()
    progress_label.text="QAレポート保存済み："+RESULT_FILE
