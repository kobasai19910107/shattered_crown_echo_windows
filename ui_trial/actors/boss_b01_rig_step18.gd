extends "res://ui_trial/actors/boss_b01_rig_step17.gd"
## STEP18 VISUAL-ONLY experimental hidden-joint retouch for R1-B01.
## Does not modify battle logic, RNG, HP, phase, saves or networking.
const DIR18 := "res://ui_trial/assets/step18_b01/"
var _step18_enabled: bool = true
var _step18_pieces: Array[Sprite2D] = []
var _step18_original: Dictionary = {}

func _mount_unique() -> void:
    _step18_pieces.clear()
    _step18_original.clear()
    super._mount_unique()
    if not _b01_active or enemy_id != SPECIAL_ID:
        return
    _build_step18_underpaint()
    _apply_step18_retouched()

func _build_step18_underpaint() -> void:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR18 + "registration.json"))
    if not data is Dictionary:
        push_warning("STEP18 registration unavailable, STEP17 art remains")
        return
    for raw in data.get("overlays", []):
        if not raw is Dictionary:
            continue
        var parent: Node2D = _b01_joints.get(str(raw.get("parent", "")))
        var name: String = str(raw.get("name", ""))
        var texture_path: String = DIR18 + name + ".png"
        if not is_instance_valid(parent) or not ResourceLoader.exists(texture_path):
            continue
        var sprite := Sprite2D.new()
        sprite.name = "STEP18_" + name
        sprite.texture = load(texture_path)
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        sprite.scale = Vector2.ONE * 0.86 * 0.5
        sprite.z_as_relative = false
        sprite.z_index = int(raw.get("z", 0))
        var center: Array = raw.get("center", [340,390])
        var center_ref := Vector2(float(center[0]),float(center[1]))
        parent.add_child(sprite)
        sprite.position = parent.to_local(_b01_root.to_global((center_ref - Vector2(340,390)) * 0.86))
        _step18_pieces.append(sprite)

func _apply_step18_retouched() -> void:
    if not _b01_active or enemy_id != SPECIAL_ID:
        return
    var active: bool = _step18_enabled and _step17_unified
    for name in _b01_joints.keys():
        var joint: Node2D = _b01_joints[name]
        if not is_instance_valid(joint):
            continue
        var art: Sprite2D = joint.get_node_or_null("Art") as Sprite2D
        if not is_instance_valid(art):
            continue
        if not _step18_original.has(name):
            _step18_original[name] = art.texture
        var revised: String = DIR18 + str(name) + "_clean.png"
        if active and ResourceLoader.exists(revised):
            art.texture = load(revised)
        else:
            art.texture = _step18_original[name]
        # Suppress duplicate horn and aura in joint QA, never hide for old comparison.
        art.visible = not (active and name in ["horn_far","crimson_aura"])
    for overlay in _step18_pieces:
        if is_instance_valid(overlay):
            overlay.visible = active

func set_joint_retouch(enabled: bool) -> void:
    if _busy:
        return
    _step18_enabled = enabled
    _apply_step18_retouched()

func _apply_step17_view() -> void:
    super._apply_step17_view()
    _apply_step18_retouched()

func set_unified(enabled: bool) -> void:
    super.set_unified(enabled)
    _apply_step18_retouched()
