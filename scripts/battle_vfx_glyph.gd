class_name BattleVFXGlyph
extends Node2D

var attribute: String="物理"
var age: float=0
var strong: bool=false
var duration: float=0.42

func build(kind: String,color: Color,heavy: bool,light: bool) -> void:
    attribute=kind;strong=heavy;modulate=color
    var player=AnimationPlayer.new();add_child(player)
    var library=AnimationLibrary.new();var animation=Animation.new();animation.length=duration
    var track=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(track,NodePath(".:modulate:a"));animation.track_insert_key(track,0,1.0);animation.track_insert_key(track,duration,0.0)
    library.add_animation("burst",animation);player.add_animation_library("",library);player.play("burst")
    if not light:
        var particles=CPUParticles2D.new();particles.one_shot=true;particles.amount=12 if not strong else 20;particles.lifetime=minf(0.3,duration);particles.explosiveness=1.0;particles.direction=Vector2.UP;particles.spread=180;particles.initial_velocity_min=25;particles.initial_velocity_max=80;particles.gravity=Vector2(0,40);particles.color=color;particles.scale_amount_min=1.5;particles.scale_amount_max=3;add_child(particles);particles.emitting=true

func _process(delta: float) -> void:
    age+=delta;queue_redraw()
    if age>=duration:queue_free()

func _draw() -> void:
    var radius: float=12+age*95
    var width: float=3 if strong else 2
    match attribute:
        "武器:片手剣":
            draw_line(Vector2(-radius,-radius),Vector2(radius,radius),Color.WHITE,width+2,true)
            draw_arc(Vector2.ZERO,radius,-2.3,0.5,22,Color.WHITE,width,true)
        "武器:レイピア":
            for offset in [-5.0, 0.0, 5.0]:
                draw_line(Vector2(-radius*1.3,offset),Vector2(radius*1.3,offset),Color.WHITE,width,true)
            draw_circle(Vector2(radius*1.3,0),4,Color.WHITE)
        "武器:短剣":
            for offset in [-12.0, 0.0, 12.0]:
                draw_line(Vector2(-radius,offset+10),Vector2(radius,offset-10),Color.WHITE,width,true)
        "武器:大剣":
            draw_arc(Vector2.ZERO,radius*1.3,-2.7,0.7,30,Color.WHITE,width+5,true)
            draw_line(Vector2(-radius*1.4,radius),Vector2(radius*1.4,-radius),Color.WHITE,width+3,true)
        "武器:魔法剣":
            draw_arc(Vector2.ZERO,radius*0.85,0,TAU,32,Color.WHITE,width,true)
            draw_line(Vector2(-radius,0),Vector2(radius,0),Color.WHITE,width+2,true)
            draw_line(Vector2(0,-radius),Vector2(0,radius),Color.WHITE,width+2,true)
        "武器:刀":
            draw_line(Vector2(-radius*1.8,10),Vector2(radius*1.8,-10),Color.WHITE,width+3,true)
            draw_line(Vector2(-radius*1.8,14),Vector2(radius*1.8,-6),Color.WHITE,width,true)
        "物理","居合":
            draw_line(Vector2(-radius,radius*0.4),Vector2(radius,-radius*0.4),Color.WHITE,width+2,true)
            if attribute=="居合":draw_line(Vector2(-radius*2,0),Vector2(radius*2,0),Color.WHITE,5,true)
        "雷":
            draw_polyline(PackedVector2Array([Vector2(-30,-30),Vector2(5,-12),Vector2(-5,10),Vector2(30,30)]),Color.WHITE,width,true)
        "バリア":
            var shield=PackedVector2Array([Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(radius,radius*0.3),Vector2(0,radius),Vector2(-radius,radius*0.3),Vector2(-radius,-radius)])
            draw_polyline(shield,Color.WHITE,width+1,true)
        "地":
            for i in range(5):draw_rect(Rect2(Vector2(i*12-30,-radius*0.4),Vector2(8,16)),Color.WHITE,false,width)
        "風":
            for i in range(3):draw_arc(Vector2(i*7,0),radius+i*6,-1.0,1.5,24,Color.WHITE,width,true)
        "闇","処刑":
            draw_circle(Vector2.ZERO,radius*0.7,Color(1,1,1,0.12))
            draw_arc(Vector2.ZERO,radius*0.8,0,TAU,32,Color.WHITE,width,true)
            draw_line(Vector2(-18,-18),Vector2(18,18),Color.WHITE,width,true);draw_line(Vector2(-18,18),Vector2(18,-18),Color.WHITE,width,true)
        "毒":
            for i in range(5):draw_circle(Vector2.from_angle(i*TAU/5)*radius*0.5,9+age*6,Color(1,1,1,0.3))
        "秘術":
            draw_arc(Vector2.ZERO,radius,0,TAU,32,Color.WHITE,width,true)
            var points=PackedVector2Array()
            for i in range(7):points.append(Vector2.from_angle(i*TAU/6)*radius*0.7)
            draw_polyline(points,Color.WHITE,width,true)
        "炎":
            for i in range(8):draw_line(Vector2.from_angle(i*TAU/8)*radius*0.3,Vector2.from_angle(i*TAU/8)*radius,Color.WHITE,width,true)
        _:
            draw_arc(Vector2.ZERO,radius,0,TAU,32,Color.WHITE,width,true)
            if attribute=="光":draw_arc(Vector2.ZERO,radius*0.6,0,TAU,32,Color.WHITE,width,true)
