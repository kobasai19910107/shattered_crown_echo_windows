extends Node2D
## Additive, deterministic, shader-free 2D effect reused by 10 attributes.
## No RNG from BattleController, no state writes, no combat side effects.
const TONES := {
    "物理": Color("eadcc4"), "炎": Color("ff774b"),
    "水": Color("75dcff"), "雷": Color("b6aaff"),
    "地": Color("d1ae73"), "光": Color("ffeb97"),
    "闇": Color("ad70d8"), "毒": Color("78d88f"),
    "秘術": Color("64bcff"), "風": Color("82f0c7")
}
var attribute: String = "物理"
var age: float = 0.0
var duration: float = 0.48
var strength: float = 1.0
var quality: int = 2
var running: bool = false

func play(value: String, finisher: bool = false, fx_quality: int = 2, speed: float = 1.0) -> void:
    attribute = value if TONES.has(value) else "物理"
    quality = clampi(fx_quality,0,2)
    age = 0.0
    duration = (0.72 if finisher else 0.43) / maxf(0.2,speed)
    strength = 1.5 if finisher else 1.0
    running = quality > 0
    visible = running
    queue_redraw()

func clear_effect() -> void:
    running = false
    visible = false
    queue_redraw()

func _process(delta: float) -> void:
    if not running: return
    age += delta
    if age >= duration:
        clear_effect()
        return
    queue_redraw()

func _draw() -> void:
    if not running or duration <= 0.0: return
    var t: float = clampf(age / duration,0.0,1.0)
    var opacity: float = (1.0-t) * (0.7 if quality == 1 else 1.0)
    var color: Color = TONES[attribute]
    color.a = opacity
    var radius: float = (15.0 + 65.0*t) * strength
    match attribute:
        "物理":
            _slash(color,radius,0.0)
        "炎":
            _rays(color,radius,7)
            _dots(color,radius,4)
        "水":
            _rings(color,radius,2)
            _dots(color,radius,5)
        "雷":
            _lightning(color,radius)
        "地":
            for i in range(4):
                var angle: float = TAU*float(i)/4.0+0.35
                var p := Vector2(cos(angle),sin(angle))*radius
                draw_line(p*0.45,p*1.15,color,7.0*strength,true)
        "光":
            _rays(color,radius,8)
            _rings(color,radius*0.55,1)
        "闇":
            _rings(color,radius*0.9,2)
            _rays(color,radius*0.7,5)
        "毒":
            _dots(color,radius,9)
            _rings(color,radius*0.4,1)
        "秘術":
            _rings(color,radius,2)
            for i in range(3):
                var a: float = TAU * float(i)/3.0
                draw_line(Vector2.ZERO,Vector2(cos(a),sin(a))*radius,color,2.0,true)
        "風":
            for i in range(3):
                draw_arc(Vector2(-radius*0.1,float(i-1)*14.0),radius*(0.5+i*0.22),-0.6,1.1,18,color,3.0*strength,true)
    draw_circle(Vector2.ZERO,7.0*(1.0-t)*strength,Color(color.r,color.g,color.b,opacity*0.8))

func _slash(color: Color, radius: float, tilt: float) -> void:
    var from: Vector2 = Vector2(-radius,-radius*0.3).rotated(tilt)
    var to: Vector2 = Vector2(radius,radius*0.3).rotated(tilt)
    draw_line(from,to,color,7.0*strength,true)
    draw_line(from+Vector2(0,-9),to+Vector2(0,-9),Color(color.r,color.g,color.b,color.a*0.5),2.0,true)

func _rays(color: Color, radius: float, count: int) -> void:
    for i in range(count):
        var a: float = TAU*float(i)/float(count)
        var axis := Vector2(cos(a),sin(a))
        draw_line(axis*radius*0.45,axis*radius,color,3.0*strength,true)

func _rings(color: Color, radius: float, count: int) -> void:
    for i in range(count):
        draw_arc(Vector2.ZERO,radius*(0.75+float(i)*0.24),0.0,TAU,28,color,2.0*strength,true)

func _dots(color: Color, radius: float, count: int) -> void:
    for i in range(count):
        var a: float = TAU * float(i)/float(count)+0.25
        draw_circle(Vector2(cos(a),sin(a))*radius*(0.45+0.15*float(i%3)),3.0*strength,color)

func _lightning(color: Color, radius: float) -> void:
    var vertices := PackedVector2Array([
        Vector2(-radius,-radius*0.5),Vector2(-radius*0.2,-radius*0.1),
        Vector2(-radius*0.45,radius*0.25),Vector2(radius*0.4,radius*0.6),
        Vector2(radius*0.1,radius*0.12),Vector2(radius,-radius*0.2)
    ])
    draw_polyline(vertices,color,5.0*strength,true)
