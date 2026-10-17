class_name CardValidationRunner
extends RefCounted

const ATTR_TRAITS := {
    "物理": "剛力", "炎": "爆発", "水": "鈍化", "雷": "帯電", "地": "堅牢",
    "光": "恩寵", "闇": "呪印", "毒": "猛毒", "秘術": "魔珠", "風": "疾風"
}
const WEAPON_TRAITS := {
    "片手剣": "流転", "レイピア": "精密", "短剣": "連刃",
    "大剣": "重撃", "魔法剣": "魔導", "刀": "納刀"
}
const ROLE_ATTRIBUTE_GAINS := {
    "基本攻撃": 1, "基本防御": 1, "特性生成": 2, "特性利用": 1,
    "手札循環": 1, "補助": 1, "継続効果": 1, "決着技": 0
}
const VALID_WEAPON_TRAIT_ACTIONS := ["SET", "CONSUME", "NEUTRAL"]
const WEAPON_TRAIT_ACTION_COUNTS := {"SET": 41, "CONSUME": 48, "NEUTRAL": 31}
const ROLE_COUNTS := {
    "基本攻撃": 21, "基本防御": 11, "特性生成": 15, "特性利用": 18,
    "手札循環": 14, "補助": 15, "継続効果": 11, "決着技": 15
}
const ATTRIBUTE_COUNTS := {
    "物理": 12, "炎": 12, "水": 12, "雷": 12, "地": 12,
    "光": 12, "闇": 12, "毒": 12, "秘術": 12, "風": 12
}
const WEAPON_COUNTS := {
    "片手剣": 20, "レイピア": 20, "短剣": 20, "大剣": 20, "魔法剣": 20, "刀": 20
}
const WEAPON_ROLE_COSTS := {
    "片手剣": {"基本攻撃":1,"基本防御":1,"特性生成":1,"特性利用":2,"手札循環":1,"補助":1,"継続効果":2,"決着技":3},
    "レイピア": {"基本攻撃":1,"基本防御":1,"特性生成":1,"特性利用":2,"手札循環":1,"補助":1,"継続効果":2,"決着技":3},
    "短剣": {"基本攻撃":1,"基本防御":1,"特性生成":1,"特性利用":2,"手札循環":1,"補助":1,"継続効果":2,"決着技":2},
    "大剣": {"基本攻撃":2,"基本防御":1,"特性生成":1,"特性利用":2,"手札循環":1,"補助":1,"継続効果":2,"決着技":3},
    "魔法剣": {"基本攻撃":1,"基本防御":1,"特性生成":1,"特性利用":2,"手札循環":1,"補助":1,"継続効果":2,"決着技":3},
    "刀": {"基本攻撃":1,"基本防御":1,"特性生成":1,"特性利用":2,"手札循環":1,"補助":1,"継続効果":2,"決着技":2}
}
const VALID_TARGETS := ["enemy", "self", "none"]
const VALID_TYPES := ["attack", "skill", "power"]
const VALID_HAND_ACTIONS := ["bottom", "discard"]
const VALID_WEAPON_INDIVIDUALITY := []
const VALID_CONTINUOUS_EFFECTS := [
    "physical_first_attack_damage", "fire_first_explosion_bonus", "water_first_slow_attack_reduction",
    "lightning_first_retaliation_bonus", "earth_turn_start_block_bonus", "light_turn_start_heal_bonus",
    "dark_lifesteal_bonus", "poison_damage_bonus", "arcane_first_magic_mana_block", "wind_first_swift_card_draw"
]

var passed = 0
var failures: Array[String] = []
var warnings: Array[String] = []
var scenario_lines: Array[String] = []

func run_all() -> Dictionary:
    passed = 0
    failures.clear()
    warnings.clear()
    scenario_lines.clear()

    var db = CardDatabase.new()
    if not db.load_data():
        _fail("DATABASE", "CardDatabase.load_data() failed.")
        return _build_result()

    _validate_static_catalog(db)
    _run_runtime_scenarios()
    return _build_result()

func _build_result() -> Dictionary:
    return {
        "passed": passed,
        "failed": failures.size(),
        "warnings": warnings.size(),
        "failures": failures.duplicate(),
        "warning_lines": warnings.duplicate(),
        "scenario_lines": scenario_lines.duplicate(),
        "ok": failures.is_empty()
    }

func _pass() -> void:
    passed += 1

func _fail(test_name: String, message: String) -> void:
    failures.append("[%s] %s" % [test_name, message])

func _warn(test_name: String, message: String) -> void:
    warnings.append("[%s] %s" % [test_name, message])

func _assert_true(test_name: String, condition: bool, message: String) -> void:
    if condition:
        _pass()
    else:
        _fail(test_name, message)

func _scenario_ok(name: String, message: String = "") -> void:
    _pass()
    var suffix = ""
    if message != "":
        suffix = " — " + message
    scenario_lines.append("PASS  %s%s" % [name, suffix])

func _scenario_fail(name: String, message: String) -> void:
    _fail(name, message)
    scenario_lines.append("FAIL  %s — %s" % [name, message])

func _validate_static_catalog(db: CardDatabase) -> void:
    _assert_true("COUNT", db.get_official_card_count() == 120, "Expected 120 official cards, got %d." % db.get_official_card_count())

    var expected_ids: Array[String] = []
    for i in range(1, 121):
        expected_ids.append("C%03d" % i)
    _assert_true("IDS", db.get_official_card_ids() == expected_ids, "Official IDs must be exactly C001..C120.")

    var attr_counts: Dictionary = {}
    var weapon_counts: Dictionary = {}
    var role_counts: Dictionary = {}
    var continuous_count = 0
    var individuality_count = 0
    var iai_count = 0
    var weapon_action_counts: Dictionary = {"SET": 0, "CONSUME": 0, "NEUTRAL": 0}

    for card_id in db.get_official_card_ids():
        var card: Dictionary = db.create_card_copy(card_id)
        if card.is_empty():
            _fail(card_id, "Card copy is empty.")
            continue

        var required = [
            "id", "display_name", "attribute", "attribute_trait", "weapon", "weapon_trait", "role",
            "card_type", "cost", "base_damage", "base_block", "weapon_trait_action", "attribute_trait_gain",
            "text", "target_type"
        ]
        for field_name in required:
            _assert_true(card_id, card.has(field_name), "Missing required field '%s'." % field_name)

        _assert_true(card_id, str(card.get("id", "")) == card_id, "Internal id does not match dictionary key.")
        var attr = str(card.get("attribute", ""))
        var weapon = str(card.get("weapon", ""))
        var role = str(card.get("role", ""))
        var card_type = str(card.get("card_type", ""))
        var target_type = str(card.get("target_type", ""))

        _assert_true(card_id, ATTR_TRAITS.has(attr), "Unknown attribute: %s" % attr)
        if ATTR_TRAITS.has(attr):
            _assert_true(card_id, str(card.get("attribute_trait", "")) == str(ATTR_TRAITS[attr]), "Attribute trait mismatch.")
        _assert_true(card_id, WEAPON_TRAITS.has(weapon), "Unknown weapon: %s" % weapon)
        if WEAPON_TRAITS.has(weapon):
            _assert_true(card_id, str(card.get("weapon_trait", "")) == str(WEAPON_TRAITS[weapon]), "Weapon trait mismatch.")
        _assert_true(card_id, ROLE_ATTRIBUTE_GAINS.has(role), "Unknown role: %s" % role)
        _assert_true(card_id, VALID_TYPES.has(card_type), "Unknown card_type: %s" % card_type)
        _assert_true(card_id, VALID_TARGETS.has(target_type), "Unknown target_type: %s" % target_type)
        _assert_true(card_id, int(card.get("cost", -1)) >= 0, "Cost must be >= 0.")
        if WEAPON_ROLE_COSTS.has(weapon) and WEAPON_ROLE_COSTS[weapon].has(role):
            _assert_true(card_id, int(card.get("cost", -1)) == int(WEAPON_ROLE_COSTS[weapon][role]), "Cost mismatch for %s / %s." % [weapon, role])
        _assert_true(card_id, int(card.get("base_damage", -1)) >= 0, "base_damage must be >= 0.")
        _assert_true(card_id, int(card.get("base_block", -1)) >= 0, "base_block must be >= 0.")

        if ROLE_ATTRIBUTE_GAINS.has(role):
            _assert_true(card_id, int(card.get("attribute_trait_gain", -1)) == int(ROLE_ATTRIBUTE_GAINS[role]), "attribute_trait_gain mismatch for role %s." % role)

        var weapon_action: String = str(card.get("weapon_trait_action", ""))
        _assert_true(card_id, VALID_WEAPON_TRAIT_ACTIONS.has(weapon_action), "Invalid weapon_trait_action: %s" % weapon_action)
        if weapon_action_counts.has(weapon_action):
            weapon_action_counts[weapon_action] = int(weapon_action_counts[weapon_action]) + 1
        _assert_true(card_id, not card.has("weapon_trait_gain"), "Legacy weapon_trait_gain must not exist in v1.7.0 official cards.")
        _assert_true(card_id, not card.has("weapon_individuality"), "Legacy weapon_individuality must not exist in v1.7.0 official cards.")

        if card_type == "attack":
            _assert_true(card_id, int(card.get("base_damage", 0)) > 0, "Attack must have base_damage > 0.")
            _assert_true(card_id, target_type == "enemy", "Attack must target an enemy in current 120-card set.")
        var expected_target = "enemy" if (card_type == "attack" or TraitSystem.is_enemy_trait(str(card.get("attribute_trait", "")))) else "self"
        _assert_true(card_id, target_type == expected_target, "target_type mismatch. Expected %s, got %s." % [expected_target, target_type])
        if role == "基本攻撃" or role == "決着技":
            _assert_true(card_id, card_type == "attack", "%s must be Attack." % role)
        if role == "基本防御" or role == "手札循環" or role == "補助":
            _assert_true(card_id, card_type == "skill", "%s must be Skill." % role)
        if role == "継続効果":
            _assert_true(card_id, card_type == "power", "継続効果 must be Power.")
            _assert_true(card_id, str(card.get("continuous_effect", "")) in VALID_CONTINUOUS_EFFECTS, "継続効果 missing/invalid continuous_effect.")

        var hand_action = str(card.get("hand_action", ""))
        if role == "手札循環":
            _assert_true(card_id, hand_action != "", "手札循環 card must define hand_action.")
            _assert_true(card_id, int(card.get("draw_count", 0)) > 0, "手札循環 card must draw cards.")
        else:
            _assert_true(card_id, hand_action == "", "Only 手札循環 cards should define hand_action in current 120-card set.")
        if hand_action != "":
            _assert_true(card_id, VALID_HAND_ACTIONS.has(hand_action), "Invalid hand_action: %s" % hand_action)
            _assert_true(card_id, int(card.get("select_count", 0)) > 0, "hand_action requires select_count > 0.")
            _assert_true(card_id, int(card.get("draw_count", 0)) > 0, "Current hand_action cards must draw before selection.")
        if card.has("conditional_hand_action"):
            _assert_true(card_id, VALID_HAND_ACTIONS.has(str(card.get("conditional_hand_action", ""))), "Invalid conditional_hand_action.")
            _assert_true(card_id, int(card.get("conditional_select_count", 0)) > 0, "conditional_hand_action requires conditional_select_count > 0.")


        var continuous = str(card.get("continuous_effect", ""))
        if continuous != "":
            continuous_count += 1
            _assert_true(card_id, VALID_CONTINUOUS_EFFECTS.has(continuous), "Unknown continuous_effect: %s" % continuous)

        if bool(card.get("iai_compatible", false)):
            iai_count += 1
            _assert_true(card_id, weapon == "刀" and role == "決着技", "Only Katana finishers may be Iai-compatible.")
            _assert_true(card_id, bool(card.get("execution_on_sheathed", false)), "Iai finisher must carry execution_on_sheathed.")

        attr_counts[attr] = int(attr_counts.get(attr, 0)) + 1
        weapon_counts[weapon] = int(weapon_counts.get(weapon, 0)) + 1
        role_counts[role] = int(role_counts.get(role, 0)) + 1

    for attr in ATTRIBUTE_COUNTS.keys():
        _assert_true("ATTR_COUNT", int(attr_counts.get(attr, 0)) == int(ATTRIBUTE_COUNTS[attr]), "%s expected %d cards, got %d." % [attr, ATTRIBUTE_COUNTS[attr], attr_counts.get(attr, 0)])
    for weapon in WEAPON_COUNTS.keys():
        _assert_true("WEAPON_COUNT", int(weapon_counts.get(weapon, 0)) == int(WEAPON_COUNTS[weapon]), "%s expected %d cards, got %d." % [weapon, WEAPON_COUNTS[weapon], weapon_counts.get(weapon, 0)])
    for role in ROLE_COUNTS.keys():
        _assert_true("ROLE_COUNT", int(role_counts.get(role, 0)) == int(ROLE_COUNTS[role]), "%s expected %d cards, got %d." % [role, ROLE_COUNTS[role], role_counts.get(role, 0)])

    _assert_true("CONTINUOUS_COUNT", continuous_count == 11, "Expected 11 continuous-effect cards, got %d." % continuous_count)
    _assert_true("INDIVIDUALITY_COUNT", individuality_count == 0, "Legacy weapon individuality exceptions must be 0 in v1.7.0.")
    for action_name in WEAPON_TRAIT_ACTION_COUNTS.keys():
        _assert_true("ACTION_COUNT_%s" % action_name, int(weapon_action_counts.get(action_name, 0)) == int(WEAPON_TRAIT_ACTION_COUNTS[action_name]), "%s expected %d cards, got %d." % [action_name, WEAPON_TRAIT_ACTION_COUNTS[action_name], weapon_action_counts.get(action_name, 0)])
    _assert_true("IAI_COUNT", iai_count == 3, "Expected 3 Iai finishers, got %d." % iai_count)

    var deck = db.create_prototype_deck()
    _assert_true("DECK", deck.size() == 24, "Prototype deck must contain 24 cards, got %d." % deck.size())

func _fresh_battle() -> BattleController:
    var battle = BattleController.new()
    battle.start_battle()
    battle.hand.clear()
    battle.draw_pile.clear()
    battle.discard_pile.clear()
    battle.resolving_card = {}
    battle.pending_hand_selection = {"mode": "", "remaining": 0}
    battle.current_mana = BattleController.BASE_MANA
    battle.player_block = 0
    battle.combat_over = false
    battle.victory = false
    return battle

func _add_card(battle: BattleController, card_id: String) -> bool:
    return battle.add_debug_card_to_hand(card_id)

func _run_runtime_scenarios() -> void:
    _scenario_basic_attack()
    _scenario_sword_dynamic_target()
    _scenario_precision_block_ignore()
    _scenario_vulnerable_reapply()
    _scenario_flurry()
    _scenario_charge()
    _scenario_magic_sword_same_card_activation()
    _scenario_sheathed_execution()
    _scenario_explosion_threshold()
    _scenario_pre_use_condition_lock()
    _scenario_magic_orb_threshold()
    _scenario_swift_cost()
    _scenario_slow_intent()
    _scenario_continuous_register_after_own_threshold()
    _scenario_discard_selection()
    _scenario_bottom_selection()

func _scenario_basic_attack() -> void:
    var name = "C001 CONSUME while 流転OFF / Mana / attribute gain"
    var b = _fresh_battle()
    _add_card(b, "C001")
    var ok = b.use_card(0, 0)
    var enemy = b.get_enemy(0)
    if ok and int(enemy.get("hp", -1)) == 18 and b.current_mana == 2 and not bool(b.weapon_traits["流転"]) and int(b.attribute_traits["剛力"]) == 1 and b.discard_pile.size() == 1:
        _scenario_ok(name)
    else:
        _scenario_fail(name, "Expected HP18/Mana2/流転OFF/剛力1/discard1.")

func _scenario_sword_dynamic_target() -> void:
    var name = "C002 流転 defense dynamically requires enemy target"
    var b = _fresh_battle()
    b.weapon_traits["流転"] = true
    _add_card(b, "C002")
    var target_type = b.get_effective_target_type(0)
    var ok = b.use_card(0, 0)
    var enemy = b.get_enemy(0)
    if target_type == "enemy" and ok and b.player_block == 6 and int(enemy.get("hp", -1)) == 21 and not bool(b.weapon_traits["流転"]):
        _scenario_ok(name, "Block6 + bonus damage3")
    else:
        _scenario_fail(name, "Expected dynamic enemy target, Block6, enemy HP21, 流転OFF.")

func _scenario_precision_block_ignore() -> void:
    var name = "C003 精密 Block Ignore"
    var b = _fresh_battle()
    b.weapon_traits["精密"] = true
    b.enemies[2]["block"] = 6
    _add_card(b, "C003")
    var ok = b.use_card(0, 2)
    var enemy = b.get_enemy(2)
    if ok and int(enemy.get("hp", -1)) == 32 and int(enemy.get("block", -1)) == 6 and int(enemy.get("vulnerable", 0)) == 0 and not bool(b.weapon_traits["精密"]):
        _scenario_ok(name)
    else:
        _scenario_fail(name, "Expected boss HP32, Block6 unchanged, 脆弱0, 精密OFF.")

func _scenario_vulnerable_reapply() -> void:
    var name = "Existing 脆弱 applies to full Rapier Attack then is re-applied"
    var b = _fresh_battle()
    b.weapon_traits["精密"] = true
    b.enemies[0]["vulnerable"] = 1
    _add_card(b, "C003")
    var ok = b.use_card(0, 0)
    var enemy = b.get_enemy(0)
    if ok and int(enemy.get("hp", -1)) == 12 and int(enemy.get("vulnerable", 0)) == 1:
        _scenario_ok(name, "10×1.25=floor12; old consumed; new 脆弱1")
    else:
        _scenario_fail(name, "Expected enemy HP12 and 脆弱1 after reapply.")

func _scenario_flurry() -> void:
    var name = "C005 連刃 same-damage second hit"
    var b = _fresh_battle()
    b.weapon_traits["連刃"] = true
    _add_card(b, "C005")
    var ok = b.use_card(0, 0)
    var enemy = b.get_enemy(0)
    if ok and int(enemy.get("hp", -1)) == 14 and not bool(b.weapon_traits["連刃"]):
        _scenario_ok(name, "5 + 5 = 10")
    else:
        _scenario_fail(name, "Expected enemy HP14 and 連刃OFF after use.")

func _scenario_charge() -> void:
    var name = "C007 重撃 basic +50%"
    var b = _fresh_battle()
    b.weapon_traits["重撃"] = true
    _add_card(b, "C007")
    var ok = b.use_card(0, 0)
    var enemy = b.get_enemy(0)
    if ok and int(enemy.get("hp", -1)) == 9 and not bool(b.weapon_traits["重撃"]):
        _scenario_ok(name, "10×1.5=15")
    else:
        _scenario_fail(name, "Expected enemy HP9 and 重撃OFF.")

func _scenario_magic_sword_same_card_activation() -> void:
    var name = "C045 SET 魔導ON without same-card self-consumption"
    var b = _fresh_battle()
    _add_card(b, "C045")
    var ok = b.use_card(0, 0)
    if ok and bool(b.weapon_traits["魔導"]) and int(b.attribute_traits["帯電"]) == 2 and int(b.get_enemy(0).get("hp", -1)) == 21:
        _scenario_ok(name, "魔導OFF→ON; same card remains 帯電+2")
    else:
        _scenario_fail(name, "Expected 魔導ON, 帯電2, enemy HP21.")

    var consume_name = "C009 CONSUME 魔導ON adds +2 attribute gain"
    var c = _fresh_battle()
    c.weapon_traits["魔導"] = true
    _add_card(c, "C009")
    var consume_ok = c.use_card(0, 0)
    if consume_ok and not bool(c.weapon_traits["魔導"]) and int(c.attribute_traits["剛力"]) == 3 and int(c.get_enemy(0).get("hp", -1)) == 16:
        _scenario_ok(consume_name, "剛力1+魔導2=3; 魔導OFF")
    else:
        _scenario_fail(consume_name, "Expected 魔導OFF, 剛力3, enemy HP16.")

func _scenario_sheathed_execution() -> void:
    var name = "C012 納刀 Cost0 + Boss execution"
    var b = _fresh_battle()
    b.weapon_traits["納刀"] = true
    b.enemies[2]["hp"] = 16
    b.enemies[2]["block"] = 0
    _add_card(b, "C012")
    var preview = b.get_effective_cost(0)
    var mana_before = b.current_mana
    var ok = b.use_card(0, 2)
    var enemy = b.get_enemy(2)
    if ok and preview == 0 and b.current_mana == mana_before and int(enemy.get("hp", -1)) == 0 and not bool(b.weapon_traits["納刀"]):
        _scenario_ok(name)
    else:
        _scenario_fail(name, "Expected Cost0, Mana unchanged, Boss HP0, 納刀OFF.")

func _scenario_explosion_threshold() -> void:
    var name = "C017 爆発 threshold + Fire generation bonus"
    var b = _fresh_battle()
    var traits: Dictionary = b.enemies[0].get("attribute_traits", {}).duplicate(true)
    traits["爆発"] = 2
    b.enemies[0]["attribute_traits"] = traits
    _add_card(b, "C017")
    var ok = b.use_card(0, 0)
    var enemy = b.get_enemy(0)
    if ok and int(enemy.get("hp", -1)) == 14 and int(enemy.get("attribute_traits", {}).get("爆発", 0)) == 4:
        _scenario_ok(name, "Attack3 + threshold explosion7")
    else:
        _scenario_fail(name, "Expected enemy HP14 and 爆発4.")

func _scenario_pre_use_condition_lock() -> void:
    var name = "Use-before condition is locked before same-card trait gain"
    var b = _fresh_battle()
    b.attribute_traits["帯電"] = 2
    _add_card(b, "C037")
    var ok = b.use_card(0, -1)
    if ok and b.player_block == 6 and int(b.attribute_traits["帯電"]) == 3:
        _scenario_ok(name, "C037 does not receive its +2 Block from the 帯電1 it gains later")
    else:
        _scenario_fail(name, "Expected Block6 and 帯電3.")

func _scenario_magic_orb_threshold() -> void:
    var name = "魔珠 threshold restores Mana"
    var b = _fresh_battle()
    b.attribute_traits["魔珠"] = 2
    b.current_mana = 1
    var ok = b.add_debug_attribute_trait("魔珠", 1)
    if ok and int(b.attribute_traits["魔珠"]) == 3 and b.current_mana == 2:
        _scenario_ok(name)
    else:
        _scenario_fail(name, "Expected 魔珠3 and Mana2.")

func _scenario_swift_cost() -> void:
    var name = "疾風 threshold grants Cost-1 and consumes on nonzero Cost"
    var b = _fresh_battle()
    b.attribute_traits["疾風"] = 2
    b.add_debug_attribute_trait("疾風", 1)
    _add_card(b, "C001")
    var preview = b.get_effective_cost(0)
    var ok = b.use_card(0, 0)
    if ok and preview == 0 and b.current_mana == 3 and b.swift_cost_reduction_charges == 0:
        _scenario_ok(name)
    else:
        _scenario_fail(name, "Expected Cost0, Mana3, 疾風 charge consumed.")

func _scenario_slow_intent() -> void:
    var name = "鈍化 updates Intent preview"
    var b = _fresh_battle()
    b.add_debug_enemy_attribute_trait(0, "鈍化", 3)
    var label = b.get_enemy_intent_display_label(0)
    if label == "Attack 2":
        _scenario_ok(name, "Attack4 → Attack2")
    else:
        _scenario_fail(name, "Expected 'Attack 2', got '%s'." % label)

func _scenario_continuous_register_after_own_threshold() -> void:
    var name = "C016 engine registers after its own explosion threshold"
    var b = _fresh_battle()
    var traits: Dictionary = b.enemies[0].get("attribute_traits", {}).duplicate(true)
    traits["爆発"] = 2
    b.enemies[0]["attribute_traits"] = traits
    _add_card(b, "C016")
    var ok = b.use_card(0, 0)
    var enemy = b.get_enemy(0)
    var engine = int(b.continuous_effects.get("fire_first_explosion_bonus", 0))
    if ok and int(enemy.get("hp", -1)) == 19 and engine == 2:
        _scenario_ok(name, "Own threshold explosion remains 5; engine becomes active afterward")
    else:
        _scenario_fail(name, "Expected enemy HP19 and fire engine=2.")

func _scenario_discard_selection() -> void:
    var name = "C006 Draw2 → Discard1 pauses and resumes resolution"
    var b = _fresh_battle()
    b.draw_pile = [b.database.create_card_copy("C001"), b.database.create_card_copy("C002")]
    b.hand = [b.database.create_card_copy("C006"), b.database.create_card_copy("C001")]
    var ok = b.use_card(0, -1)
    var pending = b.is_hand_selection_active()
    var selected_ok = b.select_hand_for_pending(0) if pending else false
    if ok and pending and selected_ok and not b.is_hand_selection_active() and b.discard_pile.size() == 2 and b.resolving_card.is_empty():
        _scenario_ok(name)
    else:
        _scenario_fail(name, "Expected pending Discard1, then resolving card + selected card in discard.")

func _scenario_bottom_selection() -> void:
    var name = "C109 Draw2 → Bottom1 selection"
    var b = _fresh_battle()
    b.draw_pile = [b.database.create_card_copy("C001"), b.database.create_card_copy("C002")]
    b.hand = [b.database.create_card_copy("C109"), b.database.create_card_copy("C005")]
    var ok = b.use_card(0, -1)
    var pending = b.is_hand_selection_active()
    var selected_id = str(b.hand[0].get("id", "")) if not b.hand.is_empty() else ""
    var selected_ok = b.select_hand_for_pending(0) if pending else false
    var bottom_id = str(b.draw_pile[0].get("id", "")) if not b.draw_pile.is_empty() else ""
    if ok and pending and selected_ok and selected_id != "" and bottom_id == selected_id and not b.is_hand_selection_active():
        _scenario_ok(name)
    else:
        _scenario_fail(name, "Expected selected hand card to become draw-pile bottom and resolution to finish.")
