extends SceneTree
## STEP28 display-layer checks. No save file is written and Battle Core data is not edited.

const LAB_PATH := "res://ui_trial/battle_ui_step21_lab.tscn"
const SIZES := [Vector2i(1280, 900), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(844, 390)]
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("[PASS] ", label)
    else:
        failures.append(label)
        push_error("[FAIL] " + label)

func _settle() -> void:
    for ignored in range(3):
        await process_frame

func _until_idle(view) -> void:
    var started := Time.get_ticks_msec()
    while view.busy and Time.get_ticks_msec() - started < 12000:
        await process_frame
    _check(not view.busy, "battle presentation returns to idle")

func _run() -> void:
    var packed := load(LAB_PATH) as PackedScene
    _check(packed != null, "STEP21 lab scene loads")
    if packed == null:
        _finish()
        return
    root.size = SIZES[0]
    var view = packed.instantiate()
    root.add_child(view)
    await _settle()

    _check(view.hud_panel.size.y <= 80.0, "top HUD is at most 80 logical pixels")
    _check(view.bottom_panel.position.y == 505.0, "bottom UI has stable 720p reference position")
    _check(view.card_buttons.size() == 5, "exactly five reusable card slots")
    _check(view.card_buttons.all(func(card): return card.get_script().resource_path.ends_with("step28_battle_card.gd")), "all hand slots use STEP28 card component")
    _check(view.end_turn_button.name == "EndTurn", "end-turn action remains present")
    _check(view.b01_visual_slot == 0 and view.actors.size() == 1, "R1-B01 articulated actor remains connected")
    _check(is_equal_approx(view.actors[0].scale.x, view.actors[0].scale.y), "boss uses uniform scale")
    _check(is_equal_approx(view.hero.scale.x, view.hero.scale.y), "player uses uniform scale")
    var target_rect := Rect2(view.enemy_buttons[0].position, view.enemy_buttons[0].size)
    _check(target_rect.has_point(view.actors[0].position), "R1-B01 tap target contains displayed actor origin")

    for viewport_size in SIZES:
        root.size = viewport_size
        view.size = Vector2(viewport_size)
        await _settle()
        var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
        var stage_rect: Rect2 = view.stage.get_global_rect()
        var hud_rect: Rect2 = view.hud_panel.get_global_rect()
        var bottom_rect: Rect2 = view.bottom_panel.get_global_rect()
        var bounds := viewport_rect.grow(1.0)
        print("[INFO] viewport=%s stage=%s hud=%s bottom=%s" % [viewport_size, stage_rect, hud_rect, bottom_rect])
        _check(is_equal_approx(view.stage.scale.x, view.stage.scale.y), "%s uniform stage scaling" % viewport_size)
        _check(bounds.encloses(stage_rect), "%s stage stays inside viewport" % viewport_size)
        _check(bounds.encloses(hud_rect), "%s HUD stays inside viewport" % viewport_size)
        _check(bounds.encloses(bottom_rect), "%s bottom UI stays inside viewport" % viewport_size)
        _check(hud_rect.end.y <= bottom_rect.position.y, "%s HUD and card UI do not collide" % viewport_size)
        if viewport_size == Vector2i(1280, 900):
            _check(is_equal_approx(bottom_rect.position.y, 685.0), "1280x900 bottom UI begins at y=685")
            _check(is_equal_approx(bottom_rect.end.y, 900.0), "1280x900 bottom UI reaches viewport bottom")

    root.size = Vector2i(1280, 900)
    await _settle()
    view.battle.hand = view.battle.database.create_deck_from_ids(["C001", "C002", "C003", "C004", "C005", "C006"])
    view.battle.current_mana = 30
    view.card_page = 0
    view._refresh_hud()
    await process_frame
    _check(view.card_buttons.filter(func(card): return card.visible).size() == 5, "first hand page displays five cards")
    _check(not view.hand_next.disabled, "six-card hand enables next page")
    view._switch_page(1)
    await process_frame
    _check(view.card_page == 1, "hand page advances")
    _check(view.card_buttons.filter(func(card): return card.visible).size() == 1, "second hand page displays remaining card")
    view._switch_page(-1)
    await process_frame
    var first_card: Button = view.card_buttons[0]
    var full_text := str(view.battle.hand[0].get("text", ""))
    var first_effect_label := first_card.get("effect_label") as Label
    var first_cost_label := first_card.get("cost_label") as Label
    var first_title_label := first_card.get("title_label") as Label
    _check(first_card.tooltip_text.contains(full_text), "card tooltip preserves full effect text")
    _check(first_effect_label.text == full_text, "card component retains complete effect text")
    _check(not first_cost_label.get_rect().intersects(first_title_label.get_rect()), "cost badge and card name do not overlap")
    var mana_before: int = view.battle.current_mana
    view._card_pressed(0)
    await process_frame
    _check(view.selected_index == 0, "card selection remains available")
    _check(view.battle.current_mana == mana_before, "selection does not spend Mana")
    var first_base_position: Vector2 = first_card.get("base_position")
    _check(first_card.position.y < first_base_position.y, "selected card is lifted")
    _check(view.enemy_buttons[0].get_theme_stylebox("normal").border_width_left == 3, "valid enemy target is highlighted")
    view._clear_selection()
    await process_frame
    _check(is_equal_approx(first_card.position.y, first_base_position.y), "cleared card returns to rest position")

    view.speed = 3.0
    view.battle.hand = view.battle.database.create_deck_from_ids(["C001"])
    view.battle.current_mana = 30
    view._refresh_hud()
    view._card_pressed(0)
    view._enemy_pressed(0)
    await process_frame
    _check(not view.cutin.visible, "normal Attack does not show finisher cut-in")
    await _until_idle(view)

    view.battle.hand = view.battle.database.create_deck_from_ids(["C012"])
    view.battle.current_mana = 30
    view._refresh_hud()
    var uses_before := int(view.battle.playtest_stats.get("cards_used", 0))
    view._card_pressed(0)
    view._enemy_pressed(0)
    await process_frame
    _check(view.cutin.visible, "C012 shows finisher cut-in")
    var portrait := view.cutin.get_node("PortraitClippingFrame") as Control
    _check(not portrait.get_global_rect().intersects(view.cutin_title.get_global_rect()), "finisher art and technique name do not overlap")
    await _until_idle(view)
    _check(not view.cutin.visible, "finisher cut-in closes after animation")
    _check(int(view.battle.playtest_stats.get("cards_used", 0)) == uses_before + 1, "C012 is resolved exactly once")

    view.bind_campaign_battle(view.battle, "boss", Callable(), Callable(), Callable())
    await process_frame
    _check(not view.debug_toolbar.visible, "campaign combat hides development toolbar")
    _finish()

func _finish() -> void:
    print("STEP28 LAYOUT RESULT: PASS=%d FAIL=%d" % [passed, failures.size()])
    if not failures.is_empty():
        print("STEP28 FAILURES: ", failures)
    quit(0 if failures.is_empty() else 1)
