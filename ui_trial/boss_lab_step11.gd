extends Control
## Visual-only R1-B01 animation laboratory; it does not load or modify saved games.
const RIG_SCRIPT = preload("res://ui_trial/actors/boss_b01_rig.gd")
var actor: Node2D
var title: Label
var status: Label
var stage: Control
var buttons: Array[Button] = []
const BASE := Vector2(1280,720)

func _ready() -> void:
    stage = Control.new()
    stage.size=BASE
    stage.mouse_filter=Control.MOUSE_FILTER_PASS
    add_child(stage)
    resized.connect(_layout)
    _layout()
    var bg=ColorRect.new()
    bg.size=BASE
    bg.color=Color("151b2a")
    stage.add_child(bg)
    for i in range(9):
        var ruin=ColorRect.new()
        ruin.color=Color(0.27,0.31,0.42,0.24)
        ruin.position=Vector2(float(i)*150+35,215-float((i*37)%110))
        ruin.size=Vector2(36,BASE.y-ruin.position.y-130)
        stage.add_child(ruin)
    var floor_rect=ColorRect.new()
    floor_rect.position=Vector2(0,555)
    floor_rect.size=Vector2(1280,165)
    floor_rect.color=Color("242c3b")
    stage.add_child(floor_rect)
    actor=RIG_SCRIPT.new()
    actor.position=Vector2(745,555)
    stage.add_child(actor)
    actor.configure_region({"id":"R1-B01","phase_index":0},"boss")
    actor.set_rest_position(Vector2(745,555))
    title=_label("R1-B01 | 破城の角獣 — 13パーツ可動検証",Vector2(35,33),30)
    _label("カード・HP・敵AIは変更しない独立演出テスト",Vector2(40,89),19)
    status=_label("待機中：頭・尻尾・胴体が呼吸アニメーション",Vector2(41,640),20)
    _button("突進 Attack",Vector2(32,177),"attack")
    _button("咆哮 Roar",Vector2(32,251),"roar")
    _button("被弾 Hit",Vector2(32,325),"hit")
    _button("待機 Reset",Vector2(32,399),"reset")
    _label("元のSTEP9の全14敵・120カードは継承",Vector2(41,590),18)

func _layout() -> void:
    if not is_instance_valid(stage): return
    var factor:float=minf(size.x/BASE.x,size.y/BASE.y)
    stage.scale=Vector2.ONE*factor
    stage.position=(size-BASE*factor)*0.5

func _label(value:String,pos:Vector2,font:int) -> Label:
    var l:=Label.new()
    l.text=value
    l.position=pos
    l.size=Vector2(930,45)
    l.add_theme_font_size_override("font_size",font)
    l.add_theme_color_override("font_color",Color("e8d8c6"))
    stage.add_child(l)
    return l

func _button(value:String,pos:Vector2,action:String) -> void:
    var b:=Button.new()
    b.text=value
    b.position=pos
    b.size=Vector2(220,56)
    b.add_theme_font_size_override("font_size",22)
    b.pressed.connect(_activate.bind(action))
    stage.add_child(b)
    buttons.append(b)

func _activate(action:String) -> void:
    if actor == null or actor._busy:return
    for b in buttons:b.disabled=true
    match action:
        "attack":
            status.text="突進：溜め→前脚を振る→左へ突進→復帰"
            await actor.play_attack(1.0)
        "roar":
            status.text="咆哮：頭を上げ、顎を開く"
            await actor.play_roar(1.0)
        "hit":
            status.text="被弾：後退・赤い被弾フラッシュ"
            await actor.play_hit(1.0)
        _:
            actor.position=Vector2(745,555)
            actor.modulate=Color.WHITE
            actor._reset_joints()
            status.text="待機状態へ復帰"
    for b in buttons:b.disabled=false
