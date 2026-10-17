extends SceneTree

# Run with: godot --headless --path . --script res://tests/combat_ux_smoke_test.gd
# Does not write any user save or preferences file.
var checks: int = 0
var failures: int = 0

func _test(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("COMBAT UX FAIL: " + description)
    else:
        print("COMBAT UX PASS: " + description)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var prefs = load("res://scripts/battle_ux_preferences.gd").new()
    _test(prefs.speed == 1 and prefs.vfx_quality == 2, "new preferences defaults")
    var audio = load("res://scripts/battle_ui_audio.gd").new()
    root.add_child(audio)
    audio.set_levels(0.0, 0.0, 0.0)
    audio.play_cue("select")
    _test(audio._players.size() == 6, "audio players initialized, silent mode")
    var tone = audio._make_tone("hit")
    _test(tone is AudioStreamWAV and not tone.data.is_empty(), "procedural audio stream")
    var presentation = load("res://scripts/battle_presentation.gd").new()
    root.add_child(presentation)
    presentation.speed_multiplier = 3.0
    presentation.weapon_glyph("刀", Vector2(100, 100), true)
    _test(presentation.get_child_count() > 0, "separate weapon FX node")
    var cards = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards_master.json"))
    _test(cards is Dictionary and int(cards.get("card_count", 0)) == 120, "formal 120 cards unchanged")
    var first_card: Dictionary = cards.get("cards", {}).get("C001", {})
    var button = load("res://scripts/playtest_card_button.gd").new()
    button.hand_index = 0
    button.configure(first_card, 1, {"attack":load("res://assets/icons/ui/attack.svg"),"block":load("res://assets/icons/ui/block.svg")}, false, false, true)
    root.add_child(button)
    button.apply_hand_arc(0, 5, false)
    _test(button.formal_card.get("id", "") == "C001" and button.visual != null, "real card UI built")
    var journal = load("res://scripts/battle_action_journal.gd").new()
    var battle = load("res://scripts/battle_controller.gd").new()
    battle.turn_number = 1
    journal.record_action(battle, "card", "C001", 0)
    _test(journal.actions.size() == 1 and journal.actions[0].card_id == "C001", "read-only input journal")
    print("COMBAT UX smoke: %d PASS / %d FAIL" % [checks - failures, failures])
    quit(0 if failures == 0 else 1)
