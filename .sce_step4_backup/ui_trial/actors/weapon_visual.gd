extends Node2D
## Six individually recognizable vector weapon silhouettes.
## Draft presentation asset: replace with commissioned transparent sprites later.
const VALID := ["片手剣", "レイピア", "短剣", "大剣", "魔法剣", "刀"]
var weapon_type: String = "片手剣"
var glow: float = 0.0

func set_weapon(value: String) -> void:
    weapon_type = value if value in VALID else "片手剣"
    queue_redraw()

func set_glow(value: float) -> void:
    glow = clampf(value, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    var metal := Color("dae6f4").lerp(Color("fff2be"), glow)
    var edge := Color("71849c")
    var handle := Color("633e36")
    match weapon_type:
        "片手剣":
            _blade([Vector2(-10,-22), Vector2(-9,-124), Vector2(0,-154), Vector2(9,-124), Vector2(10,-22)], metal, edge)
            _grip(handle, 25)
            draw_line(Vector2(-26,-20),Vector2(26,-20),Color("cfb679"),7.0,true)
        "レイピア":
            _blade([Vector2(-2,-20),Vector2(-2,-137),Vector2(0,-179),Vector2(2,-137),Vector2(2,-20)],metal,edge)
            _grip(handle, 23)
            draw_arc(Vector2(1,-22),25,0,PI,16,Color("f4cc86"),5.0,true)
            draw_line(Vector2(-28,-22),Vector2(27,-22),Color("dec995"),4.0,true)
        "短剣":
            _blade([Vector2(-10,-24),Vector2(-13,-68),Vector2(0,-94),Vector2(13,-68),Vector2(10,-24)],metal,edge)
            _grip(handle,20)
            draw_line(Vector2(-23,-24),Vector2(23,-24),Color("bf9e85"),6.0,true)
            draw_line(Vector2(8,0),Vector2(27,-38),Color("95d5e6"),4.0,true)
        "大剣":
            _blade([Vector2(-26,-27),Vector2(-30,-126),Vector2(-15,-144),Vector2(-9,-179),Vector2(0,-199),Vector2(9,-179),Vector2(15,-144),Vector2(30,-126),Vector2(26,-27)],metal,edge)
            _grip(handle,38)
            draw_line(Vector2(-43,-23),Vector2(43,-23),Color("c2aa76"),10.0,true)
            draw_line(Vector2(0,-35),Vector2(0,-166),Color("9aa7ba"),5.0,true)
        "魔法剣":
            _blade([Vector2(-11,-23),Vector2(-15,-111),Vector2(0,-167),Vector2(15,-111),Vector2(11,-23)],metal,Color("699fc9"))
            _grip(handle,26)
            draw_line(Vector2(-24,-23),Vector2(24,-23),Color("5bbdd7"),7.0,true)
            draw_circle(Vector2(0,-65),9,Color("37c9fd"))
            draw_arc(Vector2(0,-74),27,0,TAU,28,Color("65d9ff",0.6),3.0,true)
        "刀":
            var pts := PackedVector2Array([Vector2(-7,4),Vector2(-5,-22),Vector2(-10,-84),Vector2(-2,-144),Vector2(12,-173),Vector2(14,-141),Vector2(7,-78),Vector2(8,-20),Vector2(8,4)])
            draw_colored_polygon(pts,metal)
            draw_polyline(pts,edge,2.5,true)
            _grip(handle,30)
            draw_line(Vector2(-24,-18),Vector2(21,-18),Color("cbb48b"),6.0,true)
    if glow > 0.01:
        draw_arc(Vector2(0,-85),34.0+glow*10.0,0.0,TAU,32,Color(0.52,0.83,1.0,glow*0.75),2.0,true)

func _blade(points: Array, metal: Color, edge: Color) -> void:
    var packed := PackedVector2Array(points)
    draw_colored_polygon(packed,metal)
    draw_polyline(packed,edge,2.5,true)

func _grip(color: Color, length: int) -> void:
    draw_line(Vector2(0,-17),Vector2(0,length),color,10.0,true)
    draw_circle(Vector2(0,float(length)),7.0,Color("cfb77f"))
