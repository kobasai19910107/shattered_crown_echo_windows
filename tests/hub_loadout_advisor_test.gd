extends SceneTree

var passed: int = 0
var failures: Array = []

func check(title: String, ok: bool) -> void:
    if ok: passed += 1
    else:
        failures.append(title)
        print("FAIL "+title)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var analyzer := HubDeckAnalyzer.new()
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    var inventory: Dictionary = {}
    var current: Dictionary = {}
    for fixture_index in range(5):
        var items: Dictionary = helper.make_items(analyzer.roller, 341701+fixture_index*11000)
        for slot in HubDeckAnalyzer.SLOTS:
            var item: Dictionary = items[slot]
            var uid: String = str(item.get("instance_id", ""))
            inventory[uid] = item
            if fixture_index==0:
                current[slot] = uid
    helper.free()
    var snapshot: String = JSON.stringify(inventory)
    var selected_before: String = JSON.stringify(current)
    var advisor := HubLoadoutAdvisor.new()
    var recommended: Array = advisor.suggest(inventory, current, analyzer)
    check("multiple distinct proposals",recommended.size()>=2)
    check("no mutation of source inventory",JSON.stringify(inventory)==snapshot)
    check("no mutation of current equipment",JSON.stringify(current)==selected_before)
    var signatures: Dictionary = {}
    for rec in recommended:
        var uids: Dictionary = rec.uids
        var chunks: PackedStringArray = []
        for slot in HubDeckAnalyzer.SLOTS:
            var uid: String = str(uids.get(slot, ""))
            chunks.append(uid)
            check("recommended owned slot",inventory.has(uid) and str(inventory[uid].get("slot", ""))==slot)
        var signature: String = "|".join(chunks)
        check("distinct recommendation",not signatures.has(signature))
        signatures[signature] = true
        check("24 card valid",int(rec.analysis.card_count)==24 and bool(rec.analysis.complete))
        check("matches existing analyzer",int(rec.analysis.completed_sc)==int(analyzer.analyze(advisor._items(uids, inventory)).completed_sc))
    var incomplete: Dictionary = inventory.duplicate(true)
    for uid in incomplete.keys():
        if str(incomplete[uid].get("slot", "")) == "feet": incomplete.erase(uid)
    check("missing slot no guess",advisor.suggest(incomplete,current,analyzer).is_empty())
    print("HUB_LOADOUT_ADVISOR PASS=%d FAIL=%d" % [passed, failures.size()])
    quit(0 if failures.is_empty() else 1)
