class_name BattlePresentation
extends Control

static var quality: int=2 # 0 OFF / 1 lightweight / 2 normal; local presentation only.
var speed_multiplier: float = 1.0 # Presentation timing only. Never scales battle delta or logic.
var pending_events: Array=[]
var timeline: Array=[]
var last_events: Array=[]
var event_delay: float=0
var tracked_tweens: Array[Tween]=[]
var flashed: Array=[]
var strikes: Array = []
var popup_anchors: Dictionary={}

func capture(event: Dictionary) -> void:
    if pending_events.size()<256:pending_events.append(event.duplicate(true))

func clear_effects() -> void:
    for tween in tracked_tweens:
        if tween.is_valid():tween.kill()
    tracked_tweens.clear()
    for record in flashed:
        var node=record.node.get_ref()
        if is_instance_valid(node):node.material=record.material;node.modulate=record.modulate
        if is_instance_valid(node) and node is Control:node.position=record.position
    flashed.clear()
    for child in get_children():remove_child(child);child.queue_free()
    drag_ghost=null;active_popups=0;popup_anchors.clear();strikes.clear();timeline.clear();pending_events.clear();queue_redraw()

func glyph(attribute: String,point: Vector2,strong: bool=false,color: Color=Color.TRANSPARENT) -> void:
    if quality==0 or get_child_count()>40:return
    var name: String={"爆発":"炎","鈍化":"水","帯電":"雷","呪印":"闇","猛毒":"毒","魔珠":"秘術","疾風":"風","堅牢":"地","恩寵":"光","剛力":"物理"}.get(attribute,attribute)
    var effect=BattleVFXGlyph.new();effect.position=point;effect.duration=0.42 / maxf(1.0,speed_multiplier);add_child(effect);effect.build(name,HubCardView.tone(name) if color==Color.TRANSPARENT else color,strong,quality==1)

func weapon_glyph(weapon: String, point: Vector2, finisher: bool = false) -> void:
    if quality == 0 or get_child_count() > 40: return
    if weapon not in ["片手剣", "レイピア", "短剣", "大剣", "魔法剣", "刀"]: return
    var effect := BattleVFXGlyph.new()
    effect.position = point
    effect.duration = (0.52 if finisher else 0.3) / maxf(1.0, speed_multiplier)
    add_child(effect)
    effect.build("武器:" + weapon, Color("ffd8ac") if finisher else Color("f1e5f9"), finisher, quality == 1)

func flash(control: Control) -> void:
    if quality==0 or not is_instance_valid(control):return
    var surface: CanvasItem=control.get_node_or_null("MonsterVisual/Portrait")
    if surface==null:surface=control
    for record in flashed:
        if record.node.get_ref()==surface:return
    var original_material=surface.material;var original_modulate: Color=surface.modulate
    var record={"node":weakref(surface),"material":original_material,"modulate":original_modulate,"position":surface.position if surface is Control else Vector2.ZERO}
    flashed.append(record)
    var material=ShaderMaterial.new();material.shader=load("res://assets/shaders/battle_flash.gdshader");surface.material=material
    var tween=create_tween();tracked_tweens.append(tween)
    tween.tween_method(func(value: float):material.set_shader_parameter("flash_amount",value),0.85,0.0,0.16 / maxf(1.0,speed_multiplier))
    if surface is Control:
        var shake=create_tween();tracked_tweens.append(shake)
        shake.tween_property(surface,"position",record.position+Vector2(4,0),0.035 / maxf(1.0,speed_multiplier))
        shake.tween_property(surface,"position",record.position-Vector2(3,0),0.035 / maxf(1.0,speed_multiplier))
        shake.tween_property(surface,"position",record.position,0.035 / maxf(1.0,speed_multiplier))
    tween.finished.connect(func():
        var node=record.node.get_ref()
        if is_instance_valid(node):node.material=record.material;node.modulate=record.modulate
        if is_instance_valid(node) and node is Control:node.position=record.position
        flashed.erase(record))

func play_event(event: Dictionary) -> void:
    var point: Vector2=event.point
    match str(event.kind):
        "enemy_hit","player_hit":
            if int(event.hp_loss)>0:_popup("−%d HP"%int(event.hp_loss),point,Color("ffb19c"))
            if int(event.block_loss)>0:_popup("◆ −%d Block"%int(event.block_loss),point+Vector2(0,28),Color("90d7ff"))
            glyph(str(event.get("attribute","物理")),point)
            if int(event.block_loss)>0:glyph("バリア",point,false,Color("90d7ff"))
            strikes.append({"origin":event.get("source",point),"target":point,"color":HubCardView.tone(str(event.get("attribute","物理"))),"age":0.0})
            var target=event.get("target")
            if target is WeakRef:
                var node=target.get_ref()
                if is_instance_valid(node):flash(node)
        "resource":
            var resource: String=str(event.resource)
            var label: String={"healing_done":"HP","mana_gained":"Mana","block_gained":"Block"}.get(resource,resource)
            var color: Color=Color("91e5ac") if resource=="healing_done" else Color("90d7ff")
            _popup("+%d %s"%[int(event.amount),label],point,color)
            glyph("光" if resource=="healing_done" else ("バリア" if resource=="block_gained" else "秘術"),point,false,color)
        "execution":
            _popup("処刑成立",point,Color("ffd17c"));glyph("処刑",point,true)
        "defeat":_popup("撃破",point,Color("ffd17c"))
        "enemy_action":
            _popup("▶ "+str(event.get("intent",event.action)),point+Vector2(0,-25),Color("ffd17c"))
            var target=event.get("target")
            if target is WeakRef:
                var node=target.get_ref()
                if is_instance_valid(node):flash(node)
        "draw","discard","bottom":
            card_flight(str(event.id),Rect2(event.source,Vector2(45,65)),point,false)

func queue_events(events: Array,enemy_points: Array,player_point: Vector2,source: Vector2,targets: Array=[],piles: Dictionary={}) -> void:
    var attacking_enemy: int=-1
    for raw in events:
        if str(raw.kind)=="enemy_action":attacking_enemy=int(raw.enemy)
        if str(raw.kind) not in ["enemy_hit","player_hit","enemy_action","draw","discard","bottom","execution","resource"]:continue
        var event: Dictionary=raw.duplicate(true);event.source=source;event.point=player_point
        if str(raw.kind) in ["enemy_hit","enemy_action","execution"]:
            var index: int=int(raw.enemy)
            event.point=enemy_points[index] if index<enemy_points.size() else source
            if index<targets.size():event.target=weakref(targets[index])
        if str(raw.kind)=="player_hit" and attacking_enemy>=0 and attacking_enemy<enemy_points.size():event.source=enemy_points[attacking_enemy]
        if str(raw.kind)=="draw":event.source=piles.get("draw",player_point);event.point=source
        elif str(raw.kind) in ["discard","bottom"]:event.point=piles.get("draw" if str(raw.kind)=="bottom" else "discard",player_point)
        if timeline.size()<128:timeline.append(event)
    if not timeline.is_empty() and quality>0:
        play_event(timeline.pop_front());event_delay=0.035 / maxf(1.0, speed_multiplier)
var active_popups: int = 0
var drag_ghost: PanelContainer

func start_drag(card: Dictionary, cost: int, rect: Rect2) -> void:
    stop_drag()
    drag_ghost = PanelContainer.new()
    drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    drag_ghost.size = rect.size
    drag_ghost.position = rect.position
    drag_ghost.modulate = Color(1,1,1,0.85)
    var style = StyleBoxFlat.new()
    style.bg_color = Color("26364a")
    style.border_color = Color("ffe59b")
    style.set_border_width_all(3)
    style.set_corner_radius_all(12)
    drag_ghost.add_theme_stylebox_override("panel",style)
    var label = Label.new()
    label.text = "%s · Mana%d\n基礎ダメージ %d\n基礎Block %d" % [str(card.id),cost,int(card.get("base_damage",0)),int(card.get("base_block",0))]
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size",17)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    drag_ghost.add_child(label)
    add_child(drag_ghost)

func move_drag(point: Vector2) -> void:
    if is_instance_valid(drag_ghost): drag_ghost.position = point-drag_ghost.size*0.5

func stop_drag() -> void:
    if is_instance_valid(drag_ghost):
        remove_child(drag_ghost)
        drag_ghost.queue_free()
    drag_ghost = null

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 20

func _process(delta: float) -> void:
    tracked_tweens=tracked_tweens.filter(func(tween):return tween.is_valid() and tween.is_running())
    flashed=flashed.filter(func(record):return record.node.get_ref()!=null)
    event_delay-=delta
    if not timeline.is_empty() and event_delay<=0:
        if quality>0:play_event(timeline.pop_front())
        else:timeline.clear()
        event_delay=0.035 / maxf(1.0, speed_multiplier)
    var had_strikes: bool = not strikes.is_empty()
    for i in range(strikes.size()-1,-1,-1):
        strikes[i].age += delta * maxf(1.0,speed_multiplier)
        if float(strikes[i].age) >= 0.45: strikes.remove_at(i)
    if had_strikes: queue_redraw()

func _draw() -> void:
    for strike in strikes:
        var fade: float = 1.0-float(strike.age)/0.45
        var origin: Vector2 = strike.origin
        var target: Vector2 = strike.target
        var color: Color = strike.color
        color.a = fade*0.22
        draw_line(origin,target,color,12.0,true)
        color.a = fade*0.8
        draw_line(target+Vector2(-25,24),target+Vector2(25,-24),color,3.0,true)
        draw_arc(target,12.0+(1.0-fade)*34.0,0,TAU,32,color,2.0,true)
        for i in range(8):
            var offset = Vector2.from_angle(float(i)*TAU/8)*(12.0+(1.0-fade)*40)
            draw_circle(target+offset,2.0,color)

func _popup(value: String, point: Vector2, color: Color) -> void:
    if quality==0 or active_popups>=24:return
    var key: int=floori(point.x/180)
    var now: int=Time.get_ticks_msec()
    var anchor: Dictionary=popup_anchors.get(key,{"until":0,"lane":0,"base_y":point.y})
    if now>int(anchor.until):anchor.lane=0;anchor.base_y=point.y
    point.y=float(anchor.base_y)+float(int(anchor.lane)%8)*27
    anchor.lane=int(anchor.lane)+1;anchor.until=now+900;popup_anchors[key]=anchor
    var label = Label.new()
    label.text = value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.position = point-Vector2(45,15)
    label.add_theme_font_size_override("font_size",19)
    label.add_theme_color_override("font_color",color)
    label.add_theme_color_override("font_outline_color",Color("0b101b"))
    label.add_theme_constant_override("outline_size",5)
    add_child(label)
    active_popups += 1
    var tween = create_tween().set_parallel(true)
    tracked_tweens.append(tween)
    tween.tween_property(label,"position:y",label.position.y-55,0.7 / maxf(1.0,speed_multiplier)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(label,"modulate:a",0.0,0.7 / maxf(1.0,speed_multiplier)).set_delay(0.15 / maxf(1.0,speed_multiplier))
    tween.finished.connect(func(): active_popups = maxi(0,active_popups-1); label.queue_free())

func card_flight(card_id: String, source: Rect2, target: Vector2, attack: bool) -> void:
    if quality==0 or get_child_count()>40:return
    var ghost = PanelContainer.new()
    ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ghost.position = source.position
    ghost.size = source.size
    var style = StyleBoxFlat.new()
    style.bg_color = Color("26364a")
    style.border_color = Color("ffb19c") if attack else Color("90d7ff")
    style.set_border_width_all(3)
    style.set_corner_radius_all(12)
    ghost.add_theme_stylebox_override("panel",style)
    var label = Label.new()
    label.text = card_id
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size",24)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ghost.add_child(label)
    add_child(ghost)
    var tween = create_tween().set_parallel(true)
    tracked_tweens.append(tween)
    tween.tween_property(ghost,"position",target-source.size*0.3,0.3 / maxf(1.0,speed_multiplier)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(ghost,"scale",Vector2(0.6,0.6),0.3 / maxf(1.0,speed_multiplier))
    tween.tween_property(ghost,"modulate:a",0.0,0.3 / maxf(1.0,speed_multiplier))
    tween.finished.connect(ghost.queue_free)

func show_changes(before: Dictionary, after: Dictionary, enemy_points: Array, player_point: Vector2, source: Vector2, targets: Array=[],piles: Dictionary={}) -> void:
    last_events=pending_events.duplicate(true);pending_events.clear()
    if quality==0:return
    queue_events(last_events,enemy_points,player_point,source,targets,piles)
    var gains: Dictionary={"healing_done":0,"block_gained":0,"mana_gained":0}
    var losses: Dictionary={};var absorbed: Dictionary={};var player_loss: int=0;var player_absorbed: int=0
    for event in last_events:
        if str(event.kind)=="enemy_hit":
            losses[int(event.enemy)]=int(losses.get(int(event.enemy),0))+int(event.hp_loss)
            absorbed[int(event.enemy)]=int(absorbed.get(int(event.enemy),0))+int(event.block_loss)
        elif str(event.kind)=="execution":
            losses[int(event.enemy)]=int(losses.get(int(event.enemy),0))+int(event.hp_loss)
        elif str(event.kind)=="resource":gains[str(event.resource)]+=int(event.amount)
        elif str(event.kind)=="player_hit":
            player_loss+=int(event.hp_loss);player_absorbed+=int(event.block_loss)
        elif str(event.kind)=="log":
            var message: String=str(event.message)
            if message.contains("Iai Cost0 confirmed"):_popup("居合",source,Color("ffd17c"));glyph("居合",source,true)
            elif message.contains("ON consumed"):_popup(message.split("ON consumed")[0]+" 発動",player_point+Vector2(0,-45),Color("ffd17c"))
    for i in range(mini(before.enemies.size(),after.enemies.size())):
        var point: Vector2=enemy_points[i] if i<enemy_points.size() else source
        var old: Dictionary=before.enemies[i];var current: Dictionary=after.enemies[i]
        var phase_changed: bool=int(old.get("phase_index",0))!=int(current.get("phase_index",0))
        var hp_change: int=int(current.hp)-int(old.hp)+int(losses.get(i,0))
        if phase_changed:_popup("Phase "+str(int(current.phase_index)+1),point,Color("ffd17c"))
        elif hp_change!=0:
            _popup("%+d HP"%hp_change,point,Color("91e5ac") if hp_change>0 else Color("ffb19c"))
            glyph("光" if hp_change>0 else "物理",point)
            if hp_change<0 and i<targets.size():flash(targets[i])
        var block_change: int=int(current.block)-int(old.block)+int(absorbed.get(i,0))
        if block_change!=0:_popup("◆ %+d Block"%block_change,point+Vector2(0,30),Color("90d7ff"));glyph("水",point)
        if int(current.hp)<=0 and int(old.hp)>0:timeline.append({"kind":"defeat","point":point+Vector2(0,-35)})
        trait_changes(old.get("attribute_traits",{}),current.get("attribute_traits",{}),point)
        status_changes(old.get("r1_status",{}),current.get("r1_status",{}),point)
    var hp: int=int(after.hp)-int(before.hp)+player_loss-int(gains.healing_done)
    var block: int=int(after.block)-int(before.block)+player_absorbed-int(gains.block_gained)
    var mana: int=int(after.mana)-int(before.mana)-int(gains.mana_gained)
    if hp!=0:_popup("%+d HP"%hp,player_point,Color("91e5ac") if hp>0 else Color("ff8d88"));glyph("光" if hp>0 else "闇",player_point)
    if block!=0:_popup("◆ %+d Block"%block,player_point+Vector2(0,30),Color("90d7ff"));glyph("バリア",player_point,false,Color("90d7ff"))
    if mana!=0:_popup("%+d Mana"%mana,player_point+Vector2(0,60),Color("b2b0ff"));glyph("秘術",player_point)
    for key in after.get("weapon_traits",{}):
        var old_on: bool=bool(before.get("weapon_traits",{}).get(key,false));var on: bool=bool(after.weapon_traits[key])
        if on!=old_on:
            _popup(str(key)+(" ON / SET" if on else " OFF"),player_point+Vector2(0,-30),Color("ffd17c") if on else Color("b8a7ce"))
            if on:glyph("秘術",player_point,true)
    trait_changes(before.get("attribute_traits",{}),after.get("attribute_traits",{}),player_point)
    status_changes(before.get("status",{}),after.get("status",{}),player_point)
    queue_redraw()

func trait_changes(before: Dictionary,after: Dictionary,point: Vector2) -> void:
    for key in after:
        var old: int=int(before.get(key,0));var value: int=int(after[key])
        if value==old:continue
        var threshold: bool=value>old and floori(value/3.0)>floori(old/3.0)
        _popup("%s %+d → %d%s"%[key,value-old,value," / 閾値到達" if threshold else ""],point+Vector2(0,-50),HubCardView.tone({"剛力":"物理","爆発":"炎","鈍化":"水","帯電":"雷","堅牢":"地","恩寵":"光","呪印":"闇","猛毒":"毒","魔珠":"秘術","疾風":"風"}.get(key,"秘術")))
        glyph(str(key),point,threshold)

func status_changes(before: Dictionary,after: Dictionary,point: Vector2) -> void:
    for key in after:
        if after[key] is int or after[key] is float:
            var delta: int=int(after[key])-int(before.get(key,0))
            if delta!=0:_popup("%s %+d"%[key,delta],point+Vector2(0,90),Color("c4a2f4"))

