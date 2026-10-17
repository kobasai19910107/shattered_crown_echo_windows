extends SceneTree

var passes: int = 0
var fails: Array[String] = []

func check(label: String, ok: bool) -> void:
    if ok:
        passes += 1
    else:
        fails.append(label)
        push_error("FAIL: " + label)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var db = CardDatabase.new()
    check("120-card master loads", db.load_data() and db.get_official_card_count() == 120)
    var roller = Step8EquipmentRoller.new()
    check("equipment policy loads", roller.load_data())
    var items: Dictionary = {}
    for i in range(EquipmentCardOrigin.SLOTS.size()):
        var slot: String = EquipmentCardOrigin.SLOTS[i]
        var templates: Array = roller.get_templates_for_slot(slot)
        check("template exists " + slot, not templates.is_empty())
        if templates.is_empty():
            quit(2)
            return
        var item: Dictionary = roller.generate_item(str(templates[0].EquipmentID), 42500 + i)
        item["instance_id"] = "TEST_%s" % slot
        items[slot] = item
    var ids: Array = roller.inspect_deck(items).deck
    check("24-card exact deck", ids.size() == 24)
    var cards: Array = db.create_deck_from_ids(ids)
    var before: String = JSON.stringify(cards)
    check("full equipment mapping succeeds", EquipmentCardOrigin.attach(cards, ids, items))
    var seen: Dictionary = {}
    for i in range(cards.size()):
        var slot: String = EquipmentCardOrigin.SLOTS[int(i / 4)]
        check("card ID unchanged %d" % i, str(cards[i].id) == str(ids[i]))
        check("source item is correct %d" % i, str(cards[i].source_equipment_uid) == "TEST_%s" % slot)
        check("source slot is correct %d" % i, str(cards[i].source_slot) == slot)
        var instance: String = str(cards[i].card_instance_uid)
        check("card-instance unique %d" % i, not seen.has(instance))
        seen[instance] = true
    var alternate: Dictionary = items.duplicate(true)
    alternate["head"]["cards"][0] = "C999"
    var unmapped: Array = db.create_deck_from_ids(ids)
    check("reject mismatched deck", not EquipmentCardOrigin.attach(unmapped, ids, alternate))
    check("atomic fallback does not tag any cards", JSON.stringify(unmapped) == before)
    # Two equipment slots can supply the SAME card ID, but must never share an instance uid.
    var synthetic: Dictionary = {}
    var duplicate_ids: Array = []
    for i in range(EquipmentCardOrigin.SLOTS.size()):
        var slot: String = EquipmentCardOrigin.SLOTS[i]
        synthetic[slot] = {"instance_id": "SYN_%s" % slot,"slot":slot,"cards": ["C001", "C002", "C003", "C004"]}
        duplicate_ids.append_array(synthetic[slot].cards)
    var duplicates: Array = db.create_deck_from_ids(duplicate_ids)
    check("duplicate-ID deck tags successfully", EquipmentCardOrigin.attach(duplicates, duplicate_ids, synthetic))
    check("identical card IDs have separate sources", duplicates[0].id == duplicates[4].id and duplicates[0].card_instance_uid != duplicates[4].card_instance_uid)
    var b = BattleController.new()
    check("start real Region1 encounter", b.start_region1(123400, ids, ["R1-N01"], items, 30))
    var rng_before: int = b.battle_rng.state
    check("battle RNG seed unchanged", b.active_seed == 123400)
    var all_battle_cards: Array = b.hand + b.draw_pile + b.discard_pile
    check("battle cards are 24", all_battle_cards.size() == 24)
    for card in all_battle_cards:
        check("battle card has source", str(card.get("source_equipment_uid", "")) != "")
    var vanilla = BattleController.new()
    check("start untagged baseline", vanilla.start_region1(123400, ids, ["R1-N01"], {}, 30))
    check("card shuffle unchanged", vanilla.hand.map(func(c):return c.id) == b.hand.map(func(c):return c.id) and vanilla.draw_pile.map(func(c):return c.id) == b.draw_pile.map(func(c):return c.id))
    check("RNG stream unchanged", vanilla.battle_rng.state == b.battle_rng.state)
    check("debug card has no fake equipment source", b.add_debug_card_to_hand("C001") and not b.hand[-1].has("source_equipment_uid"))
    b.hand.pop_back()
    var used: bool = false
    for i in range(b.hand.size()):
        var c: Dictionary = b.hand[i]
        if int(c.get("select_count", 0)) > 0 or int(c.get("conditional_select_count", 0)) > 0:
            continue
        if not b.can_use_card(i):
            continue
        var target: int = 0 if b.get_effective_target_type(i) == "enemy" else -1
        var instance: String = str(c.get("card_instance_uid", ""))
        if b.use_card(i, target):
            for moved_card in b.discard_pile + b.power_zone:
                if str(moved_card.get("card_instance_uid", "")) == instance:
                    used = true
            break
    check("card origin survives use into discard/power", used)
    # Exact save roundtrip, including source IDs and RNG state.
    var saved_rng: int = b.battle_rng.state
    var saved: Dictionary = b.export_region1_state()
    var restored = BattleController.new()
    check("battle save/import", restored.import_region1_state(saved))
    check("RNG roundtrip", restored.battle_rng.state == saved_rng)
    check("hand origin roundtrip", JSON.stringify(restored.hand) == JSON.stringify(b.hand))
    check("draw origin roundtrip", JSON.stringify(restored.draw_pile) == JSON.stringify(b.draw_pile))
    # Compatibility: old saved cards may not have any source keys.
    var legacy: Dictionary = saved.duplicate(true)
    for area in ["hand","draw_pile","discard_pile","power_zone"]:
        for c in legacy[area]:
            c.erase("source_equipment_uid")
            c.erase("source_slot")
            c.erase("card_instance_uid")
    var legacy_restored = BattleController.new()
    check("old saved cards load", legacy_restored.import_region1_state(legacy))
    check("old cards have no made-up source", legacy_restored.hand.is_empty() or not legacy_restored.hand[0].has("source_equipment_uid"))
    # Manually configured U effects, with no live loot-generation change.
    var main_item: Dictionary = items["main_weapon"].duplicate(true)
    main_item["special_effects"] = [{"effect_id":"U01"},{"effect_id":"U02"},{"effect_id":"U03"},{"effect_id":"U04"},{"effect_id":"U05"},{"effect_id":"U06"},{"effect_id":"U07"},{"effect_id":"U08"},{"effect_id":"U09"},{"effect_id":"U10"}]
    var equipped: Dictionary = items.duplicate(true)
    equipped["main_weapon"] = main_item
    var opt = BattleController.new()
    check("start opt-in effect encounter", opt.start_region1(123401, ids, ["R1-N01"], equipped, 30))
    opt.campaign_status["LastType"] = "skill"
    var c: Dictionary = db.create_card_copy(str(ids[0]))
    c["cost"] = 1 # isolate U01/U02 without triggering U03 in this synthetic fixture
    c["source_equipment_uid"] = str(main_item.instance_id)
    c["source_slot"] = "main_weapon"
    c["card_instance_uid"] = "%s:main_weapon:0" % str(main_item.instance_id)
    check("local pool isolated", opt._local_generic_effect_ids(c).size() == 10)
    check("attack bonus +5 cap", opt._local_attack_bonus(c) == 5)
    check("same turn capped per effect", opt._local_attack_bonus(c) == 0)
    opt.turn_number += 1
    check("one-battle U01 spent / per-turn U02 reset", opt._local_attack_bonus(c) > 0)
    opt.campaign_status["LastType"] = "attack"
    check("Block bonus clamped +5", opt._local_skill_block_bonus(c, 5) == 5)
    var foreign: Dictionary = c.duplicate(true)
    foreign["source_equipment_uid"] = "TEST_offhand"
    foreign["source_slot"] = "offhand"
    check("foreign card cannot use effect", opt._local_generic_effect_ids(foreign).is_empty())
    check("U08 grants one eligible additional draw", opt._local_extra_draw(c, 1) == 1)
    check("U08 single battle limit", opt._local_extra_draw(c, 1) == 0)
    c["_equipment_paid_cost"] = 2
    c["card_type"] = "power"
    var mana_before: int = opt.current_mana
    var block_before: int = opt.player_block
    opt._local_after_card(c)
    check("U09 postpayment Mana +1", opt.current_mana == mana_before + 1)
    check("U10 installation Block +4", opt.player_block == block_before + 4)
    opt._local_after_card(c)
    check("U09/U10 do not repeat", opt.current_mana == mana_before + 1 and opt.player_block == block_before + 4)
    var single_effect_item: Dictionary = main_item.duplicate(true)
    single_effect_item["special_effects"] = [{"effect_id": "U07"}]
    opt.active_equipment_loadout["main_weapon"] = single_effect_item
    opt.campaign_status["LastType"] = "attack"
    check("U07 attack-to-skill Block +2", opt._local_skill_block_bonus(c, 5) == 2)
    check("U07 same-turn limited", opt._local_skill_block_bonus(c, 5) == 0)
    print("EQUIPMENT_ORIGIN_GENERIC_TEST: %d PASS, %d FAIL" % [passes, fails.size()])
    quit(0 if fails.is_empty() else 1)
