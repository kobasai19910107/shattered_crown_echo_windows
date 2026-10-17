extends SceneTree

const Generator = preload("res://scripts/initial_deck_generator.gd")
const Fixture = preload("res://tests/initial_deck_ui_fixture.gd")
const SLOTS = ["main_weapon", "offhand", "head", "body", "hands", "feet"]
const DEFAULTS = ["EQ-WEAPON-SWORD-R", "EQ-OFFHAND-SCABBARD-R", "EQ-HEAD-CIRCLET-R", "EQ-BODY-COAT-R", "EQ-HANDS-GLOVES-R", "EQ-FEET-BOOTS-R"]
const TEST_SAVE = "user://step17_validation_only.json"
var passed: int = 0
var failures: Array = []
var exhausted: int = 0
var records: Array = []

func check(label: String, condition: bool) -> void:
    if condition:
        passed += 1
    else:
        failures.append(label)
        print("FAIL " + label)

func json_equal(a, b) -> bool:
    # JSON restores numbers as floats and arrays as untyped Arrays. Compare the
    # persisted representation, not the runtime-only Variant container types.
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func defaults() -> Dictionary:
    var result: Dictionary = {}
    for i in range(6):
        result[SLOTS[i]] = DEFAULTS[i]
    return result

func legacy(g, templates: Dictionary, seed_value: int) -> Dictionary:
    var items: Dictionary = {}
    var context: Dictionary = {}
    for i in range(6):
        var item: Dictionary = g.roller.generate_item(templates[SLOTS[i]], seed_value + i * 1009, context)
        items[SLOTS[i]] = item
        if i == 0:
            context = {"weapon":item["affinity_weapon"], "attribute":item["rolled_attribute"], "core_cards":item["fixed_cards"].duplicate()}
    return items

func validate_result(g, templates: Dictionary, seed_value: int, result: Dictionary) -> void:
    var tag: String = str(seed_value) + "/" + str(templates["main_weapon"])
    if not bool(result.get("ok", false)):
        exhausted += 1
        check(tag + " failure exposes no unverified items", result.get("items", {}) == {} and result.get("status", "") == "EXHAUSTED")
        return
    var items: Dictionary = result["items"]
    check(tag + " legal package", g.validate_package(items))
    check(tag + " actual runtime proof", bool(g.verify_synergy(items).get("ok", false)))
    var baseline: Dictionary = legacy(g, templates, seed_value)
    for slot in SLOTS:
        for field in ["fixed_cards", "rarity", "base_hp", "socket_cap", "special_effect_slots", "special_effects", "affinity_weapon", "rolled_attribute", "equipment_id", "reroll_counts"]:
            check(tag + "/" + slot + "/" + field, items[slot][field] == baseline[slot][field])
        check(tag + " distinct new item namespace", str(items[slot]["instance_id"]).begins_with("STEP17_"))
    var builder = LoadoutBuilder.new()
    check(tag + " builder data", builder.load_data())
    for slot in SLOTS:
        var item: Dictionary = items[slot]
        builder.equipment_db.items[item["instance_id"]] = item.duplicate(true)
        check(tag + " equip " + slot, builder.set_equipment(slot, item["instance_id"]))
    check(tag + " builder24", builder.is_valid() and builder.build_deck_ids().size() == 24)
    var snapshot: Dictionary = builder.get_snapshot()
    var b = BattleController.new()
    b.start_battle(seed_value, builder.build_deck_ids(), "standard_trio", snapshot)
    var initial: Array = b.hand.duplicate(true)
    b.start_battle(seed_value, builder.build_deck_ids(), "standard_trio", snapshot)
    check(tag + " Retry snapshot deterministic", initial == b.hand and snapshot == builder.get_snapshot())

func _initialize() -> void:
    var g = Generator.new()
    check("generator data", g.load_data())
    var baseline_path: String = "user://test_outputs/step15_decks.json"
    var old_report = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
    for n in range(30):
        var seed_value: int = 20261008 + n
        var templates: Dictionary = defaults()
        var old_items: Dictionary = legacy(g, templates, seed_value)
        check("STEP15 exact legacy compatibility " + str(seed_value), g.roller.inspect_deck(old_items)["deck"] == old_report["records"][n]["deck"])
        var result: Dictionary = g.generate_initial_loadout(templates, seed_value)
        validate_result(g, templates, seed_value, result)
        check("default generation succeeds " + str(seed_value), bool(result.get("ok", false)))
        check("deterministic default " + str(seed_value), result == g.generate_initial_loadout(templates, seed_value))
        records.append({"group":"defaults", "seed":seed_value, "status":result["status"], "attempts":result["attempts"], "old_audit":g.roller.inspect_deck(old_items), "new_audit":g.roller.inspect_deck(result.get("items", {})), "evidence":result.get("evidence", {})})
    var rarities: Array = ["Common", "Rare", "Epic", "Legendary"]
    var codes: Array = ["SWORD", "RAPIER", "DAGGER", "GREATSWORD", "MAGICSWORD", "KATANA"]
    var touched: Dictionary = {}
    for code in codes:
        for rarity in rarities:
            for n in range(30):
                var templates: Dictionary = {}
                for slot in SLOTS:
                    var options: Array = []
                    for t in g.roller.get_templates_for_slot(slot):
                        if str(t["Rarity"]) == rarity and (slot != "main_weapon" or str(t["BaseCode"]) == code):
                            options.append(t["EquipmentID"])
                    templates[slot] = options[n % options.size()]
                    touched[templates[slot]] = true
                var seed_value: int = 20261008 + n
                var result: Dictionary = g.generate_initial_loadout(templates, seed_value)
                validate_result(g, templates, seed_value, result)
                records.append({"group":"matrix", "weapon":code, "rarity":rarity, "seed":seed_value, "status":result["status"], "attempts":result["attempts"], "reason":result.get("reason", ""), "audit":g.roller.inspect_deck(result.get("items", {}))})
    check("all108 templates exercised", touched.size() == 108)
    var invalid: Dictionary = defaults()
    invalid["head"] = DEFAULTS[0]
    check("wrong slot rejected", g.generate_initial_loadout(invalid, 1)["status"] == "INVALID_INPUT")
    check("unknown profile rejected", g.generate_initial_loadout(defaults(), 1, "unknown")["status"] == "INVALID_INPUT")
    var bounded: Dictionary = g.generate_initial_loadout(defaults(), 20261009, g.PROFILE_VERSION, 1)
    check("bounded failure never returns unverified items", not bounded["ok"] and bounded["status"] == "EXHAUSTED" and bounded["items"].is_empty())
    _save_and_ui_tests(g)
    var report_file = FileAccess.open("res://step17_validation_results.json", FileAccess.WRITE)
    report_file.store_string(JSON.stringify({"passed":passed, "failures":failures, "exhausted":exhausted, "templates":touched.size(), "records":records}, "  "))
    report_file.close()
    print("STEP17 PASS=%d FAIL=%d EXHAUSTED=%d CASES=%d TEMPLATES=%d" % [passed, failures.size(), exhausted, records.size(), touched.size()])
    quit(0 if failures.is_empty() else 1)

func _fixture(g, save_path: String):
    var ui = Fixture.new()
    ui.step8_roller = g.roller
    ui.step8_save_path = save_path
    ui.loadout_builder = LoadoutBuilder.new()
    ui.loadout_builder.load_data()
    ui.loadout_builder.load_prototype_loadout()
    ui.step8_status = Label.new()
    ui.add_child(ui.step8_status)
    ui.step8_seed_input = SpinBox.new()
    ui.step8_seed_input.max_value = 999999999
    ui.step8_seed_input.value = 20261008
    ui.add_child(ui.step8_seed_input)
    for i in range(6):
        var selector = OptionButton.new()
        selector.add_item(DEFAULTS[i])
        ui.add_child(selector)
        ui.step8_template_selectors[SLOTS[i]] = selector
        ui.step8_template_ids[SLOTS[i]] = [DEFAULTS[i]]
    return ui

func _save_and_ui_tests(g) -> void:
    var ui = _fixture(g, TEST_SAVE)
    ui._on_step8_generate()
    check("UI success generates and writes isolated save", ui.step8_items.size() == 6 and FileAccess.file_exists(TEST_SAVE))
    var expected: Dictionary = ui.step8_items.duplicate(true)
    var saved: String = FileAccess.get_file_as_string(TEST_SAVE)
    check("UI saved exact minted items", json_equal(JSON.parse_string(saved), expected))
    var selected: Dictionary = ui.loadout_builder.selected_by_slot.duplicate(true)
    ui.step8_template_ids["head"] = ["INVALID"]
    ui._on_step8_generate()
    check("UI failed search preserves items, selection and save", ui.step8_items == expected and ui.loadout_builder.selected_by_slot == selected and FileAccess.get_file_as_string(TEST_SAVE) == saved)
    ui.step8_template_ids["head"] = [DEFAULTS[2]]
    ui.step8_save_path = "user://step17_nonexistent_directory/save.json"
    ui._on_step8_generate()
    check("UI failed save preserves current loadout", ui.step8_items == expected and ui.loadout_builder.selected_by_slot == selected and FileAccess.get_file_as_string(TEST_SAVE) == saved)
    ui.step8_save_path = TEST_SAVE
    ui.step8_seed_input.value = 20261009
    ui._on_step8_generate()
    check("atomic overwrite changes persisted package", not json_equal(ui.step8_items, expected) and json_equal(JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)), ui.step8_items))
    expected = ui.step8_items.duplicate(true)
    var restored = _fixture(g, TEST_SAVE)
    restored._step8_restore_items()
    check("new save restore exact", json_equal(restored.step8_items, expected) and restored.loadout_builder.build_deck_ids() == ui.loadout_builder.build_deck_ids())
    restored.loadout_builder.unequip_all()
    restored._step8_restore_items()
    check("equipment switch does not reroll", json_equal(restored.step8_items, expected) and restored.loadout_builder.build_deck_ids() == ui.loadout_builder.build_deck_ids())
    var old_items: Dictionary = legacy(g, defaults(), 20261009)
    check("legacy save write", ui._step8_write_items(old_items))
    restored._step8_restore_items()
    check("legacy save restored without new guarantee or reroll", json_equal(restored.step8_items, old_items))
    ui.free()
    restored.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
