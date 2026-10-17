extends "res://ui_trial/actors/region1_unique_enemy_visual.gd"
## STEP11 — visual-only R1-B01 thirteen-layer rig; Battle Core and RNG are untouched.
## Other Region1 enemy IDs continue to use STEP9 visuals.

const RIG_JSON := "res://ui_trial/assets/step11_b01/rig.json"
const SPECIAL_ID := "R1-B01"
var _b01_root: Node2D
var _b01_joints: Dictionary = {}
var _b01_default: Dictionary = {}
var _b01_time: float = 0.0
var _b01_active: bool = false

func _mount_unique() -> void:
    if enemy_id != SPECIAL_ID:
        _b01_active = false
        _clear_b01()
        super._mount_unique()
        return
    # No changes to encounter state; only the displayed image is replaced.
    _clear_b01()
    if is_instance_valid(unique_root):
        remove_child(unique_root)
        unique_root.queue_free()
    unique_parts.clear()
    unique_initial.clear()
    for n in _parts.values():
        if n is CanvasItem: (n as CanvasItem).visible = false
    if is_instance_valid(_mob): _mob.visible = false
    if is_instance_valid(emblem): emblem.visible = false
    var file := FileAccess.get_file_as_string(RIG_JSON)
    var parsed = JSON.parse_string(file)
    if not parsed is Dictionary:
        push_warning("STEP11 rig profile invalid; old R1-B01 sprite remains available in STEP9")
        super._mount_unique()
        return
    _b01_root = Node2D.new()
    _b01_root.name = "R1B01_ArticulatedRig"
    add_child(_b01_root)
    var origin: Array = parsed.get("origin", [340.0,390.0])
    var origin_pos := Vector2(float(origin[0]),float(origin[1]))
    var visual_scale := 0.86
    for entry in parsed.get("parts", []):
        if not entry is Dictionary: continue
        var name: String = str(entry.get("name", ""))
        var asset: String = str(entry.get("asset", ""))
        if not ResourceLoader.exists(asset): continue
        var pivot: Array = entry.get("pivot", [0.0,0.0])
        var center: Array = entry.get("center", [0.0,0.0])
        var pivot_pos := Vector2(float(pivot[0]),float(pivot[1]))
        var center_pos := Vector2(float(center[0]),float(center[1]))
        var joint := Node2D.new()
        joint.name = "Joint_" + name
        joint.position = (pivot_pos - origin_pos) * visual_scale
        joint.z_index = int(entry.get("z",0))
        _b01_root.add_child(joint)
        var sprite := Sprite2D.new()
        sprite.name = "Art"
        sprite.texture = load(asset)
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        sprite.position = (center_pos - pivot_pos) * visual_scale
        # PNGs were exported at 2x resolution; use 0.5x + actual world scale.
        sprite.scale = Vector2.ONE * visual_scale * 0.5
        joint.add_child(sprite)
        _b01_joints[name] = joint
        _b01_default[name] = joint.position
    _b01_active = not _b01_joints.is_empty()

func _clear_b01() -> void:
    if is_instance_valid(_b01_root):
        _b01_root.get_parent().remove_child(_b01_root)
        _b01_root.queue_free()
    _b01_root = null
    _b01_joints.clear()
    _b01_default.clear()

func _process(delta: float) -> void:
    super._process(delta)
    if not _b01_active or _busy: return
    _b01_time += delta
    var breath: float = sin(_b01_time*1.9)
    var tail: Node2D = _b01_joints.get("tail")
    if is_instance_valid(tail): tail.rotation_degrees = breath*5.0
    var head: Node2D = _b01_joints.get("head")
    if is_instance_valid(head): head.rotation_degrees = breath*1.6
    var jaw: Node2D = _b01_joints.get("jaw")
    if is_instance_valid(jaw): jaw.rotation_degrees = 1.5 + 1.5*breath
    var torso: Node2D = _b01_joints.get("torso")
    if is_instance_valid(torso): torso.position.y = (_b01_default["torso"] as Vector2).y + breath*2.0

func _reset_joints() -> void:
    for raw_name in _b01_joints.keys():
        var node: Node2D = _b01_joints[raw_name]
        if not is_instance_valid(node): continue
        node.position = _b01_default[raw_name]
        node.rotation_degrees = 0.0
    if is_instance_valid(_b01_root): _b01_root.position = Vector2.ZERO

func play_roar(speed: float = 1.0) -> void:
    if not _b01_active or _busy: return
    _busy = true
    _reset_joints()
    var scale_t: float = 1.0/maxf(speed,0.3)
    var head: Node2D = _b01_joints.get("head")
    var jaw: Node2D = _b01_joints.get("jaw")
    var move := create_tween().set_parallel(true)
    if is_instance_valid(head): move.tween_property(head,"rotation_degrees",-13.0,0.22*scale_t)
    if is_instance_valid(jaw): move.tween_property(jaw,"rotation_degrees",20.0,0.22*scale_t)
    move.tween_property(_b01_root,"position",Vector2(0,-13),0.22*scale_t)
    await move.finished
    await get_tree().create_timer(0.14*scale_t).timeout
    var end := create_tween().set_parallel(true)
    if is_instance_valid(head): end.tween_property(head,"rotation_degrees",0.0,0.20*scale_t)
    if is_instance_valid(jaw): end.tween_property(jaw,"rotation_degrees",0.0,0.20*scale_t)
    end.tween_property(_b01_root,"position",Vector2.ZERO,0.20*scale_t)
    await end.finished
    _reset_joints()
    _busy = false

func play_attack(speed: float = 1.0) -> void:
    if not _b01_active:
        await super.play_attack(speed)
        return
    if _busy: return
    _busy = true
    _reset_joints()
    var d: float = 1.0/maxf(speed,0.3)
    var fore: Node2D = _b01_joints.get("fore_near")
    var far: Node2D = _b01_joints.get("fore_far")
    var jaw: Node2D = _b01_joints.get("jaw")
    # The character faces left. Wind up to the right then charge left.
    var wind := create_tween().set_parallel(true)
    wind.tween_property(self,"position",_rest+Vector2(29,8),0.17*d)
    if is_instance_valid(fore): wind.tween_property(fore,"rotation_degrees",17.0,0.17*d)
    if is_instance_valid(far): wind.tween_property(far,"rotation_degrees",-12.0,0.17*d)
    if is_instance_valid(jaw): wind.tween_property(jaw,"rotation_degrees",14.0,0.17*d)
    await wind.finished
    var charge := create_tween().set_parallel(true)
    charge.tween_property(self,"position",_rest+Vector2(-85,-7),0.18*d)
    if is_instance_valid(fore): charge.tween_property(fore,"rotation_degrees",-28.0,0.18*d)
    if is_instance_valid(far): charge.tween_property(far,"rotation_degrees",25.0,0.18*d)
    await charge.finished
    var back := create_tween().set_parallel(true)
    back.tween_property(self,"position",_rest,0.26*d)
    if is_instance_valid(fore): back.tween_property(fore,"rotation_degrees",0.0,0.26*d)
    if is_instance_valid(far): back.tween_property(far,"rotation_degrees",0.0,0.26*d)
    if is_instance_valid(jaw): back.tween_property(jaw,"rotation_degrees",0.0,0.26*d)
    await back.finished
    _reset_joints()
    _busy = false

func play_hit(speed: float = 1.0) -> void:
    if not _b01_active:
        await super.play_hit(speed)
        return
    if _busy: return
    _busy = true
    var d: float = 1.0/maxf(speed,0.3)
    var hit := create_tween().set_parallel(true)
    hit.tween_property(self,"position",_rest+Vector2(21,-5),0.09*d)
    hit.tween_property(_b01_root,"rotation_degrees",-5.0,0.09*d)
    hit.tween_property(self,"modulate",Color("ff8186"),0.09*d)
    await hit.finished
    var back := create_tween().set_parallel(true)
    back.tween_property(self,"position",_rest,0.19*d)
    back.tween_property(_b01_root,"rotation_degrees",0.0,0.19*d)
    back.tween_property(self,"modulate",Color.WHITE,0.19*d)
    await back.finished
    _reset_joints()
    _busy = false
