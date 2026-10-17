extends "res://ui_trial/actors/boss_b01_rig_step13.gd"
## STEP14: visuals ONLY. No HP/AI/RNG/save/EOS modification.
## R1-B01 retains one phase. New overlays are registered under the torso joint.
const GUARD_DIR := "res://ui_trial/assets/step14_b01/"
var _guards: Array[Sprite2D] = []
var _guard_show: bool = true
var _step14_loop_count: int = 0

func _mount_unique() -> void:
    super._mount_unique()
    _guards.clear()
    if not _b01_active or enemy_id != SPECIAL_ID: return
    _attach_guards()
    _calibrate_leg_fit()
    _apply_step13_art()

func _attach_guards() -> void:
    var torso: Node2D = _b01_joints.get("torso")
    if not is_instance_valid(torso) or not is_instance_valid(_b01_root): return
    # Positions are in the original 680x450 reference canvas of STEP11.
    var entries: Array = [
        ["shoulder_front",Vector2(289,271),2],
        ["shoulder_far",Vector2(301,271),-3],
        ["hip_front",Vector2(477,274),2],
        ["hip_far",Vector2(476,274),-3],
        ["neck_base",Vector2(255,233),1]
    ]
    var origin: Vector2 = Vector2(340,390)
    for entry in entries:
        var path: String = GUARD_DIR + str(entry[0]) + ".png"
        if not ResourceLoader.exists(path): continue
        var guard := Sprite2D.new()
        guard.name = "STEP14_Seam_" + str(entry[0])
        guard.texture = load(path)
        guard.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        guard.scale = Vector2.ONE * 0.86 * 0.5
        guard.z_as_relative = false
        guard.z_index = int(entry[2])
        torso.add_child(guard)
        guard.position = torso.to_local(_b01_root.to_global((Vector2(entry[1]) - origin) * 0.86))
        guard.visible = _step13_painted and _guard_show
        _guards.append(guard)

func _calibrate_leg_fit() -> void:
    # Adjust pivots to bring shoulders/hips under the painted torso.
    # Joint default positions are updated so every animation returns to this pose.
    var fits: Dictionary = {
        "fore_near": [Vector2(1,-8), 1.08],
        "fore_far": [Vector2(0,-7), 1.07],
        "hind_near": [Vector2(-1,-6), 1.06],
        "hind_far": [Vector2(0,-6), 1.06]
    }
    for name in fits.keys():
        var joint: Node2D = _b01_joints.get(str(name))
        if not is_instance_valid(joint): continue
        var adjustment: Array = fits[name]
        joint.position += Vector2(adjustment[0])
        _b01_default[name] = joint.position
        var art: Sprite2D = joint.get_node_or_null("Art") as Sprite2D
        if is_instance_valid(art): art.scale.y *= float(adjustment[1])

func _apply_step13_art() -> void:
    super._apply_step13_art()
    if _b01_active and _step13_painted:
        var jaw_joint: Node2D = _b01_joints.get("jaw")
        if is_instance_valid(jaw_joint):
            var jaw_art: Sprite2D = jaw_joint.get_node_or_null("Art") as Sprite2D
            if is_instance_valid(jaw_art):
                jaw_art.texture = load(GUARD_DIR + "jaw_soft.png")
    for guard in _guards:
        if is_instance_valid(guard): guard.visible = _step13_painted and _guard_show

func set_seam_guards(enabled: bool) -> void:
    _guard_show = enabled
    for guard in _guards:
        if is_instance_valid(guard): guard.visible = enabled and _step13_painted

func _reset_joints() -> void:
    super._reset_joints()
    if is_instance_valid(_b01_root):
        _b01_root.scale = Vector2.ONE
        _b01_root.rotation_degrees = 0.0

func _process(delta: float) -> void:
    super._process(delta)
    if not _b01_active or _busy: return
    var b: float = sin(_b01_time*1.9)
    if is_instance_valid(_b01_root):
        _b01_root.scale = Vector2(1.0+0.002*b, 1.0-0.002*b)

func _pose(angles: Dictionary, root_offset: Vector2, actor_offset: Vector2,
    length: float, easing: int = Tween.EASE_IN_OUT, transition: int = Tween.TRANS_CUBIC) -> void:
    var t := create_tween().set_parallel(true)
    t.set_trans(transition).set_ease(easing)
    t.tween_property(self,"position",_rest+actor_offset,length)
    t.tween_property(_b01_root,"position",root_offset,length)
    for key in angles.keys():
        var j: Node2D = _b01_joints.get(str(key))
        if is_instance_valid(j):
            t.tween_property(j,"rotation_degrees",float(angles[key]),length)
    await t.finished

func play_attack(speed: float = 1.0) -> void:
    if not _b01_active:
        await super.play_attack(speed)
        return
    if _busy: return
    _busy=true
    _reset_joints()
    var d: float = 1.0/maxf(speed,0.3)
    # Backward weight shift, left-facing beast.
    await _pose({"neck":8,"head":3,"fore_near":15,"fore_far":-10,
                "hind_near":-11,"hind_far":8,"tail":-4},
                Vector2(0,8),Vector2(25,7),0.24*d,Tween.EASE_OUT)
    # Accelerate; front and rear feet move out of phase. No gameplay timing changes.
    await _pose({"neck":-9,"head":-4,"jaw":9,"fore_near":-22,"fore_far":17,
                "hind_near":14,"hind_far":-11,"tail":9},
                Vector2(0,-5),Vector2(-62,-7),0.18*d,Tween.EASE_IN)
    # Impact is a brief pose; Core has already confirmed damage.
    await _pose({"neck":-12,"head":-7,"jaw":10,"fore_near":-26,"fore_far":21,
                "hind_near":17,"hind_far":-13,"tail":13},
                Vector2(0,-7),Vector2(-81,-6),0.07*d,Tween.EASE_OUT)
    # Smoother recovery to the exact rest position for consecutive cards.
    await _pose({"neck":0,"head":0,"jaw":0,"fore_near":0,"fore_far":0,
                "hind_near":0,"hind_far":0,"tail":0},
                Vector2.ZERO,Vector2.ZERO,0.29*d,Tween.EASE_OUT)
    _reset_joints()
    self.position=_rest
    self.modulate=Color.WHITE
    _busy=false
    _step14_loop_count += 1

func play_roar(speed: float=1.0) -> void:
    if not _b01_active:
        await super.play_roar(speed)
        return
    if _busy:return
    _busy=true
    _reset_joints()
    var d: float=1.0/maxf(speed,0.3)
    await _pose({"neck":-10,"head":-6,"jaw":19,"tail":-5},
                Vector2(0,-8),Vector2.ZERO,0.19*d,Tween.EASE_OUT)
    await get_tree().create_timer(0.13*d).timeout
    await _pose({"neck":0,"head":0,"jaw":0,"tail":0},
                Vector2.ZERO,Vector2.ZERO,0.25*d,Tween.EASE_OUT)
    _reset_joints()
    self.position=_rest
    _busy=false
    _step14_loop_count += 1

func play_hit(speed: float=1.0) -> void:
    if not _b01_active:
        await super.play_hit(speed)
        return
    if _busy:return
    _busy=true
    _reset_joints()
    var d: float=1.0/maxf(speed,0.3)
    var t:=create_tween().set_parallel(true)
    t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    t.tween_property(self,"position",_rest+Vector2(16,-3),0.10*d)
    t.tween_property(_b01_root,"rotation_degrees",-2.5,0.10*d)
    t.tween_property(self,"modulate",Color("fca9a7"),0.10*d)
    await t.finished
    var recover:=create_tween().set_parallel(true)
    recover.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    recover.tween_property(self,"position",_rest,0.22*d)
    recover.tween_property(_b01_root,"rotation_degrees",0.0,0.22*d)
    recover.tween_property(self,"modulate",Color.WHITE,0.22*d)
    await recover.finished
    _reset_joints()
    self.position=_rest
    self.modulate=Color.WHITE
    _busy=false
    _step14_loop_count += 1
