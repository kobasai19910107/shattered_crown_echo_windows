extends SceneTree

# Run with isolated user:// (e.g. SCE_HUB_ISOLATED_TEST=1 and private APPDATA).
# Tests the button's real claim target; generated equipment is a six-item Common
# fixture. The ranked async generator is separately covered by its runners.
var tests: int = 0
var failures: Array[String] = []

func check(label: String, passed: bool) -> void:
    tests += 1
    if not passed:
        failures.append(label)
        printerr("FAIL: " + label)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    if OS.get_environment("SCE_HUB_ISOLATED_TEST") != "1":
        printerr("Set SCE_HUB_ISOLATED_TEST=1 and use isolated user:// data")
        quit(2)
        return
    root.size = Vector2i(1280, 900)
    var main = load("res://main.tscn").instantiate()
    root.add_child(main)
    for _i in range(6):
        await process_frame
    main._hide_title_screen()
    var ui: Region1RunUI = main.region_run_ui
    var campaign = CampaignController.new()
    campaign.save_path = "user://hub_initial_free_claim_regression.json"
    ui.run = campaign
    ui.hub_page = "home"
    main.step8_items.clear()
    ui.render()
    var claim_button = ui.find_child("HubInitialClaimButton", true, false)
    check("unminted initial claim button exists", claim_button is Button)
    check("unminted button labels automatic generation", claim_button != null and "自動生成" in claim_button.text)
    check("initial status is not falsely marked claimed", not bool(ui.run.state.initial_claimed))

    # Build legal Common fixtures without bypassing the actual six-slot claim.
    var minted: Dictionary = {}
    var context: Dictionary = {}
    for i in range(Region1RunController.SLOTS.size()):
        var slot: String = Region1RunController.SLOTS[i]
        var template_id: String = ""
        for t in main.step8_roller.get_templates_for_slot(slot):
            if str(t.get("Rarity", "")) == "Common":
                template_id = str(t.get("EquipmentID", ""))
                break
        check("Common template for " + slot, template_id != "")
        if template_id == "":
            continue
        var item: Dictionary = main.step8_roller.generate_item(template_id, 550100 + 1009 * i, context)
        check("valid initial item " + slot, not item.is_empty() and main.step8_roller.validate_item(item))
        minted[slot] = item
        if i == 0 and not item.is_empty():
            context = {"weapon": item.affinity_weapon, "attribute": item.rolled_attribute, "core_cards": item.fixed_cards.duplicate()}
    main.step8_items = minted
    ui.render()
    claim_button = ui.find_child("HubInitialClaimButton", true, false)
    check("minted button text distinguishes existing package", claim_button != null and "生成済み" in claim_button.text)
    claim_button.pressed.emit()
    await process_frame
    check("button grants exactly six Common items", ui.run.state.initial_claimed and ui.run.state.loadout.size() == 6 and ui.run.state.inventory.size() == 6)
    check("claim button disappears after success", ui.find_child("HubInitialClaimButton", true, false) == null)
    check("claim gives positive feedback", ui.run.notice.contains("受取しました"))
    var previous: String = JSON.stringify(ui.run.state)
    check("second click cannot claim again", not main._finish_hub_initial_claim())
    check("second click leaves save state unchanged", JSON.stringify(ui.run.state) == previous)
    var restored = CampaignController.new()
    restored.save_path = campaign.save_path
    check("claim survives save reload", restored.load_saved() and restored.state.initial_claimed and restored.state.loadout.size() == 6)
    main.queue_free()
    await process_frame
    print("HUB_INITIAL_FREE_CLAIM_TEST checks=%d failures=%d" % [tests, failures.size()])
    quit(0 if failures.is_empty() else 1)
