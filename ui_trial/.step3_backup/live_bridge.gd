extends Control
## STEP2: battle-visual-only playback dock. No BattleController reference and no game writes.
const HERO_SCRIPT = preload("res://ui_trial/actors/actor3h.gd")
const MOB_SCRIPT = preload("res://ui_trial/actors/mob_chibi.gd")
const BACKGROUND = preload("res://ui_trial/assets/battle_background.webp")
const CUTIN = preload("res://ui_trial/assets/cutin_temp.webp")
const MAX_QUEUE := 12

var hero
var mob
var info_label: Label
var hit_label: Label
var cutin_box: Control
var title_label: Label
var queued: Array[Dictionary] = []
var _playing: bool = false
var _generation: int = 0
var _active_action: Dictionary = {}
var _speed: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(0, 172)
    clip_contents = true
    var bg := TextureRect.new()
    bg.texture = BACKGROUND
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.modulate = Color(0.65, 0.70, 0.82, 1.0)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    var tint := ColorRect.new()
    tint.color = Color(0.035, 0.045, 0.080, 0.30)
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(tint)

    hero = Node2D.new()
    hero.set_script(HERO_SCRIPT)
    hero.position = Vector2(145, 148)
    hero.scale = Vector2(0.36, 0.36)
    add_child(hero)
    hero.impact_frame.connect(_on_hero_impact)

    mob = Node2D.new()
    mob.set_script(MOB_SCRIPT)
    mob.position = Vector2(395, 148)
    mob.scale = Vector2(0.48, 0.48)
    add_child(mob)

    info_label = Label.new()
    info_label.position = Vector2(12, 5)
    info_label.size = Vector2(650, 24)
    info_label.text = "3頭身 LIVE PREVIEW  |  カード使用時に連動"
    info_label.add_theme_font_size_override("font_size", 13)
    info_label.add_theme_color_override("font_color", Color("f1ddc6"))
    info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(info_label)

    hit_label = Label.new()
    hit_label.text = ""
    hit_label.position = Vector2(360, 42)
    hit_label.size = Vector2(160, 35)
    hit_label.add_theme_font_size_override("font_size", 20)
    hit_label.add_theme_color_override("font_color", Color("ffe0a2"))
    hit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hit_label)

    cutin_box = Control.new()
    cutin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin_box.position = Vector2(-270, 27)
    cutin_box.size = Vector2(260, 125)
    cutin_box.modulate.a = 0.0
    add_child(cutin_box)
    var image := TextureRect.new()
    image.texture = CUTIN
    image.size = Vector2(250, 113)
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin_box.add_child(image)
    title_label = Label.new()
    title_label.position = Vector2(9, 91)
    title_label.size = Vector2(244, 28)
    title_label.add_theme_font_size_override("font_size", 15)
    title_label.add_theme_color_override("font_color", Color("ffe9c4"))
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cutin_box.add_child(title_label)
    resized.connect(_position_actors)
    _position_actors()

func _position_actors() -> void:
    if hero == null or mob == null or not is_instance_valid(hero) or not is_instance_valid(mob):
        return
    if _playing:
        return
    var width := maxf(340.0, size.x)
    var floor_y := maxf(146.0, size.y - 13.0)
    hero.set_rest_position(Vector2(clampf(width * 0.24, 125.0, 205.0), floor_y))
    mob.set_rest_position(Vector2(width * 0.76, floor_y))
    if hit_label != null:
        hit_label.position = Vector2(width * 0.76 - 65.0, 35.0)

func reset_display() -> void:
    queued.clear()
    _generation += 1
    # Existing motions may complete on their own. Never interrupt game logic.
    if is_instance_valid(info_label):
        info_label.text = "3頭身 LIVE PREVIEW  |  待機中"
    if is_instance_valid(hit_label):
        hit_label.text = ""
    if is_instance_valid(cutin_box):
        cutin_box.modulate.a = 0.0

func queue_card(card: Dictionary, events: Array, target_index: int, speed: float = 1.0, quality: int = 2) -> void:
    if quality <= 0:
        return
    # Events are already resolved by BattleController; never calculate damage from card text.
    var hits: int = 0
    var block_hits: int = 0
    var hit_count: int = 0
    for raw in events:
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        if str(raw.get("kind", "")) == "enemy_hit":
            hits += maxi(0, int(raw.get("hp_loss", 0)))
            block_hits += maxi(0, int(raw.get("block_loss", 0)))
            hit_count += 1
    _append_action({
        "kind": "card", "card_type": str(card.get("card_type", "skill")),
        "role": str(card.get("role", "")), "weapon": str(card.get("weapon", "")),
        "attribute": str(card.get("attribute", "")), "name": _card_name(card),
        "damage": hits, "block": block_hits, "hit_count": hit_count,
        "target": target_index, "speed": maxf(1.0, speed)
    })

func queue_enemy_turn(events: Array, speed: float = 1.0, quality: int = 2) -> void:
    if quality <= 0:
        return
    var actions: int = 0
    var hp_loss: int = 0
    var block_loss: int = 0
    for raw in events:
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        match str(raw.get("kind", "")):
            "enemy_action": actions += 1
            "player_hit":
                hp_loss += maxi(0, int(raw.get("hp_loss", 0)))
                block_loss += maxi(0, int(raw.get("block_loss", 0)))
    if actions > 0:
        _append_action({"kind":"enemy", "damage":hp_loss, "block":block_loss, "actions":actions, "speed":maxf(1.0,speed)})

func _append_action(action: Dictionary) -> void:
    if queued.size() >= MAX_QUEUE:
        queued.pop_front() # Visual playback only; never skip or alter a battle action.
    queued.append(action.duplicate(true))
    if not _playing:
        _playing = true
        call_deferred("_drain_queue")

func _card_name(card: Dictionary) -> String:
    var name := str(card.get("display_name", ""))
    if name.contains(" / "):
        name = name.split(" / ", false, 1)[-1]
    return name if name != "" else str(card.get("id", "CARD"))

func _drain_queue() -> void:
    while not queued.is_empty():
        _active_action = queued.pop_front()
        _speed = float(_active_action.get("speed", 1.0))
        if str(_active_action.get("kind", "")) == "card":
            await _animate_card(_active_action)
        else:
            await _animate_enemy(_active_action)
    _active_action.clear()
    _playing = false
    _position_actors()

func _animate_card(action: Dictionary) -> void:
    var finisher := str(action.get("role", "")) == "決着技"
    var name := str(action.get("name", "CARD"))
    info_label.text = "%s / %s / %s" % [name, str(action.get("weapon", "")), str(action.get("attribute", ""))]
    title_label.text = name
    cutin_box.position = Vector2(-260, 27)
    cutin_box.modulate.a = 0.0
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(cutin_box, "position", Vector2(8, 27), (0.26 if finisher else 0.13) / _speed)
    tween.tween_property(cutin_box, "modulate:a", 0.88 if finisher else 0.75, (0.22 if finisher else 0.11) / _speed)
    await tween.finished
    var fade := create_tween()
    fade.tween_property(cutin_box, "modulate:a", 0.0, (0.17 if finisher else 0.10) / _speed)
    # Animation is strictly cosmetic; on_impact displays pre-resolved result.
    hit_label.text = ""
    if str(action.get("card_type", "")) == "attack":
        await hero.play_attack(finisher, _speed * 1.6)
    else:
        await hero.play_cast(_speed * 1.6)
        if int(action.get("hit_count", 0)) > 0:
            _show_impact(action)
    info_label.text = "3頭身 LIVE PREVIEW  |  待機中"

func _on_hero_impact() -> void:
    if str(_active_action.get("kind", "")) == "card":
        _show_impact(_active_action)

func _show_impact(action: Dictionary) -> void:
    if int(action.get("hit_count", 0)) <= 0:
        return
    if int(action.get("damage", 0)) > 0:
        hit_label.text = "%d HP" % int(action.get("damage", 0))
    elif int(action.get("block", 0)) > 0:
        hit_label.text = "%d Block" % int(action.get("block", 0))
    else:
        hit_label.text = "HIT"
    mob.play_hit(_speed)
    var anim := create_tween()
    anim.tween_property(hit_label, "modulate:a", 1.0, 0.01)
    anim.tween_interval(0.19 / _speed)
    anim.tween_property(hit_label, "modulate:a", 0.0, 0.15 / _speed)

func _animate_enemy(action: Dictionary) -> void:
    info_label.text = "ENEMY TURN / 既存Intentの結果を再生"
    var hp_loss := int(action.get("damage", 0))
    var block_loss := int(action.get("block", 0))
    if hp_loss > 0 or block_loss > 0:
        await hero.play_hit(_speed * 1.5)
        hit_label.modulate.a = 1.0
        hit_label.text = "−%d HP" % hp_loss if hp_loss > 0 else "−%d Block" % block_loss
    else:
        await get_tree().create_timer(0.11 / _speed).timeout
    info_label.text = "3頭身 LIVE PREVIEW  |  待機中"
