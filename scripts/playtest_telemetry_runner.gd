extends RefCounted

func run_all() -> Dictionary:
    var failures: Array[String] = []
    var passed = 0

    var battle = BattleController.new()
    battle.start_battle(424242, [], "standard_trio")
    var initial = battle.get_playtest_report()

    passed += _check(initial.get("prototype_version", "") == "v1.7.0", "prototype_version=v1.7.0", failures)
    passed += _check(int(initial.get("seed", 0)) == 424242, "Seed captured", failures)
    passed += _check(str(initial.get("enemy_preset", "")) == "standard_trio", "Enemy preset captured", failures)
    passed += _check(initial.get("deck_ids", []).size() == 24, "24-card deck captured", failures)
    passed += _check(int(initial.get("cards_drawn", 0)) == 5, "Initial Draw5 counted", failures)
    passed += _check(int(initial.get("cards_used", 0)) == 0, "No card used at battle start", failures)
    passed += _check(int(initial.get("player_max_hp", 0)) == BattleController.DEFAULT_PLAYER_MAX_HP, "Manual deck uses default Max HP", failures)

    var used = false
    for i in range(battle.hand.size()):
        if not battle.can_use_card(i):
            continue
        var target_type = battle.get_effective_target_type(i)
        if target_type == "enemy":
            used = battle.use_card(i, 0)
        else:
            used = battle.use_card(i, -1)
        if used:
            break

    if battle.is_hand_selection_active() and not battle.hand.is_empty():
        battle.select_hand_for_pending(0)

    var after_card = battle.get_playtest_report()
    passed += _check(used, "At least one opening card can be used", failures)
    passed += _check(int(after_card.get("cards_used", 0)) == 1, "Card use counted", failures)
    passed += _check(not after_card.get("card_use_counts", {}).is_empty(), "Card ID use-count map populated", failures)

    if not battle.combat_over and not battle.is_hand_selection_active() and battle.resolving_card.is_empty():
        battle.end_player_turn()
    var after_enemy = battle.get_playtest_report()
    passed += _check(int(after_enemy.get("enemy_attack_actions_received", 0)) > 0 or battle.combat_over, "Enemy attack actions counted", failures)
    passed += _check(int(after_enemy.get("turns", 0)) >= 1, "Turn count available", failures)
    passed += _check(after_enemy.has("enemy_states_end"), "Final enemy snapshot available", failures)

    return {
        "ok": failures.is_empty(),
        "passed": passed,
        "failed": failures.size(),
        "failures": failures
    }

func _check(condition: bool, label: String, failures: Array[String]) -> int:
    if condition:
        return 1
    failures.append(label)
    return 0
