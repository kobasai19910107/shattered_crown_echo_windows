extends SceneTree

const RollerScript = preload("res://scripts/step8_equipment_roller.gd")
const LoadoutBuilderScript = preload("res://scripts/loadout_builder.gd")
const SLOT_IDS := ["main_weapon", "offhand", "head", "body", "hands", "feet"]

var failures: Array[String] = []
var passed := 0

func _initialize() -> void:
    var roller = RollerScript.new()
    _assert("policy 108 templates / 120 cards / 60 pairs", roller.load_data())
    if not failures.is_empty():
        _finish()
        return
    var full_decks := 0
    for template_id in roller.templates.keys():
        for seed_value in range(10):
            var item: Dictionary = roller.generate_item(str(template_id), 144000 + seed_value)
            _assert("generated item %s seed%d" % [str(template_id), seed_value], not item.is_empty() and roller.validate_item(item))
    for code in ["SWORD", "RAPIER", "DAGGER", "GREATSWORD", "MAGICSWORD", "KATANA"]:
        var main: Dictionary = roller.generate_item("EQ-WEAPON-%s-R" % code, 61234)
        _assert("main complete SET/CONSUME %s" % code, roller.validate_item(main))
        if main.is_empty():
            continue
        var context = {"weapon": main.get("affinity_weapon", ""), "attribute": main.get("rolled_attribute", ""), "core_cards": main.get("fixed_cards", [])}
        var pack: Dictionary = {"main_weapon": main}
        for i in range(1, 6):
            var slot = SLOT_IDS[i]
            var options = roller.get_templates_for_slot(slot)
            var item: Dictionary = {}
            for template in options:
                if str(template.get("Rarity", "")) == "Rare":
                    item = roller.generate_item(str(template.get("EquipmentID", "")), 90000 + i, context)
                    break
            if item.is_empty():
                failures.append("missing test item %s %s" % [code, slot])
                break
            pack[slot] = item
        if pack.size() == 6:
            var result = roller.inspect_deck(pack)
            _assert("deck 24 cards %s" % code, int(result.get("card_count", 0)) == 24)
            _assert("main SC in 24 deck %s" % code, int(result.get("completed_sc", 0)) >= 1)
            # Verify the exact generated 4-card snapshots are accepted by the existing LoadoutBuilder.
            var builder = LoadoutBuilderScript.new()
            _assert("builder data %s" % code, builder.load_data())
            for slot_id in SLOT_IDS:
                var minted: Dictionary = pack[slot_id]
                builder.equipment_db.items[str(minted["instance_id"])] = minted.duplicate(true)
                builder.set_equipment(slot_id, str(minted["instance_id"]))
            _assert("battle-compatible deck %s" % code, builder.is_valid() and builder.build_deck_ids().size() == 24)
            full_decks += 1
    _assert("six valid representative loadouts", full_decks == 6)
    _finish()

func _assert(label: String, condition: bool) -> void:
    if condition:
        passed += 1
    else:
        failures.append(label)

func _finish() -> void:
    print("STEP8 EQUIPMENT STATIC/RUNTIME VALIDATION PASS=%d FAIL=%d" % [passed, failures.size()])
    for msg in failures:
        push_error(msg)
    quit(0 if failures.is_empty() else 1)
