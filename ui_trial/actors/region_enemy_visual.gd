extends "res://ui_trial/actors/enemy_tier.gd"
## STEP8: Enemy visuals only. Never changes BattleController or enemy Dictionary.
const ATLAS_ROOT := "res://ui_trial/assets/regions/"
var enemy_id: String = ""
var region_id: int = 1
var role_number: int = 1
var phase_shown: int = 0
var id_color: Color = Color("a2bac1")
var emblem: Sprite2D
var glow: Sprite2D

func configure_region(enemy: Dictionary, fallback_tier: String) -> void:
    enemy_id = str(enemy.get("id", ""))
    region_id = clampi(int(enemy_id.substr(1, 1)) if enemy_id.begins_with("R") else 1, 1, 6)
    role_number = clampi(int(enemy_id.get_slice("-",1).substr(1,2)),1,7)
    phase_shown = int(enemy.get("phase_index", 0))
    id_color = [Color("a2bac1"),Color("5aaf83"),Color("e66a4e"),Color("6bcbf7"),Color("edce8e"),Color("a78bfa")][region_id-1]
    configure(fallback_tier)
    if is_inside_tree():_apply_art()

func _ready() -> void:
    super._ready()
    _apply_art()

func _apply_art() -> void:
    if not is_inside_tree():return
    var prefix: String = ATLAS_ROOT+"R%d/"%region_id
    # Replace the original STEP5 sprite parts with region-specific art variants.
    for name in _parts.keys():
        var node = _parts[name]
        if not node is Sprite2D:continue
        var part: String=str(name)
        if part in ["left_wing","right_wing"]:part="boss_wing"
        var image_path: String=prefix+part+".png"
        if ResourceLoader.exists(image_path):(node as Sprite2D).texture=load(image_path)
    if _mob!=null:
        _replace_nested(_mob,prefix)
    if not is_instance_valid(emblem):
        emblem=Sprite2D.new()
        emblem.position=Vector2(0,-260 if tier=="mob" else (-300 if tier=="elite" else -419))
        emblem.scale=Vector2(1.15,1.15)
        emblem.z_index=12
        add_child(emblem)
    var badge: String=ATLAS_ROOT+enemy_id+".png"
    if ResourceLoader.exists(badge):emblem.texture=load(badge)
    emblem.modulate=Color.WHITE.lerp(id_color,0.10)
    _update_phase_tint()

func _replace_nested(parent: Node, prefix: String) -> void:
    for n in parent.get_children():
        if n is Sprite2D:
            var tex: Texture2D=(n as Sprite2D).texture
            if tex!=null:
                var path: String=prefix+str(tex.resource_path).get_file()
                if ResourceLoader.exists(path):(n as Sprite2D).texture=load(path)
        _replace_nested(n,prefix)

func _update_phase_tint() -> void:
    # visual intensity only; multi-phase bosses remain governed by Battle Core.
    if is_instance_valid(emblem):emblem.modulate=Color.WHITE.lerp(id_color,0.20+minf(0.68,float(phase_shown)*0.17))
    for name in _parts.keys():
        var p=_parts[name]
        if p is Sprite2D and is_instance_valid(p):
            (p as Sprite2D).modulate=Color.WHITE.lerp(id_color,minf(0.42,float(phase_shown)*0.10))

func play_phase_change(phase: int, speed: float=1.0) -> void:
    if phase<=phase_shown:return
    phase_shown=phase
    _update_phase_tint()
    var scale_original: Vector2=scale
    var t:=create_tween().set_parallel(true)
    t.tween_property(self,"scale",scale_original*1.11,0.19/maxf(0.4,speed))
    t.tween_property(self,"modulate",Color(1.0,0.66,0.78,1),0.19/maxf(0.4,speed))
    await t.finished
    var u:=create_tween().set_parallel(true)
    u.tween_property(self,"scale",scale_original,0.33/maxf(0.4,speed))
    u.tween_property(self,"modulate",Color.WHITE,0.33/maxf(0.4,speed))
    await u.finished
