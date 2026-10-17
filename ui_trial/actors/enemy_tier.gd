extends Node2D
## STEP5 display actor for three encounter tiers. Art / animation only.
const MOB_SCRIPT = preload("res://ui_trial/actors/mob_chibi.gd")
const ART := "res://ui_trial/assets/"
var tier: String = "mob"
var _parts: Dictionary = {}
var _mob: Node2D
var _time: float = 0.0
var _busy: bool = false
var _rest: Vector2 = Vector2.ZERO

func configure(next_tier: String) -> void:
    tier = next_tier if next_tier in ["mob", "elite", "boss"] else "mob"
    if is_inside_tree():
        _construct()

func _ready() -> void:
    _rest = position
    _construct()

func _sprite(name: String, offset: Vector2, z: int = 0) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.texture = load(ART + name + ".png")
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    sprite.scale = Vector2(0.5, 0.5)
    sprite.position = offset
    sprite.z_index = z
    add_child(sprite)
    _parts[name] = sprite
    return sprite

func _construct() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    _parts.clear()
    _mob = null
    if tier == "mob":
        _mob = Node2D.new()
        _mob.set_script(MOB_SCRIPT)
        add_child(_mob)
    elif tier == "elite":
        _sprite("elite_cape", Vector2(0, -109), -2)
        _sprite("elite_core", Vector2(0, -91), 0)
        _sprite("elite_head", Vector2(0, -234), 2)
        _sprite("elite_blade", Vector2(136, -110), 3).rotation_degrees = 12
    else:
        _sprite("boss_tail", Vector2(135, -93), -3)
        var left := _sprite("boss_wing", Vector2(-96, -239), -2)
        left.rotation_degrees = -9
        _parts["left_wing"] = left
        var opposite := _sprite("boss_wing", Vector2(96, -235), -2)
        opposite.flip_h = true
        _parts["right_wing"] = opposite
        _sprite("boss_core", Vector2(0, -119), 0)
        _sprite("boss_head", Vector2(0, -310), 2)

func _process(delta: float) -> void:
    _time += delta
    if _busy or tier == "mob": return
    var bob: float = sin(_time * 1.75)
    var head: Sprite2D = _parts.get("elite_head" if tier == "elite" else "boss_head")
    if is_instance_valid(head):
        head.rotation_degrees = bob * (2.4 if tier == "elite" else 1.5)
    if tier == "boss":
        var wings: Sprite2D = _parts.get("left_wing")
        var other: Sprite2D = _parts.get("right_wing")
        if is_instance_valid(wings): wings.rotation_degrees = -9.0 + bob * 4.0
        if is_instance_valid(other): other.rotation_degrees = -bob * 4.0

func set_rest_position(next_position: Vector2) -> void:
    if _busy: return
    _rest = next_position
    position = next_position

func play_hit(speed: float = 1.0) -> void:
    if _busy: return
    if tier == "mob" and is_instance_valid(_mob):
        _mob.call("play_hit",speed)
        return
    _busy = true
    var d := 1.0 / maxf(speed, 0.3)
    var hit := create_tween().set_parallel(true)
    hit.tween_property(self, "position", _rest + Vector2(21, -4), 0.10 * d)
    hit.tween_property(self, "modulate", Color(1.0, 0.45, 0.52), 0.10 * d)
    await hit.finished
    var recover := create_tween().set_parallel(true)
    recover.tween_property(self, "position", _rest, 0.20 * d)
    recover.tween_property(self, "modulate", Color.WHITE, 0.20 * d)
    await recover.finished
    _busy = false

func play_attack(speed: float = 1.0) -> void:
    if _busy:return
    _busy = true
    var d := 1.0 / maxf(speed,0.3)
    var wind := create_tween()
    wind.tween_property(self, "position", _rest + Vector2(18,-2), 0.10*d)
    await wind.finished
    var strike := create_tween()
    strike.tween_property(self, "position", _rest + Vector2(-49,-5), 0.13*d)
    await strike.finished
    var recover := create_tween()
    recover.tween_property(self, "position", _rest, 0.19*d)
    await recover.finished
    _busy = false
