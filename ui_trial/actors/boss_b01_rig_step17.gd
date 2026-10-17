extends "res://ui_trial/actors/boss_b01_rig_step16.gd"
## STEP17 visual-only single-source art pass. No damage/RNG/HP/phase/save logic.
const STEP17_DIR := "res://ui_trial/assets/step17_b01/"
var _step17_unified: bool = true
var _step17_tail_base_position: Vector2 = Vector2.ZERO
var _step17_tail_position_ready: bool = false

func _mount_unique() -> void:
    _step17_tail_position_ready = false
    super._mount_unique()
    var tail_joint: Node2D = _b01_joints.get("tail")
    if is_instance_valid(tail_joint):
        var tail_art: Sprite2D = tail_joint.get_node_or_null("Art") as Sprite2D
        if is_instance_valid(tail_art):
            _step17_tail_base_position = tail_art.position
            _step17_tail_position_ready = true
    _apply_step17_view()

func _apply_step13_art() -> void:
    super._apply_step13_art()
    _apply_step17_view()

func _apply_step17_view() -> void:
    if not _b01_active or enemy_id != SPECIAL_ID:
        return
    if _step17_unified:
        for raw_name in _b01_joints.keys():
            var name: String = str(raw_name)
            var joint: Node2D = _b01_joints.get(name)
            if not is_instance_valid(joint):
                continue
            var art: Sprite2D = joint.get_node_or_null("Art") as Sprite2D
            if not is_instance_valid(art):
                continue
            var tex_path: String = STEP17_DIR + name + ".png"
            if ResourceLoader.exists(tex_path):
                art.texture = load(tex_path)
    var tail_joint: Node2D = _b01_joints.get("tail")
    if _step17_tail_position_ready and is_instance_valid(tail_joint):
        var tail_art: Sprite2D = tail_joint.get_node_or_null("Art") as Sprite2D
        if is_instance_valid(tail_art):
            tail_art.position = _step17_tail_base_position + (Vector2(-78.0, 42.0) * 0.86 if _step17_unified else Vector2.ZERO)
    # STEP16 texture caps are calibrated to STEP13's old palette; never overpaint
    # the single-source STEP17 art with those prior textured caps.
    for cap in _step16_caps:
        if is_instance_valid(cap):
            cap.visible = not _step17_unified and _step13_painted and _step16_new_seams
    for guard in _guards:
        if is_instance_valid(guard):
            guard.visible = not _step17_unified and _step13_painted and _guard_show

func set_unified(enabled: bool) -> void:
    if _busy:
        return
    _step17_unified = enabled
    # Keep original painted art as a non-destructive comparison baseline.
    set_painted(true)
    _apply_step17_view()

func set_seam_guards(enabled: bool) -> void:
    super.set_seam_guards(enabled)
    _apply_step17_view()
