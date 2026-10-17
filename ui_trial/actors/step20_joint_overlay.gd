extends Node2D
## STEP20 inspector-only joint display; no edits to the actor.
var actor: Node2D
var enabled: bool = true
const LINKS: Array = [
    ["torso", "neck"], ["neck", "head"], ["head", "jaw"],
    ["head", "horn_near"], ["head", "horn_far"],
    ["torso", "fore_near"], ["torso", "fore_far"],
    ["torso", "hind_near"], ["torso", "hind_far"],
    ["torso", "tail"]
]
func _process(_delta: float) -> void:
    if enabled: queue_redraw()
func _draw() -> void:
    if not enabled or not is_instance_valid(actor): return
    if not actor._b01_active: return
    for pair in LINKS:
        var a: Node2D = actor._b01_joints.get(pair[0])
        var b: Node2D = actor._b01_joints.get(pair[1])
        if is_instance_valid(a) and is_instance_valid(b):
            draw_line(to_local(a.global_position), to_local(b.global_position), Color(0.4,0.85,1.0,0.65),1.4)
    for name in actor._b01_joints.keys():
        if str(name)=="crimson_aura": continue
        var node: Node2D = actor._b01_joints[name]
        if is_instance_valid(node):
            var p: Vector2 = to_local(node.global_position)
            draw_circle(p,3.8,Color(1.0,0.75,0.2,0.95))
            draw_arc(p,8,0.0,TAU,20,Color(0.0,0.0,0.0,0.82),2.0)
