extends Control
## STEP20 pose-scrub QA laboratory. Display only; not a combat implementation.
const ACTOR = preload("res://ui_trial/actors/boss_b01_rig_step19.gd")
const HERO = preload("res://ui_trial/actors/actor3h.gd")
const OVERLAY = preload("res://ui_trial/actors/step20_joint_overlay.gd")
const BG = preload("res://ui_trial/assets/battle_background.webp")
const DESIGN := Vector2(1280,720)
const BOSS_REST := Vector2(839,506)
const HERO_REST := Vector2(304,526)
const COLOR_GOLD := Color("e9c888")
const COLOR_TEXT := Color("f3f0eb")
const COLOR_MUTED := Color("bed1de")
const REPORT := "user://step20_r1b01_pose_report.json"

# Matches the anatomical rotations used by STEP14. These are frozen *visual*
# keyframes, NOT new enemy attacks or gameplay phases.
const POSES: Array = [
    {"name":"待機", "angles":{}, "shift":Vector2.ZERO, "root":Vector2.ZERO,"tilt":0.0},
    {"name":"溜め", "angles":{"neck":8,"head":3,"fore_near":15,"fore_far":-10,"hind_near":-11,"hind_far":8,"tail":-4},"shift":Vector2(25,7),"root":Vector2(0,8),"tilt":0.0},
    {"name":"突進", "angles":{"neck":-9,"head":-4,"jaw":9,"fore_near":-22,"fore_far":17,"hind_near":14,"hind_far":-11,"tail":9},"shift":Vector2(-62,-7),"root":Vector2(0,-5),"tilt":0.0},
    {"name":"衝突", "angles":{"neck":-12,"head":-7,"jaw":10,"fore_near":-26,"fore_far":21,"hind_near":17,"hind_far":-13,"tail":13},"shift":Vector2(-81,-6),"root":Vector2(0,-7),"tilt":0.0},
    {"name":"復帰", "angles":{}, "shift":Vector2.ZERO,"root":Vector2.ZERO,"tilt":0.0},
    {"name":"咆哮", "angles":{"neck":-10,"head":-6,"jaw":19,"tail":-5},"shift":Vector2.ZERO,"root":Vector2(0,-8),"tilt":0.0},
    {"name":"被弾", "angles":{}, "shift":Vector2(16,-3),"root":Vector2.ZERO,"tilt":-2.5},
    {"name":"終了", "angles":{}, "shift":Vector2.ZERO,"root":Vector2.ZERO,"tilt":0.0}
]
var stage: Control
var hero: Node2D
var boss: Node2D
var overlay: Node2D
var slider: HSlider
var pose_label: Label
var status: Label
var result_label: Label
var buttons: Array[Button] = []
var busy: bool = false
var speed: float = 2.0
var completed: int = 0
var max_rest_error: float = 0.0
var issues: Array[String] = []
var clip_warnings: Array[String] = []
var show_inspector: bool = true
var monitor_elapsed: float = 0.0

func _ready() -> void:
    stage = Control.new()
    stage.size = DESIGN
    stage.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(stage)
    resized.connect(_layout)
    _layout()
    var bg := TextureRect.new()
    bg.texture = BG
    bg.position = Vector2.ZERO
    bg.size = DESIGN
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(bg)
    var shade := ColorRect.new()
    shade.position = Vector2.ZERO
    shade.size = DESIGN
    shade.color = Color(0.02,0.03,0.05,0.54)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(shade)
    _panel(Vector2(0,0),Vector2(1280,103),Color(0.018,0.031,0.055,0.93))
    _panel(Vector2(0,549),Vector2(1280,171),Color(0.018,0.031,0.055,0.95))
    var guide := ColorRect.new()
    guide.position = Vector2(12,539)
    guide.size = Vector2(1255,2)
    guide.color = Color(0.92,0.78,0.54,0.55)
    guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(guide)
    hero = HERO.new()
    hero.position = HERO_REST
    hero.scale = Vector2.ONE * 0.57
    stage.add_child(hero)
    hero.set_rest_position(HERO_REST)
    hero.set_weapon("片手剣")
    boss = ACTOR.new()
    boss.position = BOSS_REST
    boss.scale = Vector2.ONE * 1.35
    stage.add_child(boss)
    boss.configure_region({"id":"R1-B01","phase_index":0},"boss")
    boss.set_rest_position(BOSS_REST)
    overlay = OVERLAY.new()
    overlay.actor = boss
    overlay.enabled = show_inspector
    stage.add_child(overlay)
    _make_controls()
    _set_pose(0.0)

func _layout() -> void:
    if not is_instance_valid(stage):return
    var k: float = minf(maxf(size.x,1.0)/DESIGN.x,maxf(size.y,1.0)/DESIGN.y)
    stage.scale=Vector2.ONE*k
    stage.position=(size-DESIGN*k)*0.5

func _panel(pos:Vector2, dimensions:Vector2, fill:Color) -> void:
    var p:=ColorRect.new()
    p.position=pos
    p.size=dimensions
    p.color=fill
    p.mouse_filter=Control.MOUSE_FILTER_IGNORE
    stage.add_child(p)

func _label(s:String,pos:Vector2,font_size:int,color:Color,w:float=1200.0)->Label:
    var t:=Label.new()
    t.text=s
    t.position=pos
    t.size=Vector2(w,45)
    t.add_theme_font_size_override("font_size",font_size)
    t.add_theme_color_override("font_color",color)
    t.mouse_filter=Control.MOUSE_FILTER_IGNORE
    stage.add_child(t)
    return t

func _button(s:String,pos:Vector2,dim:Vector2,callback:Callable)->void:
    var b:=Button.new()
    b.text=s
    b.position=pos
    b.size=dim
    b.add_theme_font_size_override("font_size",17)
    b.pressed.connect(callback)
    stage.add_child(b)
    buttons.append(b)

func _make_controls() -> void:
    _label("SHATTERED CROWN ECHO  /  STEP 20",Vector2(18,9),27,COLOR_TEXT,720)
    _label("R1-B01 破城の角獣 — 13パーツ可動ポーズ検査",Vector2(20,49),20,COLOR_GOLD,850)
    _label("プレビュー専用・本編のカード/HP/敵AIは変更しません",Vector2(815,31),15,COLOR_MUTED,470)
    _label("3頭身プレイヤー",Vector2(192,486),16,COLOR_TEXT,270)
    _label("R1-B01 / 姿勢の補間・関節位置の確認",Vector2(650,486),17,COLOR_TEXT,600)
    pose_label=_label("現在：待機",Vector2(20,559),18,COLOR_GOLD,280)
    slider=HSlider.new()
    slider.position=Vector2(310,566)
    slider.size=Vector2(940,32)
    slider.min_value=0.0
    slider.max_value=float(POSES.size()-1)
    slider.step=0.01
    slider.value_changed.connect(_on_scrub)
    stage.add_child(slider)
    _button("先頭へ",Vector2(19,616),Vector2(105,45),func():slider.value=0.0)
    _button("待機→突進",Vector2(130,616),Vector2(151,45),func():_run_motion("attack"))
    _button("咆哮",Vector2(287,616),Vector2(105,45),func():_run_motion("roar"))
    _button("被弾",Vector2(398,616),Vector2(105,45),func():_run_motion("hit"))
    _button("10周×3動作",Vector2(509,616),Vector2(167,45),func():_run_motion("stress"))
    _button("関節ガイド",Vector2(682,616),Vector2(138,45),_toggle_pivots)
    _button("新旧アート",Vector2(826,616),Vector2(134,45),_toggle_art)
    _button("記録を保存",Vector2(966,616),Vector2(139,45),_save_report)
    _button("1x / 2x / 3x",Vector2(1111,616),Vector2(140,45),_switch_speed)
    status=_label("キーフレームをスライダーで停止できます",Vector2(22,670),15,COLOR_MUTED,750)
    result_label=_label("各動作終了後の位置・回転ズレを記録",Vector2(760,670),15,COLOR_MUTED,490)

func _on_scrub(value:float) -> void:
    if not busy:_set_pose(value)

func _set_pose(value:float) -> void:
    if not is_instance_valid(boss) or not boss._b01_active:return
    boss._busy=true # pause idle breathing during manual inspection
    boss._reset_joints()
    var i:int=clampi(int(floor(value)),0,POSES.size()-1)
    var next:int=mini(i+1,POSES.size()-1)
    var t:float=clampf(value-float(i),0.0,1.0)
    var a:Dictionary=POSES[i]
    var b:Dictionary=POSES[next]
    var shift:Vector2=(a["shift"] as Vector2).lerp(b["shift"] as Vector2,t)
    var root_shift:Vector2=(a["root"] as Vector2).lerp(b["root"] as Vector2,t)
    boss.position=BOSS_REST+shift
    boss._b01_root.position=root_shift
    boss._b01_root.rotation_degrees=lerpf(float(a["tilt"]),float(b["tilt"]),t)
    for k in boss._b01_joints.keys():
        var j:Node2D=boss._b01_joints[k]
        if is_instance_valid(j):
            j.rotation_degrees=lerpf(float((a["angles"] as Dictionary).get(k,0.0)),float((b["angles"] as Dictionary).get(k,0.0)),t)
    pose_label.text="現在：%s → %s  (%d%%)" % [str(a["name"]),str(b["name"]),roundi(t*100.0)]
    if is_instance_valid(overlay):overlay.queue_redraw()
    _check_field_bounds(str(a["name"]))

func _visual_bounds() -> Rect2:
    var lo:Vector2=Vector2(100000.0,100000.0)
    var hi:Vector2=Vector2(-100000.0,-100000.0)
    var found:bool=false
    if not is_instance_valid(boss):return Rect2()
    for raw in boss._b01_joints.keys():
        var joint:Node2D=boss._b01_joints[raw]
        if not is_instance_valid(joint):continue
        var art:Sprite2D=joint.get_node_or_null("Art") as Sprite2D
        if not is_instance_valid(art) or not art.visible or art.texture==null:continue
        var area:Rect2=art.get_rect()
        for corner in [area.position,area.position+Vector2(area.size.x,0),area.end,area.position+Vector2(0,area.size.y)]:
            var q:Vector2=(stage.get_global_transform().affine_inverse() * art.to_global(corner))
            lo.x=minf(lo.x,q.x);lo.y=minf(lo.y,q.y)
            hi.x=maxf(hi.x,q.x);hi.y=maxf(hi.y,q.y)
            found=true
    return Rect2(lo,hi-lo) if found else Rect2()

func _check_field_bounds(pose_name:String)->void:
    var r:Rect2=_visual_bounds()
    if r.size==Vector2.ZERO:return
    var flags:Array[String]=[]
    if r.position.y<103.0:flags.append("HUD上部に重複")
    if r.end.y>549.0:flags.append("操作領域に重複")
    if r.position.x<0.0 or r.end.x>1280.0:flags.append("左右にはみ出し")
    for flag in flags:
        var msg:String=pose_name+": "+flag
        if not clip_warnings.has(msg):clip_warnings.append(msg)
    if not busy and is_instance_valid(status):
        status.text=" / ".join(flags) if not flags.is_empty() else "現在のポーズ：画面の大きなはみ出しなし"

func _toggle_pivots() -> void:
    show_inspector=not show_inspector
    overlay.enabled=show_inspector
    overlay.queue_redraw()
    status.text="関節位置ガイド：表示" if show_inspector else "関節位置ガイド：非表示"

func _toggle_art() -> void:
    if busy:return
    boss._busy=false
    boss.set_anatomical_redraw(not boss._step19_enabled)
    boss._busy=true
    _set_pose(slider.value)
    status.text="STEP19統一素材" if boss._step19_enabled else "STEP18旧素材（比較のみ）"

func _switch_speed() -> void:
    if busy:return
    speed=1.0 if speed>=3.0 else speed+1.0
    status.text="再生速度：%.0fx"%speed

func _run_motion(kind:String) -> void:
    if busy:return
    busy=true
    for button in buttons:button.disabled=true
    slider.editable=false
    boss._busy=false
    boss._reset_joints()
    boss.position=BOSS_REST
    boss.modulate=Color.WHITE
    # Await the *actual* Godot tweens, not a simulated animation clock.
    if kind=="stress":
        for i in range(10):
            await boss.play_attack(speed)
            _check_reset("突進_%d"%(i+1))
            await boss.play_roar(speed)
            _check_reset("咆哮_%d"%(i+1))
            await boss.play_hit(speed)
            _check_reset("被弾_%d"%(i+1))
        _save_report()
    elif kind=="attack":
        await boss.play_attack(speed)
        _check_reset("突進")
    elif kind=="roar":
        await boss.play_roar(speed)
        _check_reset("咆哮")
    elif kind=="hit":
        await boss.play_hit(speed)
        _check_reset("被弾")
    boss._busy=true
    busy=false
    slider.editable=true
    for button in buttons:button.disabled=false
    slider.value=0.0
    _set_pose(0.0)

func _check_reset(label:String)->void:
    completed+=1
    var err:float=boss.position.distance_to(BOSS_REST)
    err=maxf(err,boss._b01_root.position.length())
    err=maxf(err,absf(boss._b01_root.rotation_degrees))
    err=maxf(err,boss._b01_root.scale.distance_to(Vector2.ONE))
    for name in boss._b01_default.keys():
        var j:Node2D=boss._b01_joints.get(name)
        if is_instance_valid(j):
            err=maxf(err,j.position.distance_to(boss._b01_default[name]))
            err=maxf(err,absf(j.rotation_degrees))
    max_rest_error=maxf(max_rest_error,err)
    _check_field_bounds(label)
    if err>2.5:issues.append("%s：復帰誤差 %.3f"%[label,err])
    result_label.text="検証 %d 動作 / 最大復帰誤差 %.3f / 警告 %d"%[completed,max_rest_error,issues.size()]

func _save_report() -> void:
    var data:Dictionary={
        "schema":1,"scenario":"step20_r1_b01_pose_qa","boss_id":"R1-B01",
        "completed_actions":completed,"max_rest_error":max_rest_error,
        "pass_rest":completed>0 and max_rest_error<=2.5 and issues.is_empty(),
        "issues":issues.duplicate(),"bounds_warnings":clip_warnings.duplicate(),"art_step19":boss._step19_enabled,
        "joint_count":boss._b01_joints.size(),"speed":speed,
        "note":"Only Godot visual animation reset; no BattleCore test, FPS test, or image-quality certification."
    }
    var f:=FileAccess.open(REPORT,FileAccess.WRITE)
    if f==null:
        status.text="保存失敗："+REPORT
        return
    f.store_string(JSON.stringify(data,"  "))
    f.close()
    status.text="レポート保存："+REPORT
