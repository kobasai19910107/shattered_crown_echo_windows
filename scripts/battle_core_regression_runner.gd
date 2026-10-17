class_name BattleCoreRegressionRunner
extends RefCounted

const CardValidationRunnerScript = preload("res://scripts/card_validation_runner.gd")
const BattleSimulationRunnerScript = preload("res://scripts/battle_simulation_runner.gd")
const PlaytestTelemetryRunnerScript = preload("res://scripts/playtest_telemetry_runner.gd")
const LoadoutValidationRunnerScript = preload("res://scripts/loadout_validation_runner.gd")
const BattleResultValidationRunnerScript = preload("res://scripts/battle_result_validation_runner.gd")

var passed: int = 0
var failures: Array[String] = []
var warnings: Array[String] = []
var lines: Array[String] = []

func run_all() -> Dictionary:
    passed = 0
    failures.clear()
    warnings.clear()
    lines.clear()

    _run_existing_suites()
    _run_weapon_trait_gate()
    _run_attribute_trait_gate()
    _run_continuous_effect_gate()
    _run_multi_enemy_gate()
    _run_equipment_gate()
    _run_seed_snapshot_gate()

    return {
        "ok": failures.is_empty(),
        "passed": passed,
        "failed": failures.size(),
        "warnings": warnings.size(),
        "failures": failures.duplicate(),
        "warning_lines": warnings.duplicate(),
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

func _warn(message: String) -> void:
    warnings.append(message)
    lines.append("WARN  %s" % message)

func _run_existing_suites() -> void:
    lines.append("=== EXISTING SUITES ===")

    var card_result: Dictionary = CardValidationRunnerScript.new().run_all()
    _assert("120-card catalog + runtime smoke suite", bool(card_result.get("ok", false)), "FAIL %d" % int(card_result.get("failed", 0)))
    lines.append("  card suite: PASS %d / FAIL %d" % [int(card_result.get("passed", 0)), int(card_result.get("failed", 0))])

    var loadout_result: Dictionary = LoadoutValidationRunnerScript.new().run_all()
    _assert("equipment/loadout suite", bool(loadout_result.get("ok", false)), "FAIL %d" % int(loadout_result.get("failed", 0)))
    lines.append("  loadout suite: PASS %d / FAIL %d" % [int(loadout_result.get("passed", 0)), int(loadout_result.get("failed", 0))])

    var telemetry_result: Dictionary = PlaytestTelemetryRunnerScript.new().run_all()
    _assert("playtest telemetry suite", bool(telemetry_result.get("ok", false)), "FAIL %d" % int(telemetry_result.get("failed", 0)))
    lines.append("  telemetry suite: PASS %d / FAIL %d" % [int(telemetry_result.get("passed", 0)), int(telemetry_result.get("failed", 0))])

    var simulation_result: Dictionary = BattleSimulationRunnerScript.new().run_all()
    _assert("deterministic batch/probe suite", bool(simulation_result.get("ok", false)), "FAIL %d" % int(simulation_result.get("failed", 0)))
    lines.append("  batch suite: PASS %d / FAIL %d / WARN %d" % [
        int(simulation_result.get("passed", 0)),
        int(simulation_result.get("failed", 0)),
        int(simulation_result.get("warnings", 0))
    ])
    if int(simulation_result.get("warnings", 0)) > 0:
        _warn("Batch simulation returned warnings. They are not treated as a Battle Core gate failure unless a runtime error/FAIL is also present.")

    var result_suite: Dictionary = BattleResultValidationRunnerScript.new().run_all()
    _assert("battle-end/BattleResult handoff suite", bool(result_suite.get("ok", false)), "FAIL %d" % int(result_suite.get("failed", 0)))
    lines.append("  BattleResult suite: PASS %d / FAIL %d" % [int(result_suite.get("passed", 0)), int(result_suite.get("failed", 0))])

func _fresh_battle(preset: String = "standard_trio") -> BattleController:
    var battle = BattleController.new()
    battle.start_battle(515151, [], preset)
    battle.hand.clear()
    battle.draw_pile.clear()
    battle.discard_pile.clear()
    battle.resolving_card = {}
    battle.pending_hand_selection = {"mode": "", "remaining": 0}
    battle.current_mana = 99
    battle.player_block = 0
    battle.last_notice = ""
    battle.combat_over = false
    battle.victory = false
    return battle

func _put_single_card(battle: BattleController, card_id: String) -> bool:
    battle.hand.clear()
    var card: Dictionary = battle.database.get_card_copy(card_id)
    if card.is_empty():
        return false
    battle.hand.append(card)
    return true

func _use_first_card(battle: BattleController, enemy_index: int = 0) -> bool:
    if battle.hand.is_empty():
        return false
    var target_type = battle.get_effective_target_type(0)
    return battle.use_card(0, enemy_index if target_type == "enemy" else -1)

func _run_weapon_trait_gate() -> void:
    lines.append("=== SIX WEAPON TRAITS ===")

    var sword = _fresh_battle()
    sword.weapon_traits["流転"] = true
    _put_single_card(sword, "C002")
    var sword_target = sword.get_effective_target_type(0)
    var sword_ok = sword.use_card(0, 0)
    _assert("流転 dynamic target + defense conversion", sword_ok and sword_target == "enemy" and sword.player_block == 6 and int(sword.get_enemy(0).get("hp", 0)) == 21 and not bool(sword.weapon_traits.get("流転", false)))

    var rapier = _fresh_battle("boss_solo")
    rapier.weapon_traits["精密"] = true
    _put_single_card(rapier, "C003")
    var rapier_ok = rapier.use_card(0, 0)
    var rapier_enemy = rapier.get_enemy(0)
    _assert("精密 Block Ignore / ON→OFF", rapier_ok and int(rapier_enemy.get("hp", 0)) == 32 and int(rapier_enemy.get("block", 0)) == 6 and int(rapier_enemy.get("vulnerable", 0)) == 0 and not bool(rapier.weapon_traits.get("精密", false)))

    var dagger = _fresh_battle()
    dagger.weapon_traits["連刃"] = true
    _put_single_card(dagger, "C053")
    var dagger_ok = dagger.use_card(0, 0)
    _assert("連刃 CONSUME uses same-damage second hit", dagger_ok and int(dagger.get_enemy(0).get("hp", 0)) == 8 and not bool(dagger.weapon_traits.get("連刃", false)))

    var greatsword = _fresh_battle()
    greatsword.weapon_traits["重撃"] = true
    _put_single_card(greatsword, "C019")
    var greatsword_ok = greatsword.use_card(0, 0)
    _assert("重撃 CONSUME uses x1.5", greatsword_ok and int(greatsword.get_enemy(0).get("hp", 0)) == 6 and not bool(greatsword.weapon_traits.get("重撃", false)))

    var magic_sword = _fresh_battle()
    _put_single_card(magic_sword, "C022")
    var magic_set_ok = magic_sword.use_card(0, 0)
    _assert("魔導 SET does not self-consume", magic_set_ok and bool(magic_sword.weapon_traits.get("魔導", false)) and magic_sword.get_enemy_attribute_trait(0, "爆発") == 2 and int(magic_sword.get_enemy(0).get("hp", 0)) == 21)
    _put_single_card(magic_sword, "C021")
    var magic_consume_ok = magic_sword.use_card(0, 0)
    _assert("魔導 CONSUME adds +2 attribute gain", magic_consume_ok and not bool(magic_sword.weapon_traits.get("魔導", false)) and magic_sword.get_enemy_attribute_trait(0, "爆発") == 5 and int(magic_sword.get_enemy(0).get("hp", 0)) == 11)

    var katana = _fresh_battle("boss_solo")
    katana.weapon_traits["納刀"] = true
    katana.enemies[0]["hp"] = 15
    katana.enemies[0]["block"] = 0
    _put_single_card(katana, "C012")
    var cost_preview = katana.get_effective_cost(0)
    var mana_before = katana.current_mana
    var katana_ok = katana.use_card(0, 0)
    _assert("納刀 Cost0 + Iai Boss execution", katana_ok and cost_preview == 0 and katana.current_mana == mana_before and int(katana.get_enemy(0).get("hp", 0)) == 0 and int(katana.get_playtest_report().get("executions", 0)) == 1 and not bool(katana.weapon_traits.get("納刀", false)))

func _run_attribute_trait_gate() -> void:
    lines.append("=== TEN ATTRIBUTE TRAITS ===")

    var strength = _fresh_battle()
    strength.attribute_traits["剛力"] = 3
    _put_single_card(strength, "C001")
    var strength_ok = strength.use_card(0, 0)
    _assert("剛力 stage adds once per Attack card", strength_ok and int(strength.get_enemy(0).get("hp", 0)) == 17)

    var explosion = _fresh_battle()
    var explosion_ok = explosion.add_debug_enemy_attribute_trait(0, "爆発", 3)
    _assert("爆発 threshold 3 deals 5", explosion_ok and explosion.get_enemy_attribute_trait(0, "爆発") == 3 and int(explosion.get_enemy(0).get("hp", 0)) == 19)

    var explosion_multi = _fresh_battle()
    var ex_traits: Dictionary = explosion_multi.enemies[0].get("attribute_traits", {}).duplicate(true)
    ex_traits["爆発"] = 2
    explosion_multi.enemies[0]["attribute_traits"] = ex_traits
    explosion_multi.add_debug_enemy_attribute_trait(0, "爆発", 7)
    _assert("爆発 processes all crossed 3/6/9 thresholds", explosion_multi.get_enemy_attribute_trait(0, "爆発") == 9 and int(explosion_multi.get_enemy(0).get("hp", 0)) == 3)

    var slow = _fresh_battle()
    slow.add_debug_enemy_attribute_trait(0, "鈍化", 3)
    _assert("鈍化 updates Intent total", slow.get_enemy_intent_display_label(0) == "Attack 2")

    var charged = _fresh_battle("slime_duo")
    charged.add_debug_attribute_trait("帯電", 3)
    charged.player_block = 100
    charged._enemy_phase()
    _assert("帯電 retaliates once per enemy Attack action", int(charged.get_enemy(0).get("hp", 0)) == 21 and int(charged.get_enemy(1).get("hp", 0)) == 21)

    var fortify = _fresh_battle()
    fortify.add_debug_attribute_trait("堅牢", 3)
    fortify._player_turn_start(false)
    _assert("堅牢 gives turn-start Block2 per stage", fortify.player_block == 2)

    var grace = _fresh_battle()
    grace.player_hp = 40
    grace.add_debug_attribute_trait("恩寵", 3)
    grace._player_turn_start(false)
    _assert("恩寵 heals 1 per stage at player-turn start", grace.player_hp == 41)

    var curse = _fresh_battle()
    curse.player_hp = 40
    curse.add_debug_enemy_attribute_trait(0, "呪印", 3)
    _put_single_card(curse, "C001")
    var curse_ok = curse.use_card(0, 0)
    _assert("呪印 drains once on first Attack", curse_ok and curse.player_hp == 42 and curse.curse_lifesteal_used)

    var poison = _fresh_battle("boss_solo")
    poison.enemies[0]["hp"] = 10
    poison.enemies[0]["block"] = 0
    poison.add_debug_enemy_attribute_trait(0, "猛毒", 3)
    poison._resolve_poison_end_of_enemy_phase()
    _assert("猛毒 deals 2 per stage at enemy-turn end", int(poison.get_enemy(0).get("hp", 0)) == 8)

    var magic_orb = _fresh_battle()
    magic_orb.current_mana = 0
    magic_orb.attribute_traits["魔珠"] = 2
    magic_orb.add_debug_attribute_trait("魔珠", 7)
    _assert("魔珠 resolves every crossed threshold", int(magic_orb.attribute_traits.get("魔珠", 0)) == 9 and magic_orb.current_mana == 3)

    var swift = _fresh_battle()
    swift.attribute_traits["疾風"] = 2
    swift.add_debug_attribute_trait("疾風", 7)
    _assert("疾風 stores one Cost-1 charge per crossed threshold", int(swift.attribute_traits.get("疾風", 0)) == 9 and swift.swift_cost_reduction_charges == 3)
    _put_single_card(swift, "C001")
    swift.current_mana = 3
    var swift_cost = swift.get_effective_cost(0)
    var swift_ok = swift.use_card(0, 0)
    _assert("疾風 applies at most one reduction per card", swift_ok and swift_cost == 0 and swift.current_mana == 3 and swift.swift_cost_reduction_charges == 2)

func _run_continuous_effect_gate() -> void:
    lines.append("=== CONTINUOUS EFFECT ENGINE ===")
    var power_ids = ["C010", "C016", "C028", "C042", "C056", "C069", "C083", "C092", "C098", "C106", "C110"]
    for card_id in power_ids:
        var b = _fresh_battle()
        _put_single_card(b, card_id)
        var card: Dictionary = b.hand[0]
        var effect_name = str(card.get("continuous_effect", ""))
        var effect_value = int(card.get("continuous_value", 0))
        var ok = _use_first_card(b, 0)
        _assert("%s registers %s" % [card_id, effect_name], ok and effect_name != "" and int(b.continuous_effects.get(effect_name, 0)) == effect_value and b.resolving_card.is_empty())

    var physical = _fresh_battle()
    physical.continuous_effects["physical_first_attack_damage"] = 2
    _put_single_card(physical, "C001")
    physical.use_card(0, 0)
    _assert("Physical engine buffs only first Attack trigger", int(physical.get_enemy(0).get("hp", 0)) == 16 and physical.first_attack_engine_used)

    var water = _fresh_battle()
    water.continuous_effects["water_first_slow_attack_reduction"] = 1
    water.add_debug_enemy_attribute_trait(0, "鈍化", 3)
    var values = water._get_enemy_attack_hit_values(0, 4, 1, true)
    _assert("Water engine adds first slowed Attack reduction", values.size() == 1 and int(values[0]) == 1 and water.first_slow_engine_used)

    var lightning = _fresh_battle()
    lightning.continuous_effects["lightning_first_retaliation_bonus"] = 2
    lightning.add_debug_attribute_trait("帯電", 3)
    lightning.enemies[0]["block"] = 0
    lightning._resolve_charge_retaliation(0)
    _assert("Lightning engine adds +2 to first retaliation", int(lightning.get_enemy(0).get("hp", 0)) == 19 and lightning.first_retaliation_engine_used)

    var earth = _fresh_battle()
    earth.continuous_effects["earth_turn_start_block_bonus"] = 2
    earth.add_debug_attribute_trait("堅牢", 3)
    earth._player_turn_start(false)
    _assert("Earth engine adds turn-start Block", earth.player_block == 4)

    var light = _fresh_battle()
    light.continuous_effects["light_turn_start_heal_bonus"] = 1
    light.player_hp = 40
    light.add_debug_attribute_trait("恩寵", 3)
    light._player_turn_start(false)
    _assert("Light engine adds turn-start heal", light.player_hp == 42)

    var dark = _fresh_battle()
    dark.continuous_effects["dark_lifesteal_bonus"] = 1
    dark.player_hp = 40
    dark.add_debug_enemy_attribute_trait(0, "呪印", 3)
    _put_single_card(dark, "C001")
    dark.use_card(0, 0)
    _assert("Dark engine adds +1 to curse drain", dark.player_hp == 43)

    var poison = _fresh_battle()
    poison.continuous_effects["poison_damage_bonus"] = 1
    poison.enemies[0]["block"] = 0
    poison.add_debug_enemy_attribute_trait(0, "猛毒", 3)
    poison._resolve_poison_end_of_enemy_phase()
    _assert("Poison engine adds +1 end-turn damage", int(poison.get_enemy(0).get("hp", 0)) == 21)

    var arcane = _fresh_battle()
    arcane.continuous_effects["arcane_first_magic_mana_block"] = 3
    arcane.current_mana = 0
    arcane.attribute_traits["魔珠"] = 2
    arcane.add_debug_attribute_trait("魔珠", 1)
    _assert("Arcane engine converts first 魔珠 Mana trigger to Block3", arcane.current_mana == 1 and arcane.player_block == 3 and arcane.first_magic_orb_engine_used)

    var wind = _fresh_battle()
    wind.continuous_effects["wind_first_swift_card_draw"] = 1
    wind.attribute_traits["疾風"] = 2
    wind.add_debug_attribute_trait("疾風", 1)
    wind.hand = [wind.database.get_card_copy("C001")]
    wind.draw_pile = [wind.database.get_card_copy("C002")]
    wind.current_mana = 3
    var wind_ok = wind.use_card(0, 0)
    _assert("Wind engine Draw1 on first 疾風-reduced card", wind_ok and wind.first_swift_engine_used and wind.hand.size() == 1 and str(wind.hand[0].get("id", "")) == "C002")

func _run_multi_enemy_gate() -> void:
    lines.append("=== MULTI-ENEMY / INTENT / TURN ORDER ===")

    var order = _fresh_battle("standard_trio")
    var order_ok = true
    for i in range(order.get_enemy_count()):
        if int(order.get_enemy(i).get("order_index", 0)) != i + 1:
            order_ok = false
            break
    _assert("EnemyOrderIndex is fixed left-to-right", order_ok)

    var shared_block = _fresh_battle("slime_duo")
    shared_block.player_block = 5
    shared_block.player_hp = 48
    shared_block._enemy_phase()
    _assert("Player Block is shared across multiple enemies", shared_block.player_hp == 45 and shared_block.player_block == 0)

    var multihit = _fresh_battle("standard_trio")
    multihit.enemies[0]["hp"] = 0
    multihit.enemies[2]["hp"] = 0
    multihit.player_block = 4
    multihit.player_hp = 48
    multihit._enemy_phase()
    _assert("Multi-hit consumes one shared Block pool sequentially", multihit.player_hp == 46 and multihit.player_block == 0)

    var death_stop = _fresh_battle("boss_solo")
    death_stop.enemies[0]["hp"] = 3
    death_stop.enemies[0]["block"] = 0
    death_stop.enemies[0]["intents"] = [{
        "label": "Attack then impossible Guard",
        "actions": [
            {"type": "attack", "damage": 1, "hits": 1},
            {"type": "block", "amount": 99}
        ]
    }]
    death_stop.add_debug_attribute_trait("帯電", 3)
    death_stop.player_block = 99
    death_stop._enemy_phase()
    _assert("Enemy death during own action cancels remaining actions", int(death_stop.get_enemy(0).get("hp", 0)) == 0 and int(death_stop.get_enemy(0).get("block", 0)) == 0 and death_stop.combat_over and death_stop.victory)

    var poison_win = _fresh_battle("boss_solo")
    poison_win.enemies[0]["hp"] = 2
    poison_win.enemies[0]["block"] = 0
    poison_win.add_debug_enemy_attribute_trait(0, "猛毒", 3)
    poison_win._resolve_poison_end_of_enemy_phase()
    _assert("Enemy-turn-end 猛毒 can end battle before next player turn", poison_win.combat_over and poison_win.victory and int(poison_win.get_enemy(0).get("hp", 0)) == 0)

func _run_equipment_gate() -> void:
    lines.append("=== EQUIPMENT HP / RARITY / SPECIAL EFFECTS ===")
    var builder = LoadoutBuilder.new()
    var loaded = builder.load_data()
    _assert("LoadoutBuilder loads v1.7.0-compatible source data", loaded)
    if not loaded:
        return

    builder.load_prototype_loadout()
    var deck_ids = builder.build_deck_ids()
    var snapshot = builder.get_snapshot()
    var b = BattleController.new()
    b.start_battle(12015, deck_ids, "slime_duo", snapshot)
    _assert("6 equipment slots always build 24 cards", deck_ids.size() == 24)
    _assert("Prototype equipment HP total is connected to Max HP", b.player_max_hp == builder.calculate_player_max_hp() and b.player_hp == b.player_max_hp)
    _assert("Prototype rarity effects are collected", b.equipment_special_effects.size() == 5)
    _assert("Prototype battle-start traits applied", bool(b.weapon_traits.get("流転", false)) and int(b.attribute_traits.get("剛力", 0)) == 1 and int(b.attribute_traits.get("堅牢", 0)) == 1 and int(b.attribute_traits.get("疾風", 0)) == 1)
    _assert("Prototype turn-start Block applied", b.player_block == 1)

    builder.unequip_all()
    var fallback_ids = builder.build_deck_ids()
    _assert("Unequipped loadout still builds 24 basic cards", fallback_ids.size() == 24 and fallback_ids.count("BASIC_STRIKE") == 12 and fallback_ids.count("BASIC_GUARD") == 12 and builder.calculate_player_max_hp() == 48)

    builder.load_prototype_loadout()
    var legendary_ok = builder.set_equipment("body", "EQ_BODY_GRACE_01")
    var legendary = BattleController.new()
    legendary.start_battle(14015, builder.build_deck_ids(), "slime_duo", builder.get_snapshot())
    _assert("Legendary prototype uses 3 special-effect slots", legendary_ok and builder.equipment_db.get_item_special_effects("EQ_BODY_GRACE_01").size() == 3)
    _assert("Legendary first-turn Draw/Mana/恩寵 effects resolve", legendary.hand.size() == 6 and legendary.current_mana == 4 and int(legendary.attribute_traits.get("恩寵", 0)) == 1)

func _run_seed_snapshot_gate() -> void:
    lines.append("=== DETERMINISM / SNAPSHOT ===")
    var builder = LoadoutBuilder.new()
    if not builder.load_data():
        _assert("Seed snapshot setup", false, "LoadoutBuilder failed")
        return
    builder.load_prototype_loadout()
    var deck_ids = builder.build_deck_ids()
    var snapshot = builder.get_snapshot()

    var a = BattleController.new()
    var b = BattleController.new()
    a.start_battle(777777, deck_ids, "armored_pair", snapshot)
    b.start_battle(777777, deck_ids, "armored_pair", snapshot)
    _assert("Same deck + preset + equipment + Seed reproduces opening hand", _card_ids(a.hand) == _card_ids(b.hand))
    _assert("Same snapshot reproduces HP/traits/effects", a.player_max_hp == b.player_max_hp and a.weapon_traits == b.weapon_traits and a.attribute_traits == b.attribute_traits and a.equipment_special_effects == b.equipment_special_effects)

    var frozen_snapshot: Dictionary = snapshot.duplicate(true)
    var frozen_deck: Array = deck_ids.duplicate()
    builder.set_equipment("main_weapon", "EQ_MW_RAPIER_01")
    var retry = BattleController.new()
    retry.start_battle(777777, frozen_deck, "armored_pair", frozen_snapshot)
    var main_weapon: Dictionary = retry.active_equipment_loadout.get("main_weapon", {})
    _assert("Battle-start loadout snapshot is immutable from later builder changes", str(main_weapon.get("item_id", "")) == "EQ_MW_SWORD_01")

func _card_ids(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.get("id", "?")))
    return result
