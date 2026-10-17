class_name BattleResultValidationRunner
extends RefCounted

var passed: int = 0
var failures: Array[String] = []
var lines: Array[String] = []

func run_all() -> Dictionary:
    passed = 0
    failures.clear()
    lines.clear()

    _victory_result_test()
    _defeat_result_test()
    _idempotent_finalize_test()
    _result_copy_isolation_test()
    _restart_reset_test()
    _transient_close_test()
    _mid_resolution_victory_test()

    return {
        "ok": failures.is_empty(),
        "passed": passed,
        "failed": failures.size(),
        "failures": failures.duplicate(),
        "lines": lines.duplicate()
    }

func _assert(name: String, condition: bool, detail: String = "") -> void:
    if condition:
        passed += 1
        lines.append("PASS  %s" % name)
    else:
        var message = name if detail == "" else "%s — %s" % [name, detail]
        failures.append(message)
        lines.append("FAIL  %s" % message)

func _battle(preset: String = "boss_solo") -> BattleController:
    var battle = BattleController.new()
    battle.start_battle(616161, [], preset)
    battle.current_mana = 99
    return battle

func _victory_result_test() -> void:
    lines.append("=== VICTORY HANDOFF ===")
    var battle = _battle("boss_solo")
    battle.enemies[0]["hp"] = 0
    battle._check_victory()
    var result = battle.get_battle_result()
    var payload = battle.get_next_encounter_payload()
    _assert("Victory creates BattleResult", battle.combat_over and battle.victory and battle.has_battle_result())
    _assert("Victory result code/reason", str(result.get("result", "")) == "VICTORY" and str(result.get("reason", "")) == "all_enemies_defeated")
    _assert("Victory is eligible for next encounter", bool(result.get("eligible_for_next_encounter", false)) and not payload.is_empty())
    _assert("BattleResult preserves Seed/preset", int(result.get("seed", 0)) == 616161 and str(result.get("enemy_preset", "")) == "boss_solo")
    _assert("BattleResult preserves 24-card deck", result.get("deck_ids", []).size() == 24)
    _assert("Next payload preserves remaining HP/deck", int(payload.get("player_hp_remaining", -1)) == battle.player_hp and payload.get("deck_ids", []).size() == 24)
    _assert("Telemetry is finalized", str(result.get("telemetry", {}).get("result", "")) == "VICTORY")

func _defeat_result_test() -> void:
    lines.append("=== DEFEAT HANDOFF ===")
    var battle = _battle("boss_solo")
    battle.player_hp = 1
    battle.player_block = 0
    battle.enemies[0]["intents"] = [{"label":"Lethal", "actions":[{"type":"attack", "damage":99, "hits":1}]}]
    battle.enemies[0]["intent_index"] = 0
    battle._enemy_phase()
    var result = battle.get_battle_result()
    _assert("Defeat creates BattleResult", battle.combat_over and not battle.victory and battle.has_battle_result())
    _assert("Defeat clamps HP to zero", battle.player_hp == 0 and int(result.get("player_hp_end", -1)) == 0)
    _assert("Defeat result code/reason", str(result.get("result", "")) == "DEFEAT" and str(result.get("reason", "")) == "player_hp_zero")
    _assert("Defeat cannot advance encounter", battle.get_next_encounter_payload().is_empty() and not bool(result.get("eligible_for_next_encounter", true)))

func _idempotent_finalize_test() -> void:
    lines.append("=== IDEMPOTENT FINALIZE ===")
    var battle = _battle()
    battle._finalize_battle("VICTORY", "test_first")
    var first = battle.get_battle_result()
    battle._finalize_battle("DEFEAT", "test_second")
    var second = battle.get_battle_result()
    _assert("Finalization happens only once", str(second.get("result", "")) == "VICTORY" and str(second.get("reason", "")) == "test_first")
    _assert("Second finalize cannot overwrite result", first == second)

func _result_copy_isolation_test() -> void:
    lines.append("=== RESULT SNAPSHOT ISOLATION ===")
    var battle = _battle()
    battle._finalize_battle("VICTORY", "snapshot_test")
    var copy = battle.get_battle_result()
    copy["result"] = "MUTATED"
    copy["deck_ids"] = []
    var fresh = battle.get_battle_result()
    _assert("Returned result is a deep copy", str(fresh.get("result", "")) == "VICTORY" and fresh.get("deck_ids", []).size() == 24)

func _restart_reset_test() -> void:
    lines.append("=== NEW BATTLE RESET ===")
    var battle = _battle()
    battle._finalize_battle("VICTORY", "before_restart")
    battle.start_battle(626262, [], "slime_duo")
    _assert("Starting a new battle clears old BattleResult", not battle.combat_over and not battle.has_battle_result() and battle.battle_end_reason == "")
    _assert("New battle uses new reproduction identity", battle.get_active_seed() == 626262 and battle.get_active_enemy_preset() == "slime_duo")

func _transient_close_test() -> void:
    lines.append("=== END-OF-BATTLE STATE CLOSE ===")
    var battle = _battle()
    battle.resolving_card = {"id":"TEST"}
    battle.pending_hand_selection = {"mode":"discard", "remaining":1}
    battle._finalize_battle("VICTORY", "close_transient")
    _assert("Resolving card is cleared", battle.resolving_card.is_empty())
    _assert("Pending hand selection is cleared", not battle.is_hand_selection_active())

func _mid_resolution_victory_test() -> void:
    lines.append("=== PLAYER CARD RESOLUTION COMPLETES BEFORE VICTORY ===")
    var battle = _battle("boss_solo")
    battle.hand.clear()
    battle.draw_pile.clear()
    battle.discard_pile.clear()
    battle.current_mana = 99
    battle.weapon_traits["魔導"] = true
    battle.enemies[0]["hp"] = 10
    battle.enemies[0]["block"] = 0
    battle.hand.append(battle.database.get_card_copy("C022"))
    var ok = battle.use_card(0, 0)
    var last_id = "" if battle.discard_pile.is_empty() else str(battle.discard_pile.back().get("id", ""))
    _assert("Threshold kill still completes confirmed card resolution", ok and battle.combat_over and battle.victory and battle.resolving_card.is_empty())
    _assert("Winning card reaches discard instead of empty placeholder", last_id == "C022")
