extends Node2D
const WEAPON_SCRIPT = preload("res://ui_trial/actors/weapon_visual.gd")
## 3-heads-tall modular preview actor. VISUAL ONLY; it never changes BattleController.
signal impact_frame

var torso: Node2D
var head_pivot: Node2D
var front_arm: Node2D
var rear_arm: Node2D
var cape_pivot: Node2D
var weapon_pivot: Node2D
var weapon_visual
var current_weapon: String = "片手剣"
var guard_outline: Line2D
var _elapsed: float = 0.0
var _busy: bool = false
var _rest_position: Vector2

func _ready() -> void:
    _rest_position = position
    cape_pivot = Node2D.new()
    cape_pivot.position = Vector2(-15, -206)
    add_child(cape_pivot)
    _part(cape_pivot, "cape", Vector2(-13, 85))

    var hair_back := Node2D.new()
    hair_back.position = Vector2(0, -286)
    add_child(hair_back)
    _part(hair_back, "back_hair", Vector2(0, 12))

    var legs := Node2D.new()
    legs.position = Vector2(0, -70)
    add_child(legs)
    _part(legs, "legs", Vector2(0, 0))

    rear_arm = Node2D.new()
    rear_arm.position = Vector2(-40, -213)
    rear_arm.rotation_degrees = 10.0
    add_child(rear_arm)
    _part(rear_arm, "arm", Vector2(-5, 43))

    torso = Node2D.new()
    torso.position = Vector2(0, -175)
    add_child(torso)
    _part(torso, "torso", Vector2.ZERO)

    head_pivot = Node2D.new()
    head_pivot.position = Vector2(0, -276)
    add_child(head_pivot)
    _part(head_pivot, "head", Vector2.ZERO)
    _part(head_pivot, "bangs", Vector2(0, -44))

    front_arm = Node2D.new()
    front_arm.position = Vector2(40, -211)
    front_arm.rotation_degrees = -14.0
    add_child(front_arm)
    _part(front_arm, "arm", Vector2(2, 44))
    weapon_pivot = Node2D.new()
    weapon_pivot.position = Vector2(12, 91)
    weapon_pivot.rotation_degrees = 86.0
    front_arm.add_child(weapon_pivot)
    weapon_visual = Node2D.new()
    weapon_visual.set_script(WEAPON_SCRIPT)
    weapon_visual.scale = Vector2(0.80,0.80)
    weapon_visual.position = Vector2(0,-70)
    weapon_pivot.add_child(weapon_visual)

    # Outline is visual-only and follows the actor without a weapon swing.
    guard_outline = Line2D.new()
    guard_outline.name = "GuardOutline"
    guard_outline.points = PackedVector2Array([
        Vector2(-74,-264),Vector2(73,-264),Vector2(73,-160),
        Vector2(0,-107),Vector2(-74,-160),Vector2(-74,-264)
    ])
    guard_outline.width = 6.0
    guard_outline.default_color = Color(0.47,0.86,1.0,0.85)
    guard_outline.modulate.a = 0.0
    guard_outline.z_index = 10
    add_child(guard_outline)

func _part(parent: Node2D, part_name: String, offset: Vector2) -> void:
    var sprite := Sprite2D.new()
    sprite.texture = load("res://ui_trial/assets/%s.png" % part_name)
    # PNG files use 2x source pixels for crisp rendering.
    sprite.scale = Vector2(0.5, 0.5)
    sprite.position = offset
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    parent.add_child(sprite)

func _process(delta: float) -> void:
    _elapsed += delta
    if _busy:
        return
    var bob := sin(_elapsed * 2.8)
    torso.position.y = -175.0 + bob * 1.7
    head_pivot.rotation_degrees = sin(_elapsed * 1.7) * 2.0
    cape_pivot.rotation_degrees = sin(_elapsed * 1.9) * 5.0
    front_arm.rotation_degrees = -14.0 + sin(_elapsed * 2.3) * 2.0
    rear_arm.rotation_degrees = 10.0 - sin(_elapsed * 2.3) * 2.0

func play_attack(finisher: bool = false, speed: float = 1.0) -> void:
    if _busy:
        return
    _busy = true
    var factor: float = 1.0 / maxf(0.2, speed)
    var original: Vector2 = _rest_position
    var windup := create_tween()
    windup.set_parallel(true)
    windup.tween_property(self, "position", original + Vector2(-14, 0), 0.13 * factor)
    windup.tween_property(front_arm, "rotation_degrees", -105.0, 0.13 * factor)
    windup.tween_property(weapon_pivot, "rotation_degrees", 18.0, 0.13 * factor)
    await windup.finished

    var strike := create_tween()
    strike.set_parallel(true)
    strike.tween_property(self, "position", original + Vector2(98 if finisher else 78, 0), 0.17 * factor)
    strike.tween_property(front_arm, "rotation_degrees", 95.0, 0.17 * factor)
    strike.tween_property(weapon_pivot, "rotation_degrees", 123.0, 0.17 * factor)
    await strike.finished
    impact_frame.emit()

    var recover := create_tween()
    recover.set_parallel(true)
    recover.tween_property(self, "position", original, 0.20 * factor)
    recover.tween_property(front_arm, "rotation_degrees", -14.0, 0.20 * factor)
    recover.tween_property(weapon_pivot, "rotation_degrees", 86.0, 0.20 * factor)
    await recover.finished
    _busy = false

func set_rest_position(next_position: Vector2) -> void:
    if _busy:
        return
    _rest_position = next_position
    position = next_position

func play_cast(speed: float = 1.0) -> void:
    if _busy:
        return
    _busy = true
    var factor := 1.0 / maxf(0.3, speed)
    var prepare := create_tween()
    prepare.set_parallel(true)
    prepare.tween_property(front_arm, "rotation_degrees", -85.0, 0.15 * factor)
    prepare.tween_property(weapon_pivot, "rotation_degrees", 12.0, 0.15 * factor)
    prepare.tween_property(head_pivot, "rotation_degrees", -9.0, 0.15 * factor)
    await prepare.finished
    var end := create_tween()
    end.set_parallel(true)
    end.tween_property(front_arm, "rotation_degrees", -14.0, 0.18 * factor)
    end.tween_property(weapon_pivot, "rotation_degrees", 86.0, 0.18 * factor)
    end.tween_property(head_pivot, "rotation_degrees", 0.0, 0.18 * factor)
    await end.finished
    _busy = false

func play_hit(speed: float = 1.0) -> void:
    if _busy:
        return
    _busy = true
    var factor := 1.0 / maxf(0.3, speed)
    var normal := _rest_position
    var hit := create_tween()
    hit.set_parallel(true)
    hit.tween_property(self, "position", normal + Vector2(-14, -6), 0.10 * factor)
    hit.tween_property(self, "modulate", Color(1.0, 0.5, 0.5), 0.10 * factor)
    await hit.finished
    var end := create_tween()
    end.set_parallel(true)
    end.tween_property(self, "position", normal, 0.17 * factor)
    end.tween_property(self, "modulate", Color.WHITE, 0.17 * factor)
    await end.finished
    _busy = false


# STEP3: a separate animation family for each of six weapon types.
# Each routine only affects drawing/poses. Never reads or writes gameplay resources.
func set_weapon(weapon: String) -> void:
    current_weapon = weapon if weapon in WEAPON_SCRIPT.VALID else "片手剣"
    if is_instance_valid(weapon_visual):
        weapon_visual.set_weapon(current_weapon)

func _pose(offset: Vector2, arm: float, blade: float, back_arm: float, duration: float) -> void:
    var anim := create_tween()
    anim.set_parallel(true)
    anim.tween_property(self,"position",_rest_position+offset,duration)
    anim.tween_property(front_arm,"rotation_degrees",arm,duration)
    anim.tween_property(weapon_pivot,"rotation_degrees",blade,duration)
    anim.tween_property(rear_arm,"rotation_degrees",back_arm,duration)
    await anim.finished

func _rest_pose(duration: float) -> void:
    await _pose(Vector2.ZERO,-14.0,86.0,10.0,duration)
    weapon_visual.set_glow(0.0)
    _busy = false

func play_weapon_action(weapon: String, is_finisher: bool = false, speed: float = 1.0) -> void:
    if _busy: return
    set_weapon(weapon)
    _busy = true
    var d: float = 1.0 / maxf(0.35,speed)
    if is_finisher: weapon_visual.set_glow(0.9)
    match current_weapon:
        "片手剣":
            await _pose(Vector2(-12,0),-95.0,15.0,20.0,0.11*d)
            await _pose(Vector2(76,0),100.0,125.0,-20.0,0.16*d)
        "レイピア":
            await _pose(Vector2(-8,0),-28.0,-65.0,5.0,0.09*d)
            await _pose(Vector2(105,-4),-36.0,-87.0,-20.0,0.10*d)
        "短剣":
            await _pose(Vector2(30,0),-43.0,-80.0,22.0,0.07*d)
            await _pose(Vector2(64,0),-12.0,60.0,-11.0,0.07*d)
            await _pose(Vector2(43,0),-82.0,-80.0,25.0,0.06*d)
            await _pose(Vector2(79,0),-5.0,80.0,-20.0,0.07*d)
        "大剣":
            await _pose(Vector2(-24,0),-142.0,-10.0,64.0,0.24*d)
            await _pose(Vector2(88,-6),130.0,147.0,-45.0,0.23*d)
        "魔法剣":
            await _pose(Vector2(-2,0),-88.0,-15.0,-50.0,0.13*d)
            weapon_visual.set_glow(1.0)
            await _pose(Vector2(61,-4),75.0,119.0,-19.0,0.20*d)
        "刀":
            # Sheathed-style hold -> fast single-draw Iai.
            await _pose(Vector2(-25,0),38.0,145.0,-40.0,0.17*d)
            await _pose(Vector2(116,-3),94.0,15.0,-35.0,0.075*d)
    impact_frame.emit()  # one display event; never a second gameplay hit
    await _rest_pose(0.17*d)

func play_weapon_skill(weapon: String, speed: float = 1.0) -> void:
    if _busy: return
    set_weapon(weapon)
    _busy = true
    var d: float = 1.0/maxf(0.35,speed)
    var angle: float = -80.0 if current_weapon in ["魔法剣","レイピア"] else -45.0
    var held: float = 9.0 if current_weapon == "刀" else 30.0
    await _pose(Vector2(0,-3),angle,held,-45.0,0.13*d)
    weapon_visual.set_glow(0.65)
    await _pose(Vector2(12,-6),-27.0,72.0,-16.0,0.12*d)
    await _rest_pose(0.12*d)


func play_guard(speed: float = 1.0) -> void:
    # Block/defence cards never execute an attacking swing or emit impact_frame.
    if _busy: return
    _busy = true
    var d: float = 1.0 / maxf(0.35, speed)
    var old_modulate: Color = modulate
    var up := create_tween().set_parallel(true)
    up.tween_property(self, "position", _rest_position + Vector2(-4.0,-3.0), 0.12*d)
    up.tween_property(front_arm, "rotation_degrees", -27.0, 0.12*d)
    up.tween_property(weapon_pivot, "rotation_degrees", 71.0, 0.12*d)
    up.tween_property(rear_arm, "rotation_degrees", -24.0, 0.12*d)
    up.tween_property(guard_outline, "modulate:a", 0.95, 0.12*d)
    up.tween_property(self, "modulate", Color(0.82,0.95,1.0,old_modulate.a), 0.12*d)
    await up.finished
    await get_tree().create_timer(0.12*d).timeout
    var down := create_tween().set_parallel(true)
    down.tween_property(self, "position", _rest_position, 0.15*d)
    down.tween_property(front_arm, "rotation_degrees", -14.0, 0.15*d)
    down.tween_property(weapon_pivot, "rotation_degrees", 86.0, 0.15*d)
    down.tween_property(rear_arm, "rotation_degrees", 10.0, 0.15*d)
    down.tween_property(guard_outline, "modulate:a", 0.0, 0.15*d)
    down.tween_property(self, "modulate", old_modulate, 0.15*d)
    await down.finished
    _busy = false
