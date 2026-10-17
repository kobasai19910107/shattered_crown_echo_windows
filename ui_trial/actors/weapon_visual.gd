extends Node2D
## STEP4: independently illustrated transparent weapon sprites, independent of gameplay.
## No card data, MP, HP, RNG, target checks, or battle authority here.
const VALID := ["片手剣", "レイピア", "短剣", "大剣", "魔法剣", "刀"]
const FILES := {
    "片手剣": "res://ui_trial/assets/weapon_sword.png",
    "レイピア": "res://ui_trial/assets/weapon_rapier.png",
    "短剣": "res://ui_trial/assets/weapon_dagger.png",
    "大剣": "res://ui_trial/assets/weapon_greatsword.png",
    "魔法剣": "res://ui_trial/assets/weapon_magic_sword.png",
    "刀": "res://ui_trial/assets/weapon_katana.png",
}
var weapon_type: String = "片手剣"
var glow: float = 0.0
var _sprite: Sprite2D

func _ready() -> void:
    _ensure_sprite()
    _update_image()

func _ensure_sprite() -> void:
    if is_instance_valid(_sprite):
        return
    _sprite = Sprite2D.new()
    _sprite.name = "WeaponArtwork"
    _sprite.centered = true
    _sprite.position = Vector2(0.0, -85.0)
    # Transparent textures are generated at double battle-stage resolution.
    _sprite.scale = Vector2(0.5, 0.5)
    _sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    add_child(_sprite)

func set_weapon(value: String) -> void:
    weapon_type = value if value in VALID else "片手剣"
    _ensure_sprite()
    _update_image()

func _update_image() -> void:
    var path: String = str(FILES.get(weapon_type, FILES["片手剣"]))
    _sprite.texture = load(path) as Texture2D
    if _sprite.texture == null:
        push_warning("STEP4 weapon artwork missing: " + path)
    queue_redraw()

func set_glow(value: float) -> void:
    glow = clampf(value, 0.0, 1.0)
    if is_instance_valid(_sprite):
        _sprite.modulate = Color(1.0, 1.0, 1.0 - glow * 0.15)
    queue_redraw()

func _draw() -> void:
    if glow > 0.01:
        draw_arc(Vector2(0, -85), 37.0 + glow * 10.0,
            0.0, TAU, 32, Color(0.52, 0.83, 1.0, glow * 0.75), 2.0, true)
