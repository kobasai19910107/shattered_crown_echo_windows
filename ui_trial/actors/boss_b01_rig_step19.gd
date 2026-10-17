extends "res://ui_trial/actors/boss_b01_rig_step18.gd"
## STEP19 — independently drawn anatomical overlaps + hierarchical joints.
## Pure visual actor. The BattleController / save / online code is unchanged.
const DIR19 := "res://ui_trial/assets/step19_b01/"
var _step19_enabled: bool = true
var _step19_meta: Dictionary = {}
var _step19_original: Dictionary = {}

func _mount_unique() -> void:
    super._mount_unique()
    if not _b01_active or enemy_id != SPECIAL_ID:
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR19 + "geometry.json"))
    if not raw is Dictionary:
        push_warning("STEP19 geometric registration missing; STEP18 remains active")
        return
    _step19_meta = raw.get("parts", {})
    if _step19_meta.size() != 13:
        push_warning("STEP19 incomplete sprites; original art is retained")
        return
    _step19_original.clear()
    for key in _b01_joints:
        var joint: Node2D = _b01_joints[key]
        if not is_instance_valid(joint):
            continue
        var art: Sprite2D = joint.get_node_or_null("Art") as Sprite2D
        if not is_instance_valid(art):
            continue
        _step19_original[str(key)] = {
            "texture": art.texture,
            "position": art.position,
            "scale": art.scale,
            "visible": art.visible,
            "z": joint.z_index
        }
    _link_anatomy()
    _apply_step19_view()

func _link_anatomy() -> void:
    # Change parenting while keeping each joint's global pivot position.
    # neck/legs/tail are anatomically connected to torso, jaw/horns to head.
    var torso: Node2D = _b01_joints.get("torso")
    var neck: Node2D = _b01_joints.get("neck")
    var head: Node2D = _b01_joints.get("head")
    if not is_instance_valid(torso) or not is_instance_valid(neck) or not is_instance_valid(head):
        return
    for name in ["neck", "tail", "spines_back", "fore_far", "fore_near", "hind_far", "hind_near"]:
        var j: Node2D = _b01_joints.get(name)
        if is_instance_valid(j):
            j.reparent(torso, true)
    head.reparent(neck, true)
    for name in ["jaw", "horn_near", "horn_far"]:
        var j: Node2D = _b01_joints.get(name)
        if is_instance_valid(j):
            j.reparent(head, true)
    var aura: Node2D = _b01_joints.get("crimson_aura")
    if is_instance_valid(aura):
        aura.reparent(torso, true)
    # Reparenting alters LOCAL joint coordinates; rest points must use new local values.
    for name in _b01_joints:
        var j: Node2D = _b01_joints[name]
        if is_instance_valid(j):
            j.z_as_relative = false
            _b01_default[name] = j.position

func _apply_step19_view() -> void:
    if not _b01_active or _step19_meta.is_empty():
        return
    for raw_name in _b01_joints:
        var name: String = str(raw_name)
        var j: Node2D = _b01_joints[name]
        if not is_instance_valid(j):
            continue
        var art: Sprite2D = j.get_node_or_null("Art") as Sprite2D
        if not is_instance_valid(art):
            continue
        if _step19_enabled and _step19_meta.has(name):
            var data: Dictionary = _step19_meta[name]
            var resource_path: String = DIR19 + name + ".png"
            if not ResourceLoader.exists(resource_path):
                push_error("Missing STEP19 part: " + name)
                continue
            art.texture = load(resource_path)
            var pivot: Array = data.get("pivot", [0,0])
            var center: Array = data.get("center", [0,0])
            var world_center := Vector2(float(center[0]), float(center[1]))
            var world_pivot := Vector2(float(pivot[0]), float(pivot[1]))
            art.position = (world_center - world_pivot) * 0.86
            art.scale = Vector2.ONE * 0.43
            art.visible = name != "crimson_aura"
            j.z_index = int(data.get("z", 0))
        elif _step19_original.has(name):
            var saved: Dictionary = _step19_original[name]
            art.texture = saved.get("texture")
            art.position = saved.get("position", Vector2.ZERO)
            art.scale = saved.get("scale", Vector2.ONE)
            art.visible = bool(saved.get("visible", true))
            j.z_index = int(saved.get("z", 0))
    for p in _step18_pieces:
        if is_instance_valid(p):
            p.visible = not _step19_enabled and _step18_enabled and _step17_unified
    for cap in _step16_caps:
        if is_instance_valid(cap):
            cap.visible = false if _step19_enabled else cap.visible
    for g in _guards:
        if is_instance_valid(g):
            g.visible = false if _step19_enabled else g.visible

func set_anatomical_redraw(enabled: bool) -> void:
    if _busy:
        return
    _step19_enabled = enabled
    _apply_step19_view()

func play_roar(speed: float = 1.0) -> void:
    # Jaw is a child of the head: it opens in the head's local pose.
    await super.play_roar(speed)

func _reset_joints() -> void:
    super._reset_joints()
    # The previously inherited hit motion applies a short root rotation.
    if is_instance_valid(_b01_root):
        _b01_root.rotation_degrees = 0.0
