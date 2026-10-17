class_name LoadoutValidationRunner
extends RefCounted

var passed = 0
var failures: Array[String] = []
var lines: Array[String] = []

func _assert(name: String, condition: bool, message: String) -> void:
    if condition:
        passed += 1
        lines.append("PASS  %s" % name)
    else:
        failures.append("[%s] %s" % [name, message])
        lines.append("FAIL  %s — %s" % [name, message])

func run_all() -> Dictionary:
    passed = 0
    failures.clear()
    lines.clear()
    var builder = LoadoutBuilder.new()
    _assert("LOAD_DATA", builder.load_data(), "LoadoutBuilder.load_data failed.")
    if not failures.is_empty():
        return _result()
    var slots = builder.equipment_db.get_slot_ids()
    _assert("SLOT_COUNT", slots.size() == 6, "Expected six equipment slots.")
    _assert("FALLBACK_COUNT", builder.equipment_db.fallback_cards.size() == 4, "Fallback must have four cards.")
    _assert("FALLBACK_HP", builder.equipment_db.fallback_hp_per_slot == 8, "Fallback HP per slot must be 8 in v1.6 prototype.")

    _assert("RARITY_COMMON_0", builder.equipment_db.get_special_effect_slot_count_for_rarity("Common") == 0, "Common prototype effect slots must be 0.")
    _assert("RARITY_RARE_1", builder.equipment_db.get_special_effect_slot_count_for_rarity("Rare") == 1, "Rare prototype effect slots must be 1.")
    _assert("RARITY_EPIC_2", builder.equipment_db.get_special_effect_slot_count_for_rarity("Epic") == 2, "Epic prototype effect slots must be 2.")
    _assert("RARITY_LEGENDARY_3", builder.equipment_db.get_special_effect_slot_count_for_rarity("Legendary") == 3, "Legendary prototype effect slots must be 3.")

    builder.unequip_all()
    var fallback_deck = builder.build_deck_ids()
    _assert("UNEQUIPPED_DECK_24", fallback_deck.size() == 24, "Six empty slots must still build 24 cards.")
    _assert("UNEQUIPPED_VALID", builder.is_valid(), "Unequipped loadout must be valid.")
    _assert("UNEQUIPPED_STRIKE_COUNT", fallback_deck.count("BASIC_STRIKE") == 12, "Expected 12 fallback strikes.")
    _assert("UNEQUIPPED_GUARD_COUNT", fallback_deck.count("BASIC_GUARD") == 12, "Expected 12 fallback guards.")
    _assert("UNEQUIPPED_MAX_HP_48", builder.calculate_player_max_hp() == 48, "Six unequipped fallback slots must total 48 Max HP.")

    builder.load_prototype_loadout()
    _assert("PROTOTYPE_VALID", builder.is_valid(), "Prototype loadout must be valid.")
    _assert("PROTOTYPE_DECK_24", builder.build_deck_ids().size() == 24, "Prototype loadout must build 24 cards.")
    _assert("SNAPSHOT_SIX", builder.get_snapshot().size() == 6, "Snapshot must contain six slots.")
    _assert("PROTOTYPE_MAX_HP_48", builder.calculate_player_max_hp() == 48, "Prototype loadout baseline should total 48 Max HP.")
    var hp_snapshot = builder.get_snapshot()
    for slot_id in slots:
        var slot_snapshot: Dictionary = hp_snapshot.get(slot_id, {})
        _assert("SNAPSHOT_HP_%s" % slot_id, int(slot_snapshot.get("effective_hp", 0)) > 0, "Every loadout snapshot slot needs effective_hp.")
        _assert("SNAPSHOT_RARITY_%s" % slot_id, slot_snapshot.has("rarity"), "Every snapshot slot needs rarity metadata.")
        _assert("SNAPSHOT_EFFECTS_%s" % slot_id, slot_snapshot.has("special_effects"), "Every snapshot slot needs special_effects metadata.")

    var rarity_seen = {"Common": false, "Rare": false, "Epic": false, "Legendary": false}
    for slot_id in slots:
        var candidates = builder.equipment_db.get_items_for_slot(slot_id)
        _assert("CATALOG_%s" % slot_id, not candidates.is_empty(), "Every slot needs at least one prototype item.")
        for item in candidates:
            var item_id = str(item.get("id", "item"))
            var cards: Array = item.get("cards", [])
            var rarity = str(item.get("rarity", ""))
            if rarity_seen.has(rarity):
                rarity_seen[rarity] = true
            _assert("%s_HP_POSITIVE" % item_id, int(item.get("base_hp", 0)) > 0, "Every prototype equipment item needs positive base_hp.")
            _assert("%s_FOUR_CARDS" % item_id, cards.size() == 4, "Each equipment item must contribute exactly four cards.")
            _assert("%s_RARITY_VALID" % item_id, builder.equipment_db.rarity_rules.has(rarity), "Unknown equipment rarity.")
            _assert("%s_EFFECTS_VALID" % item_id, builder.equipment_db.validate_item_special_effects(item_id), "Special effects violate rarity slots or supported effect catalog.")
            var effects: Array = item.get("special_effects", [])
            _assert("%s_EFFECT_SLOT_LIMIT" % item_id, effects.size() <= builder.equipment_db.get_special_effect_slot_count_for_rarity(rarity), "Special effect count exceeds rarity slot limit.")
            for raw_id in cards:
                _assert("%s_%s_EXISTS" % [item_id, str(raw_id)], builder.card_db.cards.has(str(raw_id)), "Equipment card id missing from CardDatabase.")
    for rarity in rarity_seen.keys():
        _assert("RARITY_PRESENT_%s" % rarity, bool(rarity_seen[rarity]), "Prototype catalog should contain at least one item of every rarity for validation.")

    _assert("CROSS_SLOT_REJECT", not builder.set_equipment("head", "EQ_MW_SWORD_01"), "Main Weapon must not be equippable in Head slot.")

    # Runtime smoke: prototype loadout tests HP + rarity special effects together.
    builder.load_prototype_loadout()
    var battle = BattleController.new()
    battle.start_battle(12014, builder.build_deck_ids(), "slime_duo", builder.get_snapshot())
    _assert("RUNTIME_DECK_24", battle.battle_deck_ids.size() == 24, "Battle must receive 24 equipment-generated cards.")
    _assert("RUNTIME_DRAW5", battle.hand.size() == 5, "Default prototype loadout has no first-turn Draw bonus and must Draw5.")
    _assert("RUNTIME_SNAPSHOT", battle.get_playtest_report().get("equipment_loadout", {}).size() == 6, "Telemetry must retain six-slot loadout snapshot.")
    _assert("RUNTIME_MAX_HP", battle.player_max_hp == builder.calculate_player_max_hp(), "Battle Max HP must equal six-slot HP total.")
    _assert("RUNTIME_FULL_HP", battle.player_hp == battle.player_max_hp, "Battle must start at full equipment-derived HP.")
    _assert("RUNTIME_EFFECT_COUNT", battle.equipment_special_effects.size() == 5, "Default prototype loadout should expose five special effects.")
    _assert("RUNTIME_SWORD_TRAIT", bool(battle.weapon_traits.get("流転", false)), "Prototype Sword should set 流転ON at battle start.")
    _assert("RUNTIME_MIGHT_TRAIT", int(battle.attribute_traits.get("剛力", 0)) == 1, "Prototype Assault Gloves should grant 剛力1.")
    _assert("RUNTIME_FORTIFY_TRAIT", int(battle.attribute_traits.get("堅牢", 0)) == 1, "Prototype Fortitude Armor should grant 堅牢1.")
    _assert("RUNTIME_SWIFT_TRAIT", int(battle.attribute_traits.get("疾風", 0)) == 1, "Prototype Tempo Boots should grant 疾風1.")
    _assert("RUNTIME_TURN_BLOCK", battle.player_block == 1, "Prototype Fortitude Armor should grant turn-start Block1.")

    # Legendary smoke: Grace body uses all three prototype effect slots.
    builder.load_prototype_loadout()
    _assert("SET_LEGENDARY_BODY", builder.set_equipment("body", "EQ_BODY_GRACE_01"), "Legendary body should be selectable.")
    var legendary_battle = BattleController.new()
    legendary_battle.start_battle(14001, builder.build_deck_ids(), "slime_duo", builder.get_snapshot())
    _assert("LEGENDARY_EFFECT_COUNT", builder.equipment_db.get_item_special_effects("EQ_BODY_GRACE_01").size() == 3, "Legendary prototype body should use three effect slots.")
    _assert("LEGENDARY_DRAW6", legendary_battle.hand.size() == 6, "Legendary Grace body should make first turn Draw6.")
    _assert("LEGENDARY_MANA4", legendary_battle.current_mana == 4, "Legendary Grace body should make turn-start Mana4.")
    _assert("LEGENDARY_GRACE1", int(legendary_battle.attribute_traits.get("恩寵", 0)) == 1, "Legendary Grace body should grant 恩寵1 at battle start.")
    return _result()

func _result() -> Dictionary:
    return {"ok": failures.is_empty(), "passed": passed, "failed": failures.size(), "failures": failures.duplicate(), "lines": lines.duplicate()}
