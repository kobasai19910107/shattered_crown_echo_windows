extends "res://ui_trial/actors/boss_b01_rig.gd"
## STEP12 – non-destructive articulated B01. Real art remains STEP11 until layer repaint.
## No card, enemy state, RNG, HP, phase, save, or EOS mutations.

var _step12_joint_debug: Array[Node2D] = []
var _step12_debug_enabled: bool = false

func _mount_unique() -> void:
    _step12_joint_debug.clear()
    super._mount_unique()
    if not _b01_active or enemy_id != SPECIAL_ID:
        return
    # STEP11 attached everything to a single root. Parent parts anatomically:
    # jaw/horns follow head; head follows neck; neck/spines/tail follow torso.
    # keep_global_transform=true prevents snapping on adoption.
    var family: Dictionary = {
        "neck":"torso", "head":"neck", "jaw":"head",
        "horn_near":"head", "horn_far":"head", "spines_back":"torso",
        "tail":"torso", "crimson_aura":"torso"
    }
    for part_name in ["neck","head","jaw","horn_near","horn_far","spines_back","tail","crimson_aura"]:
        var child: Node2D = _b01_joints.get(part_name)
        var parent: Node2D = _b01_joints.get(str(family.get(part_name,"")))
        if not is_instance_valid(child) or not is_instance_valid(parent):
            continue
        child.reparent(parent, true)
        child.z_as_relative = false
        _b01_default[part_name] = child.position
    # Nested joints have explicit global layer order; protect STEP11 z values.
    for key in _b01_joints.keys():
        var joint: Node2D = _b01_joints[key]
        if is_instance_valid(joint):
            joint.z_as_relative = false
            # The pivot is a local origin; debug markers stay attached to joints.
            var marker := Polygon2D.new()
            marker.polygon = PackedVector2Array([
                Vector2(-3,-3),Vector2(3,-3),Vector2(3,3),Vector2(-3,3)])
            marker.color = Color("65f5d4")
            marker.z_index = 30
            marker.z_as_relative = false
            marker.visible = _step12_debug_enabled
            joint.add_child(marker)
            _step12_joint_debug.append(marker)

func set_debug_pivots(enabled: bool) -> void:
    _step12_debug_enabled = enabled
    for item in _step12_joint_debug:
        if is_instance_valid(item):
            item.visible = enabled

func _reset_joints() -> void:
    super._reset_joints()
    if is_instance_valid(_b01_root):
        _b01_root.rotation_degrees = 0.0
    for key in _b01_joints.keys():
        var joint: Node2D = _b01_joints[key]
        if is_instance_valid(joint): joint.scale = Vector2.ONE

func _process(delta: float) -> void:
    super._process(delta)
    if not _b01_active or _busy: return
    # Opposing subtle foot shifts give weight without breaking ground contact.
    var b: float = sin(_b01_time*1.9)
    var front: Node2D = _b01_joints.get("fore_near")
    var hind: Node2D = _b01_joints.get("hind_near")
    if is_instance_valid(front): front.rotation_degrees = -1.1*b
    if is_instance_valid(hind): hind.rotation_degrees = 0.9*b
    var aura: Node2D = _b01_joints.get("crimson_aura")
    if is_instance_valid(aura):
        var sprite := aura.get_node_or_null("Art") as Sprite2D
        if is_instance_valid(sprite): sprite.modulate.a = 0.72 + 0.12*b

func play_attack(speed: float=1.0) -> void:
    if not _b01_active:
        await super.play_attack(speed)
        return
    if _busy: return
    _busy = true
    _reset_joints()
    var d: float = 1.0 / maxf(0.3, speed)
    var fore: Node2D = _b01_joints.get("fore_near")
    var fore_back: Node2D = _b01_joints.get("fore_far")
    var hind: Node2D = _b01_joints.get("hind_near")
    var hind_back: Node2D = _b01_joints.get("hind_far")
    var neck: Node2D = _b01_joints.get("neck")
    var jaw: Node2D = _b01_joints.get("jaw")
    # Anticipation. Beast faces left; crouch backward (+X), then leap left.
    var anticipate := create_tween().set_parallel(true)
    anticipate.tween_property(self,"position",_rest+Vector2(33,9),0.23*d)
    anticipate.tween_property(_b01_root,"position",Vector2(0,11),0.23*d)
    if is_instance_valid(neck): anticipate.tween_property(neck,"rotation_degrees",8.0,0.23*d)
    if is_instance_valid(fore): anticipate.tween_property(fore,"rotation_degrees",18.0,0.23*d)
    if is_instance_valid(hind): anticipate.tween_property(hind,"rotation_degrees",-13.0,0.23*d)
    await anticipate.finished
    # Charge. Front and rear legs oppose each other; jaw opens for the impact.
    var dash := create_tween().set_parallel(true)
    dash.tween_property(self,"position",_rest+Vector2(-91,-9),0.18*d)
    dash.tween_property(_b01_root,"position",Vector2(0,-8),0.18*d)
    if is_instance_valid(neck): dash.tween_property(neck,"rotation_degrees",-9.0,0.18*d)
    if is_instance_valid(fore): dash.tween_property(fore,"rotation_degrees",-25.0,0.18*d)
    if is_instance_valid(fore_back):dash.tween_property(fore_back,"rotation_degrees",20.0,0.18*d)
    if is_instance_valid(hind):dash.tween_property(hind,"rotation_degrees",20.0,0.18*d)
    if is_instance_valid(hind_back):dash.tween_property(hind_back,"rotation_degrees",-18.0,0.18*d)
    if is_instance_valid(jaw):dash.tween_property(jaw,"rotation_degrees",12.0,0.18*d)
    await dash.finished
    # Body settles; the logic already resolved this attack independently.
    var recover := create_tween().set_parallel(true)
    recover.tween_property(self,"position",_rest,0.32*d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    recover.tween_property(_b01_root,"position",Vector2.ZERO,0.32*d)
    for name in ["neck","fore_near","fore_far","hind_near","hind_far","jaw"]:
        var node: Node2D = _b01_joints.get(name)
        if is_instance_valid(node): recover.tween_property(node,"rotation_degrees",0.0,0.32*d)
    await recover.finished
    _reset_joints()
    _busy = false

func play_roar(speed: float=1.0) -> void:
    if not _b01_active:
        await super.play_roar(speed)
        return
    if _busy: return
    _busy = true
    _reset_joints()
    var d: float = 1.0 / maxf(speed,0.3)
    var neck: Node2D = _b01_joints.get("neck")
    var jaw: Node2D = _b01_joints.get("jaw")
    var head: Node2D = _b01_joints.get("head")
    var t := create_tween().set_parallel(true)
    if is_instance_valid(neck):t.tween_property(neck,"rotation_degrees",-11.0,0.23*d)
    if is_instance_valid(head):t.tween_property(head,"rotation_degrees",-6.0,0.23*d)
    if is_instance_valid(jaw):t.tween_property(jaw,"rotation_degrees",22.0,0.23*d)
    t.tween_property(_b01_root,"position",Vector2(0,-11),0.23*d)
    await t.finished
    await get_tree().create_timer(0.11*d).timeout
    var release := create_tween().set_parallel(true)
    for name in ["neck","head","jaw"]:
        var node: Node2D = _b01_joints.get(name)
        if is_instance_valid(node):release.tween_property(node,"rotation_degrees",0.0,0.20*d)
    release.tween_property(_b01_root,"position",Vector2.ZERO,0.20*d)
    await release.finished
    _reset_joints()
    _busy = false

func play_hit(speed: float=1.0) -> void:
    if not _b01_active:
        await super.play_hit(speed)
        return
    if _busy: return
    _busy = true
    _reset_joints()
    var d: float = 1.0/maxf(speed,0.3)
    var neck: Node2D = _b01_joints.get("neck")
    var hit := create_tween().set_parallel(true)
    hit.tween_property(self,"position",_rest+Vector2(20,-4),0.085*d)
    hit.tween_property(_b01_root,"rotation_degrees",-3.0,0.085*d)
    if is_instance_valid(neck):hit.tween_property(neck,"rotation_degrees",-6.0,0.085*d)
    hit.tween_property(self,"modulate",Color("ff888a"),0.085*d)
    await hit.finished
    var back := create_tween().set_parallel(true)
    back.tween_property(self,"position",_rest,0.22*d)
    back.tween_property(_b01_root,"rotation_degrees",0.0,0.22*d)
    if is_instance_valid(neck):back.tween_property(neck,"rotation_degrees",0.0,0.22*d)
    back.tween_property(self,"modulate",Color.WHITE,0.22*d)
    await back.finished
    _reset_joints()
    _busy = false
