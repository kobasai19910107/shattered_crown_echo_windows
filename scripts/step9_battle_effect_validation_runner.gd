extends SceneTree

# Run with Godot 4.7.2:
# godot --headless --path <project> --script res://scripts/step9_battle_effect_validation_runner.gd
var ok_count: int = 0
var fails: Array[String] = []

func _initialize() -> void:
    var b: BattleController = BattleController.new()
    var sample_deck: Array = []
    for i in range(24):
        sample_deck.append("C001")
    b.start_battle(191900, sample_deck, "standard_trio")
    _check("battle starts", not b.combat_over and b.get_official_card_count() == 120)
    if b.combat_over:
        _finish()
        return

    var count_action: Dictionary = {"SET": 0, "CONSUME": 0, "NEUTRAL": 0}
    var powers: int = 0
    for i in range(1, 121):
        var cid: String = "C%03d" % i
        var c: Dictionary = b.database.get_card_copy(cid)
        _check("card exists %s" % cid, not c.is_empty())
        if c.is_empty():
            continue
        count_action[str(c.get("weapon_trait_action", "NEUTRAL"))] += 1
        if str(c.get("card_type", "")) == "power":
            powers += 1
            _check("Power not CONSUME %s" % cid, str(c.get("weapon_trait_action", "")) != "CONSUME")
            _check("Power common engine %s" % cid, bool(c.get("step9_power_trait_engine", false)))
    _check("45/45/30", count_action["SET"] == 45 and count_action["CONSUME"] == 45 and count_action["NEUTRAL"] == 30)
    _check("Power 11", powers == 11)
    _check("C046 Cost2", int(b.database.get_card_copy("C046").get("cost", -1)) == 2)
    _check("C072 now enemy Attack", str(b.database.get_card_copy("C072").get("target_type", "")) == "enemy" and str(b.database.get_card_copy("C072").get("card_type", "")) == "attack")

    # C010 installation: initial gain is NOT accelerated; subsequent first card each turn is +1.
    b.attribute_traits["剛力"] = 0
    b.power_trait_engines.clear()
    b.resolving_card = b.database.get_card_copy("C010")
    b._gain_player_attribute_trait("剛力", 1, b.resolving_card)
    _check("Power own gain excluded", b.get_attribute_trait("剛力") == 1)
    b._register_continuous_effect(b.resolving_card)
    b.resolving_card = b.database.get_card_copy("C001")
    b._gain_player_attribute_trait("剛力", 1, b.resolving_card)
    _check("Power first gain +1", b.get_attribute_trait("剛力") == 3)
    b._gain_player_attribute_trait("剛力", 1, b.resolving_card)
    _check("Power only once this turn", b.get_attribute_trait("剛力") == 4)
    b.resolving_card = {}

    # C028 repeatable SET after first 鈍化 gain each turn.
    b.power_trait_engines = [{"id": "C028", "trait": "鈍化", "last_used_turn": -1}]
    b.enemies[0]["attribute_traits"]["鈍化"] = 0
    b.weapon_traits["精密"] = false
    b.resolving_card = b.database.get_card_copy("C027")
    b._gain_enemy_attribute_trait(0, "鈍化", 1, b.resolving_card)
    _check("C028 slow +1 and precision reSET", b.get_enemy_attribute_trait(0, "鈍化") == 2 and bool(b.weapon_traits["精密"]))
    b.resolving_card = {}

    # C106 repeatable SET after 魔珠 gain even after a prior CONSUME.
    b.power_trait_engines = [{"id": "C106", "trait": "魔珠", "last_used_turn": -1}]
    b.attribute_traits["魔珠"] = 0
    b.weapon_traits["魔導"] = false
    b.resolving_card = b.database.get_card_copy("C105")
    b._gain_player_attribute_trait("魔珠", 1, b.resolving_card)
    _check("C106 magic +1 and reSET", b.get_attribute_trait("魔珠") == 2 and bool(b.weapon_traits["魔導"]))
    b.resolving_card = {}

    # C083 turn-start auto sheathe against a cursed living enemy.
    b.power_trait_engines = [{"id": "C083", "trait": "呪印", "last_used_turn": -1}]
    b.enemies[0]["attribute_traits"]["呪印"] = 1
    b.weapon_traits["納刀"] = false
    b._player_turn_start(false)
    _check("C083 cursed turn-start sheathe", bool(b.weapon_traits["納刀"]))

    # C004 valid salvage targets must be physical Attack only.
    b.discard_pile = [b.database.get_card_copy("C003"), b.database.get_card_copy("C014")]
    b.hand.clear()
    b.resolving_card = b.database.get_card_copy("C004")
    b.resolving_card["_resolved_target_enemy_index"] = -1
    _check("C004 starts conditional salvage", b._begin_salvage(true, "finish"))
    _check("C004 excludes non physical", b.get_salvage_selectable_indices().size() == 1 and b.get_salvage_selectable_indices()[0] == 0)
    _check("C004 recovers selected discard", b.select_discard_for_pending(0) and b.hand.size() == 1 and str(b.hand[0]["id"]) == "C003")

    # C074 must Salvage → Draw1 → Bottom1 without the currently resolving card as a candidate.
    b.discard_pile = [b.database.get_card_copy("C015")]
    b.draw_pile = [b.database.get_card_copy("C001")]
    b.hand.clear()
    b.resolving_card = b.database.get_card_copy("C074")
    b.resolving_card["_resolved_target_enemy_index"] = 0
    _check("C074 salvage begins", b._begin_salvage(false, "C074_draw_bottom"))
    _check("C074 salvage and bottom pending", b.select_discard_for_pending(0) and str(b.pending_hand_selection.get("mode", "")) == "bottom" and b.hand.size() == 2)
    _check("C074 bottom resolves", b.select_hand_for_pending(0) and b.resolving_card.is_empty())

    # C108 salvage after its 魔珠 threshold gain; otherwise Draw fallback.
    b.power_trait_engines.clear()
    b.attribute_traits["魔珠"] = 2
    b.draw_pile = [b.database.get_card_copy("C001")]
    b.discard_pile = [b.database.get_card_copy("C009")]
    b.hand.clear()
    b.resolving_card = b.database.get_card_copy("C108")
    b.resolving_card["_resolved_target_enemy_index"] = -1
    b._finish_resolving_card()
    _check("C108 threshold salvage pending", b.is_salvage_selection_active())
    _check("C108 choose and finalize", b.select_discard_for_pending(0) and b.resolving_card.is_empty())

    # C084 post-hit Curse must be applied only if target survives; with no Power +1 = one.
    b.enemies[0]["hp"] = 999
    b.enemies[0]["max_hp"] = 999
    b.enemies[0]["attribute_traits"]["呪印"] = 2
    b.hand = [b.database.get_card_copy("C084")]
    b.current_mana = 3
    b.weapon_traits["納刀"] = false
    _check("C084 is payable and targetable", b.can_use_card(0))
    b.use_card(0, 0)
    _check("C084 attack then Curse1", b.get_enemy_attribute_trait(0, "呪印") == 3)

    # C072: now a targetable Iai Attack that costs zero when sheathed.
    b.enemies[0]["hp"] = 999
    b.enemies[0]["max_hp"] = 999
    b.hand = [b.database.get_card_copy("C072")]
    b.current_mana = 3
    b.weapon_traits["納刀"] = true
    _check("C072 Iai preview Cost0", b.get_effective_cost(0) == 0 and b.get_effective_target_type(0) == "enemy")
    b.use_card(0, 0)
    _check("C072 consumes sheathe", not bool(b.weapon_traits["納刀"]))

    # Power is once per card-copy per battle; deployed cards never re-enter discard/draw.
    var installed_before: int = b.power_zone.size()
    b.hand = [b.database.get_card_copy("C010")]
    b.current_mana = 3
    var discard_before: int = b.discard_pile.size()
    b.use_card(0)
    _check("Power moves to deployed zone", b.power_zone.size() == installed_before + 1)
    _check("Power not added to discard", b.discard_pile.size() == discard_before)
    _check("Power engine installs", not b.power_trait_engines.is_empty())

    _finish()

func _check(label: String, passed: bool) -> void:
    if passed:
        ok_count += 1
    else:
        fails.append(label)

func _finish() -> void:
    print("STEP9_RUNTIME_VALIDATION PASS=%d FAIL=%d" % [ok_count, fails.size()])
    for msg in fails:
        push_error(msg)
    quit(0 if fails.is_empty() else 1)
