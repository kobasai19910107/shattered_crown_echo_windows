extends "res://ui_trial/actors/boss_b01_rig_step12.gd"
## STEP13: local visual-only texture swap. Battle Core, RNG, phase and saves untouched.
const STEP13_DIR := "res://ui_trial/assets/step13_b01/"
const STEP11_DIR := "res://ui_trial/assets/step11_b01/"
var _step13_painted: bool = true

func _mount_unique() -> void:
    super._mount_unique()
    if not _b01_active or enemy_id != SPECIAL_ID:
        return
    _apply_step13_art()

func _apply_step13_art() -> void:
    if not _b01_active:
        return
    for key in _b01_joints.keys():
        var sprite: Sprite2D = _b01_joints[key].get_node_or_null("Art") as Sprite2D
        if not is_instance_valid(sprite):
            continue
        var dir_path: String = STEP13_DIR if _step13_painted else STEP11_DIR
        var tex_path: String = dir_path + str(key) + ".png"
        if ResourceLoader.exists(tex_path):
            sprite.texture = load(tex_path)

func set_painted(enabled: bool) -> void:
    _step13_painted = enabled
    _apply_step13_art()
