extends SceneTree

# Run (from project root, with Godot 4.7.x installed):
# godot --headless --path . -s res://tests/drop_duplicate_validation_runner.gd -- --offers=5000
# Checks all five drop sources, the first-choice base RNG stream, save migration,
# independent coop-member history, legal equipment, and repeated fixed seeds.

const SOURCES := ["battle", "elite", "boss", "chest", "shop"]
const SLOTS := ["main_weapon", "offhand", "head", "body", "hands", "feet"]
var assertions: int = 0
var failures: Array[String] = []
var report: Dictionary = {}

func _check(label: String, result: bool) -> void:
    if result:
        assertions += 1
    else:
        failures.append(label)

func _initialize() -> void:
    var offers: int = 5000
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--offers="):
            offers = maxi(1, int(arg.trim_prefix("--offers=")))

    var controller := Region1RunController.new()
    _check("data loaded: 108 templates / 120 cards / 60 pairs", controller.roller.templates.size() == 108 and controller.roller.cards.size() == 120 and controller.roller.pairs.size() == 60)
    _check("legacy history is optional", controller.valid_state(controller.state))
    var malformed: Dictionary = controller.state.duplicate(true)
    malformed.recent_drop_pairs = ["head|C002|C001"]
    _check("reversed pair history is invalid", not controller.valid_state(malformed))
    malformed.recent_drop_pairs = []
    for i in range(14):
        DropDuplicatePolicy.record_acquired(malformed, {"slot":"head","random_cards":["C002","C001"]})
    _check("history FIFO stays at 12", malformed.recent_drop_pairs.size() == 12)
    _check("order-independent canonicalization", DropDuplicatePolicy.pair_key({"slot":"head","random_cards":["C001","C002"]}) == DropDuplicatePolicy.pair_key({"slot":"head","random_cards":["C002","C001"]}))
    _check("different slot is different key", DropDuplicatePolicy.pair_key({"slot":"head","random_cards":["C001","C002"]}) != DropDuplicatePolicy.pair_key({"slot":"body","random_cards":["C002","C001"]}))

    var old_file: String = "user://sce_drop_history_old_test.json"
    var new_file: String = "user://sce_drop_history_new_test.json"
    var old_payload: Dictionary = controller.state.duplicate(true)
    old_payload.erase("recent_drop_pairs")
    _check("write legacy-shaped save", Region1Save.write(old_file, old_payload))
    var legacy := Region1RunController.new()
    legacy.save_path = old_file
    _check("load old save", legacy.load_saved() and legacy.state.recent_drop_pairs.size() == 0)
    DropDuplicatePolicy.record_acquired(legacy.state, {"slot":"body","random_cards":["C001","C002"]})
    _check("write new save", Region1Save.write(new_file, legacy.state))
    var restored := Region1RunController.new()
    restored.save_path = new_file
    _check("new history roundtrip", restored.load_saved() and restored.state.recent_drop_pairs == legacy.state.recent_drop_pairs)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(old_file))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(new_file))

    var coop := CoopCampaignController.new()
    DropDuplicatePolicy.record_acquired(coop.members[0].state, {"slot":"head","random_cards":["C001","C002"]})
    _check("coop members own separate histories", coop.members[1].state.recent_drop_pairs.size() == 0)
    var coop_copy := CoopCampaignController.new()
    _check("coop import history roundtrip", coop_copy.import_state(coop.export_state()) and coop_copy.members[0].state.recent_drop_pairs.size() == 1 and coop_copy.members[1].state.recent_drop_pairs.size() == 0)

    # Retry uses the same initial run RNG stream and produces a stable outcome.
    var first_rng := RandomNumberGenerator.new()
    first_rng.seed = 1234567
    var second_rng := RandomNumberGenerator.new()
    second_rng.seed = 1234567
    var fixed_state: Dictionary = {"sequence":0,"run":{"seed":1234567},"recent_drop_pairs":["head|C001|C002"]}
    var first_offer: Array = controller._offer(fixed_state.duplicate(true), "battle", first_rng)
    var second_offer: Array = controller._offer(fixed_state.duplicate(true), "battle", second_rng)
    _check("fixed seed exactly reproducible", first_offer == second_offer and first_rng.state == second_rng.state)

    var generator := InitialDeckGenerator.new()
    _check("unchanged initial generator data loads", generator.load_data())
    var templates: Dictionary = {"main_weapon":"EQ-WEAPON-SWORD-R", "offhand":"EQ-OFFHAND-SCABBARD-R", "head":"EQ-HEAD-CIRCLET-R", "body":"EQ-BODY-COAT-R", "hands":"EQ-HANDS-GLOVES-R", "feet":"EQ-FEET-BOOTS-R"}
    for n in range(20):
        var start_deck: Dictionary = generator.generate_initial_loadout(templates, 20261008 + n)
        var repeated: Dictionary = generator.generate_initial_loadout(templates, 20261008 + n)
        _check("initial 24 reproducible %d" % n, start_deck == repeated and (not bool(start_deck.get("ok", false)) or generator.verify_synergy(start_deck.items).get("ok", false)))

    # Baseline is the unfiltered _drop() repeated three times. Both paths use
    # identical seeds and keep a separate history of actually selected items.
    var overall_card_ids: Dictionary = {}
    var overall_template_ids: Dictionary = {}
    for kind in SOURCES:
        var baseline_history: Array = []
        var updated_history: Array = []
        var base_duplicate: int = 0
        var new_duplicate: int = 0
        var base_recent: int = 0
        var new_recent: int = 0
        var base_nonweapon_pair: int = 0
        var new_nonweapon_pair: int = 0
        var base_nonweapon: int = 0
        var new_nonweapon: int = 0
        var base_card_ids: Dictionary = {}
        var new_card_ids: Dictionary = {}
        var base_template_ids: Dictionary = {}
        var new_template_ids: Dictionary = {}
        var base_total: int = 0
        var new_total: int = 0
        for n in range(offers):
            var seed: int = 9100000 + n * 167 + SOURCES.find(kind) * 1000003
            var base_rng := RandomNumberGenerator.new()
            base_rng.seed = seed
            var new_rng := RandomNumberGenerator.new()
            new_rng.seed = seed
            var baseline_state: Dictionary = {"sequence":0,"run":{"seed":seed},"recent_drop_pairs":baseline_history.duplicate()}
            var modified_state: Dictionary = {"sequence":0,"run":{"seed":seed},"recent_drop_pairs":updated_history.duplicate()}
            var baseline_offer: Array = []
            for j in range(3):
                baseline_offer.append(controller._drop(baseline_state, kind, base_rng))
            var improved_offer: Array = controller._offer(modified_state, kind, new_rng)
            _check("original run RNG preserved %s offer %d" % [kind, n], base_rng.state == new_rng.state)
            _check("three offers always returned %s offer %d" % [kind, n], improved_offer.size() == 3)
            var before_base: Dictionary = {}
            var before_new: Dictionary = {}
            for j in range(3):
                var original: Dictionary = baseline_offer[j]
                var improved: Dictionary = improved_offer[j]
                var base_key: String = DropDuplicatePolicy.pair_key(original)
                var improved_key: String = DropDuplicatePolicy.pair_key(improved)
                if before_base.has(base_key): base_duplicate += 1
                if before_new.has(improved_key): new_duplicate += 1
                before_base[base_key] = true
                before_new[improved_key] = true
                if baseline_history.has(base_key): base_recent += 1
                if updated_history.has(improved_key): new_recent += 1
                _check("legal original %s/%d/%d" % [kind,n,j], controller.roller.validate_item(original))
                _check("legal improved %s/%d/%d" % [kind,n,j], controller.roller.validate_item(improved))
                base_template_ids[str(original.equipment_id)] = true
                new_template_ids[str(improved.equipment_id)] = true
                overall_template_ids[str(improved.equipment_id)] = true
                for id in original.random_cards: base_card_ids[str(id)] = true
                for id in improved.random_cards:
                    new_card_ids[str(id)] = true
                    overall_card_ids[str(id)] = true
                if str(original.slot) != "main_weapon":
                    base_nonweapon += 1
                    if _is_catalog_pair(controller.roller, original.random_cards): base_nonweapon_pair += 1
                if str(improved.slot) != "main_weapon":
                    new_nonweapon += 1
                    if _is_catalog_pair(controller.roller, improved.random_cards): new_nonweapon_pair += 1
                base_total += 1
                new_total += 1
            var acquired_original: Dictionary = baseline_offer[n % 3]
            var acquired_improved: Dictionary = improved_offer[n % 3]
            baseline_state.recent_drop_pairs = baseline_history.duplicate()
            modified_state.recent_drop_pairs = updated_history.duplicate()
            DropDuplicatePolicy.record_acquired(baseline_state, acquired_original)
            DropDuplicatePolicy.record_acquired(modified_state, acquired_improved)
            baseline_history = baseline_state.recent_drop_pairs.duplicate()
            updated_history = modified_state.recent_drop_pairs.duplicate()
        report[kind] = {
            "offers":offers,"candidate_count":new_total,
            "baseline_duplicate_percent":100.0*float(base_duplicate)/float(base_total),
            "updated_duplicate_percent":100.0*float(new_duplicate)/float(new_total),
            "baseline_recent12_percent":100.0*float(base_recent)/float(base_total),
            "updated_recent12_percent":100.0*float(new_recent)/float(new_total),
            "baseline_nonweapon_pair_percent":100.0*float(base_nonweapon_pair)/maxf(1.0,float(base_nonweapon)),
            "updated_nonweapon_pair_percent":100.0*float(new_nonweapon_pair)/maxf(1.0,float(new_nonweapon)),
            "baseline_cards":base_card_ids.size(),"updated_cards":new_card_ids.size(),
            "baseline_templates":base_template_ids.size(),"updated_templates":new_template_ids.size()
        }
        _check("reduced 3-choice duplicate %s" % kind, new_duplicate < base_duplicate)
        _check("reduced recent12 repeat %s" % kind, new_recent < base_recent)
        _check("nonweapon pair rate remains near original %s" % kind, absf(float(report[kind].updated_nonweapon_pair_percent) - float(report[kind].baseline_nonweapon_pair_percent)) < 5.0)
    _check("all 120 cards reachable across sources", overall_card_ids.size() == 120)
    _check("all 108 templates reachable across sources", overall_template_ids.size() == 108)
    print("DROP DUPLICATE VALIDATION: ", JSON.stringify(report, "  "))
    print("Assertions PASS=%d FAIL=%d" % [assertions, failures.size()])
    for error in failures:
        push_error(error)
    quit(0 if failures.is_empty() else 1)

func _is_catalog_pair(roller: Step8EquipmentRoller, card_ids: Array) -> bool:
    var ids: Array[String] = [str(card_ids[0]), str(card_ids[1])]
    ids.sort()
    for p in roller.pairs:
        var pair_ids: Array[String] = roller._pair_ids(p)
        pair_ids.sort()
        if pair_ids == ids:
            return true
    return false
