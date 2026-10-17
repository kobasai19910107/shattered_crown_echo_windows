extends "res://ui_trial/actors/region_enemy_visual.gd"
## STEP9: Region1 individual 3-part sprites. Read-only visual overlay.
const UNIQUE_BASE := "res://ui_trial/assets/region1_unique/"
const PROFILES_PATH := "res://ui_trial/region1_unique_profiles.json"
var unique_root: Node2D
var unique_parts: Dictionary = {}
var unique_initial: Dictionary = {}
var sprite_scale: float = 1.0
var unique_elapsed: float = 0.0

func _ready() -> void:
    super._ready()
    _mount_unique()

func configure_region(enemy: Dictionary, fallback_tier: String) -> void:
    super.configure_region(enemy, fallback_tier)
    if is_inside_tree(): _mount_unique()

func _mount_unique() -> void:
    if not enemy_id.begins_with("R1-"): return
    var profile_path: String = UNIQUE_BASE + enemy_id + "/body.png"
    if not ResourceLoader.exists(profile_path): return
    if is_instance_valid(unique_root):
        remove_child(unique_root)
        unique_root.queue_free()
    unique_parts.clear()
    unique_initial.clear()
    # STEP8 stock sprites remain in the scene but are hidden when an ID-specific sprite exists.
    for part in _parts.values():
        if part is CanvasItem: (part as CanvasItem).visible = false
    if is_instance_valid(_mob): _mob.visible = false
    if is_instance_valid(emblem): emblem.visible = false
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILES_PATH))
    if not parsed is Dictionary: return
    var profile: Dictionary = parsed.get("enemies",{}).get(enemy_id,{})
    if profile.is_empty(): return
    unique_root = Node2D.new()
    unique_root.name = "UniqueR1Art"
    add_child(unique_root)
    sprite_scale = 0.86 if tier == "mob" else (0.94 if tier == "elite" else 1.04)
    for part_name in ["body","head","weapon"]:
        var sprite := Sprite2D.new()
        sprite.name = part_name.capitalize()
        sprite.texture = load(UNIQUE_BASE + enemy_id + "/" + part_name + ".png")
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        var v: Dictionary = profile.get("offsets",{}).get(part_name,{})
        var offset: Array = v.get("offset",[0,0])
        sprite.position = Vector2(float(offset[0]),float(offset[1])) * sprite_scale
        sprite.scale = Vector2.ONE * sprite_scale
        sprite.z_index = {"body":0,"head":2,"weapon":3}.get(part_name,0)
        unique_root.add_child(sprite)
        unique_parts[part_name] = sprite
        unique_initial[part_name] = sprite.position
    _tint_unique()

func _process(delta: float) -> void:
    super._process(delta)
    unique_elapsed += delta
    if not _busy and is_instance_valid(unique_root):
        var head: Sprite2D = unique_parts.get("head")
        var weapon: Sprite2D = unique_parts.get("weapon")
        if is_instance_valid(head):
            head.position.y = (unique_initial["head"] as Vector2).y + sin(unique_elapsed*1.95)*2.7
            head.rotation_degrees = sin(unique_elapsed*1.4)*1.7
        if is_instance_valid(weapon):
            weapon.rotation_degrees = sin(unique_elapsed*1.4+0.7)*2.5

func play_attack(speed: float = 1.0) -> void:
    if not _busy and is_instance_valid(unique_root):
        var weapon: Sprite2D = unique_parts.get("weapon")
        if is_instance_valid(weapon):
            var duration: float = 1.0/maxf(0.3,speed)
            var swing := create_tween()
            swing.tween_property(weapon,"rotation_degrees",-23.0,0.10*duration)
            swing.tween_property(weapon,"rotation_degrees",28.0,0.14*duration)
            swing.tween_property(weapon,"rotation_degrees",0.0,0.18*duration)
    await super.play_attack(speed)

func _tint_unique() -> void:
    for part in unique_parts.values():
        if is_instance_valid(part):
            var blend: float = minf(0.33,float(phase_shown)*0.11)
            part.modulate = Color.WHITE.lerp(Color("ffadab"), blend)

func play_phase_change(phase: int, speed: float = 1.0) -> void:
    await super.play_phase_change(phase,speed)
    _tint_unique()


func play_hit(speed: float = 1.0) -> void:
    # Region1 unique mobs hide _mob (the legacy sprite). Animate the VISIBLE
    # UniqueR1Art directly; inherited mob play_hit moved only the hidden _mob.
    if not is_instance_valid(unique_root):
        await super.play_hit(speed)
        return
    if _busy: return
    _busy = true
    var d: float = 1.0 / maxf(0.3, speed)
    var rest: Vector2 = unique_root.position
    var normal_tint: Color = unique_root.modulate
    var hit := create_tween().set_parallel(true)
    hit.tween_property(unique_root, "position", rest+Vector2(25.0,-4.0), 0.11*d)
    hit.tween_property(unique_root, "modulate", Color(1.0,0.37,0.46,normal_tint.a), 0.11*d)
    await hit.finished
    var return_tween := create_tween().set_parallel(true)
    return_tween.tween_property(unique_root, "position", rest, 0.22*d)
    return_tween.tween_property(unique_root, "modulate", normal_tint, 0.22*d)
    await return_tween.finished
    _busy = false
