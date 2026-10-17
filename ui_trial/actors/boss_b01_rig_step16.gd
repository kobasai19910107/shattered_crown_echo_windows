extends "res://ui_trial/actors/boss_b01_rig_step14.gd"
## STEP16: purely local, optional R1-B01 seam correction; no battle state/RNG.
## Adds seven feathered texture-matched caps and foot-grounding correction.
const REGISTER_PATH := "res://ui_trial/assets/step16_b01/registration.json"
const CAP_DIR := "res://ui_trial/assets/step16_b01/"
var _step16_caps: Array[Sprite2D] = []
var _step16_new_seams: bool = true
var _step16_leg_anchors: Dictionary = {}

func _mount_unique() -> void:
    _step16_caps.clear()
    super._mount_unique()
    if not _b01_active or enemy_id != SPECIAL_ID:
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTER_PATH))
    if not parsed is Dictionary:
        push_warning("STEP16 registration unavailable; STEP14 art remains intact")
        return
    var d: Dictionary = parsed
    _step16_leg_anchors = d.get("leg_grounding", {}).duplicate(true)
    for entry in d.get("caps", []):
        if not entry is Dictionary:
            continue
        var asset: String = CAP_DIR + str(entry.get("name", "")) + ".png"
        if not ResourceLoader.exists(asset):
            continue
        var parent: Node2D = _b01_joints.get(str(entry.get("parent", "")))
        if not is_instance_valid(parent):
            continue
        var sp := Sprite2D.new()
        sp.name = "STEP16_" + str(entry.get("name", ""))
        sp.texture = load(asset)
        sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        sp.scale = Vector2.ONE * 0.86 * 0.5
        sp.z_as_relative = false
        sp.z_index = int(entry.get("z", 5))
        parent.add_child(sp)
        var point: Array = entry.get("center", [340,390])
        var ref := Vector2(float(point[0]),float(point[1]))
        sp.position = parent.to_local(_b01_root.to_global((ref - Vector2(340,390)) * 0.86))
        _step16_caps.append(sp)
    # Old STEP14 guard stamps and new textured caps must never be drawn together.
    super.set_seam_guards(false)
    _step16_new_seams = true
    _sync_step16_caps()

func _sync_step16_caps() -> void:
    for cap in _step16_caps:
        if is_instance_valid(cap):
            cap.visible = _b01_active and _step13_painted and _step16_new_seams

func _apply_step13_art() -> void:
    super._apply_step13_art()
    _sync_step16_caps()

func set_seam_guards(enabled: bool) -> void:
    # Compatibility with STEP15 button: enabled -> STEP14 original seams;
    # disabled -> STEP16 texture-matched seams. Preserves the old visual as control.
    super.set_seam_guards(enabled)
    _step16_new_seams = not enabled
    _sync_step16_caps()

func use_new_seams(enabled: bool) -> void:
    set_seam_guards(not enabled)

func _foot_offset_for(name: String, angle: float, actor_offset: Vector2) -> Vector2:
    if not _step16_leg_anchors.has(name):
        return Vector2.ZERO
    var anchor: Array = _step16_leg_anchors[name]
    var base := Vector2(float(anchor[0]),float(anchor[1])) * 0.86
    var rotated: Vector2 = base.rotated(deg_to_rad(angle))
    var grounded: float = 0.70 if absf(actor_offset.x) < 40.0 else 0.25
    var delta_y: float = clampf(-(rotated.y-base.y)*grounded,-12.0,12.0)
    # Near legs move naturally around shoulder/hip; this compensates paw elevation only.
    return Vector2(0,delta_y)

func _pose(angles: Dictionary, root_offset: Vector2, actor_offset: Vector2,
    length: float, easing: int = Tween.EASE_IN_OUT,
    transition: int = Tween.TRANS_CUBIC) -> void:
    # Override only the animation interpolation, never change damage timing/state.
    var tween := create_tween().set_parallel(true)
    tween.set_trans(transition).set_ease(easing)
    tween.tween_property(self,"position",_rest+actor_offset,length)
    tween.tween_property(_b01_root,"position",root_offset,length)
    for key in angles.keys():
        var name: String = str(key)
        var joint: Node2D = _b01_joints.get(name)
        if not is_instance_valid(joint):
            continue
        var target_angle: float = float(angles[key])
        tween.tween_property(joint,"rotation_degrees",target_angle,length)
        if _step16_leg_anchors.has(name):
            var desired: Vector2 = _b01_default[name] + _foot_offset_for(name,target_angle,actor_offset)
            tween.tween_property(joint,"position",desired,length)
    await tween.finished
