class_name BattleSimulationRunner
extends RefCounted

const MAX_TURNS := 30
const MAX_ACTIONS_PER_TURN := 40
const BATCH_SEEDS := [1001, 1002, 1003, 1011, 1021, 1031, 1101, 1201, 1301, 1401, 1501, 1601]

var passed: int = 0
var failed: int = 0
var warnings: int = 0
var failures: Array[String] = []
var scenario_lines: Array[String] = []

func run_all() -> Dictionary:
    passed = 0
    failed = 0
    warnings = 0
    failures.clear()
    scenario_lines.clear()

    _probe_all_official_cards()
    _run_determinism_probe()
    _run_setup_builder_probe()
    _run_enemy_preset_probe()
    _run_battle_batch()

    return {
        "ok": failed == 0,
        "passed": passed,
        "failed": failed,
        "warnings": warnings,
        "failures": failures.duplicate(),
        "scenario_lines": scenario_lines.duplicate()
    }

func _pass(test_name: String) -> void:
    passed += 1

func _fail(test_name: String, detail: String) -> void:
    failed += 1
    failures.append("%s — %s" % [test_name, detail])

func _warn(message: String) -> void:
    warnings += 1
    scenario_lines.append("WARN: %s" % message)

func _probe_all_official_cards() -> void:
    var probe_failures = 0
    for number in range(1, 121):
        var card_id = "C%03d" % number
        var battle = BattleController.new()
        battle.start_battle(8000 + number)

        battle.hand.clear()
        battle.discard_pile.clear()
        battle.current_mana = 99
        battle.last_notice = ""

        var card: Dictionary = battle.database.get_card_copy(card_id)
        if card.is_empty():
            probe_failures += 1
            _fail("Probe %s" % card_id, "card missing from CardDatabase")
            continue

        battle.hand.append(card)
        # Filler cards guarantee Draw→Bottom/Discard cards always have a legal selection.
        for filler_id in ["C001", "C002", "C005", "C009"]:
            battle.hand.append(battle.database.get_card_copy(filler_id))

        if not battle.can_use_card(0):
            probe_failures += 1
            _fail("Probe %s" % card_id, "card is not usable in a neutral legal state")
            continue

        var target_index = -1
        if battle.get_effective_target_type(0) == "enemy":
            target_index = _choose_target(battle)
            if target_index < 0:
                probe_failures += 1
                _fail("Probe %s" % card_id, "no legal enemy target")
                continue

        if not battle.use_card(0, target_index):
            probe_failures += 1
            _fail("Probe %s" % card_id, "BattleController.use_card returned false")
            continue

        var guard = 0
        while battle.is_hand_selection_active() and guard < 4:
            guard += 1
            if battle.hand.is_empty():
                break
            battle.select_hand_for_pending(0)

        if battle.is_hand_selection_active():
            probe_failures += 1
            _fail("Probe %s" % card_id, "hand-selection resolution did not finish")
            continue
        if not battle.resolving_card.is_empty():
            probe_failures += 1
            _fail("Probe %s" % card_id, "card remained in resolving zone")
            continue

        _pass("Probe %s" % card_id)

    if probe_failures == 0:
        scenario_lines.append("Official card probes: PASS 120/120")
    else:
        scenario_lines.append("Official card probes: FAIL %d/120" % probe_failures)

func _run_determinism_probe() -> void:
    var a = BattleController.new()
    var b = BattleController.new()
    a.start_battle(424242)
    b.start_battle(424242)

    var hand_a = _ids_from_cards(a.hand)
    var hand_b = _ids_from_cards(b.hand)
    var draw_a = _ids_from_cards(a.draw_pile)
    var draw_b = _ids_from_cards(b.draw_pile)

    if hand_a == hand_b and draw_a == draw_b:
        _pass("Deterministic initial shuffle")
        scenario_lines.append("Determinism: PASS (Seed 424242 produces identical initial Hand/Draw order)")
    else:
        _fail("Deterministic initial shuffle", "same Seed produced different card order")
        scenario_lines.append("Determinism: FAIL")


func _run_setup_builder_probe() -> void:
    var builder = DeckBuilder.new()
    if not builder.load_data():
        _fail("DeckBuilder load", "card database failed to load")
        return
    _pass("DeckBuilder load")

    builder.load_prototype_deck()
    if builder.deck_ids.size() == DeckBuilder.DECK_SIZE and builder.is_ready():
        _pass("Prototype deck size")
    else:
        _fail("Prototype deck size", "expected 24 cards, got %d" % builder.deck_ids.size())

    var attr_expected = {
        "物理": 12, "炎": 12, "水": 12, "雷": 12, "地": 12,
        "光": 12, "闇": 12, "毒": 12, "秘術": 12, "風": 12
    }
    for attr in attr_expected.keys():
        var ids = builder.get_filtered_card_ids(str(attr), "ALL", "ALL", "")
        if ids.size() == int(attr_expected[attr]):
            _pass("Filter attribute %s" % attr)
        else:
            _fail("Filter attribute %s" % attr, "expected %d, got %d" % [attr_expected[attr], ids.size()])

    var weapon_expected = {
        "片手剣": 20, "レイピア": 20, "短剣": 20,
        "大剣": 20, "魔法剣": 20, "刀": 20
    }
    for weapon in weapon_expected.keys():
        var ids = builder.get_filtered_card_ids("ALL", str(weapon), "ALL", "")
        if ids.size() == int(weapon_expected[weapon]):
            _pass("Filter weapon %s" % weapon)
        else:
            _fail("Filter weapon %s" % weapon, "expected %d, got %d" % [weapon_expected[weapon], ids.size()])

    builder.clear_deck()
    if builder.deck_ids.is_empty() and not builder.is_ready():
        _pass("Deck clear")
    else:
        _fail("Deck clear", "deck was not empty after clear")

    for _i in range(DeckBuilder.DECK_SIZE):
        builder.add_card("C001")
    if builder.is_ready() and not builder.add_card("C002"):
        _pass("Deck size cap")
    else:
        _fail("Deck size cap", "builder allowed more than 24 cards or failed readiness")

    if builder.remove_one("C001") and builder.deck_ids.size() == 23 and not builder.is_ready():
        _pass("Deck remove")
    else:
        _fail("Deck remove", "remove_one did not reduce deck to 23")

    scenario_lines.append("Setup builder: 120-card filters / 24-card cap / add-remove checks complete")

func _run_enemy_preset_probe() -> void:
    var expected_counts = {
        "standard_trio": 3,
        "slime_duo": 2,
        "armored_pair": 2,
        "boss_solo": 1
    }
    for preset_id in expected_counts.keys():
        var battle = BattleController.new()
        battle.start_battle(515151, [], str(preset_id))
        if battle.get_enemy_count() != int(expected_counts[preset_id]):
            _fail("Preset %s" % preset_id, "expected %d enemies, got %d" % [expected_counts[preset_id], battle.get_enemy_count()])
            continue
        var order_ok = true
        for i in range(battle.get_enemy_count()):
            if int(battle.get_enemy(i).get("order_index", 0)) != i + 1:
                order_ok = false
                break
        if order_ok:
            _pass("Preset %s" % preset_id)
        else:
            _fail("Preset %s" % preset_id, "EnemyOrderIndex was not sequential")
    scenario_lines.append("Enemy presets: PASS check requested for standard_trio / slime_duo / armored_pair / boss_solo")

func _run_battle_batch() -> void:
    var decks = {
        "Prototype": [],
        "Attribute sampler": _build_attribute_sampler_ids()
    }

    var total_runs = 0
    var wins = 0
    var losses = 0
    var timeouts = 0
    var total_turns = 0

    for deck_name in decks.keys():
        var deck_ids: Array = decks[deck_name]
        var deck_wins = 0
        var deck_losses = 0
        var deck_timeouts = 0
        var deck_turns = 0

        for seed_value in BATCH_SEEDS:
            var battle = BattleController.new()
            battle.start_battle(int(seed_value), deck_ids)
            var result = _autoplay_battle(battle)
            total_runs += 1
            deck_turns += int(result.get("turns", 0))
            total_turns += int(result.get("turns", 0))

            var outcome: String = str(result.get("outcome", "timeout"))
            if outcome == "victory":
                wins += 1
                deck_wins += 1
            elif outcome == "defeat":
                losses += 1
                deck_losses += 1
            else:
                timeouts += 1
                deck_timeouts += 1

            if bool(result.get("runtime_error", false)):
                _fail("Batch %s Seed %d" % [deck_name, seed_value], str(result.get("error", "runtime simulation error")))
            else:
                _pass("Batch %s Seed %d" % [deck_name, seed_value])

        var avg_turns = float(deck_turns) / float(BATCH_SEEDS.size())
        scenario_lines.append("%s: %d runs / W %d / L %d / timeout %d / avg turns %.2f" % [
            deck_name, BATCH_SEEDS.size(), deck_wins, deck_losses, deck_timeouts, avg_turns
        ])

    if timeouts > 0:
        _warn("%d/%d autoplay battles reached the %d-turn safety cap. This is balance/AI data, not a script failure." % [timeouts, total_runs, MAX_TURNS])

    var overall_avg = 0.0 if total_runs == 0 else float(total_turns) / float(total_runs)
    scenario_lines.append("Batch total: %d / W %d / L %d / timeout %d / avg turns %.2f" % [total_runs, wins, losses, timeouts, overall_avg])
    scenario_lines.append("Note: autoplay AI is intentionally simple; W/L is not a balance verdict.")

func _autoplay_battle(battle: BattleController) -> Dictionary:
    var loop_guard = 0
    while not battle.combat_over and battle.turn_number <= MAX_TURNS:
        loop_guard += 1
        if loop_guard > MAX_TURNS + 2:
            return {"outcome": "timeout", "turns": battle.turn_number, "runtime_error": true, "error": "outer loop guard triggered"}

        var actions = 0
        while not battle.combat_over and actions < MAX_ACTIONS_PER_TURN:
            if battle.is_hand_selection_active():
                if battle.hand.is_empty():
                    return {"outcome": "timeout", "turns": battle.turn_number, "runtime_error": true, "error": "pending hand selection with empty hand"}
                battle.select_hand_for_pending(0)
                actions += 1
                continue

            var hand_index = _choose_playable_card(battle)
            if hand_index < 0:
                break

            var target_index = -1
            if battle.get_effective_target_type(hand_index) == "enemy":
                target_index = _choose_target(battle)
                if target_index < 0:
                    break

            if not battle.use_card(hand_index, target_index):
                return {"outcome": "timeout", "turns": battle.turn_number, "runtime_error": true, "error": "autoplay selected a card that failed to use"}
            actions += 1

        if actions >= MAX_ACTIONS_PER_TURN:
            return {"outcome": "timeout", "turns": battle.turn_number, "runtime_error": true, "error": "per-turn action guard triggered"}

        if not battle.combat_over:
            battle.end_player_turn()

    if battle.combat_over:
        return {
            "outcome": "victory" if battle.victory else "defeat",
            "turns": battle.turn_number,
            "runtime_error": false
        }
    return {"outcome": "timeout", "turns": battle.turn_number, "runtime_error": false}

func _choose_playable_card(battle: BattleController) -> int:
    var best_index = -1
    var best_score = -999999.0
    for i in range(battle.hand.size()):
        if not battle.can_use_card(i):
            continue
        var card: Dictionary = battle.hand[i]
        var score = _score_card_for_autoplay(battle, card, i)
        if score > best_score:
            best_score = score
            best_index = i
    return best_index

func _score_card_for_autoplay(battle: BattleController, card: Dictionary, hand_index: int) -> float:
    var cost = battle.get_effective_cost(hand_index)
    var damage = int(card.get("base_damage", 0))
    var block = int(card.get("base_block", 0))
    var score = 0.0

    # Low HP raises the value of defensive cards. Otherwise attacks/finishers are preferred.
    var hp_ratio = float(battle.player_hp) / float(battle.player_max_hp)
    if damage > 0:
        score += 70.0 + float(damage) * 2.0
    if block > 0:
        score += float(block) * (4.0 if hp_ratio < 0.55 else 1.4)
    if card.get("role", "") == "決着技":
        score += 16.0
    if card.get("role", "") == "継続効果":
        score += 12.0 if battle.turn_number <= 3 else 2.0
    if int(card.get("draw_count", 0)) > 0:
        score += 8.0
    if str(card.get("weapon_trait_action", "NEUTRAL")) == "SET" or int(card.get("attribute_trait_gain", 0)) >= 2:
        score += 5.0
    score -= float(cost) * 5.0
    return score

func _choose_target(battle: BattleController) -> int:
    var best_index = -1
    var lowest_hp = 1 << 30
    for enemy_index in range(battle.get_enemy_count()):
        if not battle.is_enemy_target_valid(enemy_index):
            continue
        var enemy = battle.get_enemy(enemy_index)
        var hp = int(enemy.get("hp", 0))
        if hp < lowest_hp:
            lowest_hp = hp
            best_index = enemy_index
    return best_index

func _build_attribute_sampler_ids() -> Array:
    # Two sequential cards from each 12-card attribute block = 20 cards,
    # then four cross-role cards to reach the formal 24-card battle size.
    var result: Array = []
    for attribute_index in range(10):
        var first = attribute_index * 12 + 1
        result.append("C%03d" % first)
        result.append("C%03d" % (first + 1))
    for extra in [6, 17, 44, 109]:
        result.append("C%03d" % extra)
    return result

func _ids_from_cards(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.get("id", "?")))
    return result
