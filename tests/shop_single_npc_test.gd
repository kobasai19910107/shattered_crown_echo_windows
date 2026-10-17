extends SceneTree

# godot --headless --path . -s res://tests/shop_single_npc_test.gd
# Isolated save paths only; the player's real campaign remains untouched.
var successes: int = 0
var failures: Array[String] = []

func assert_test(label: String, passes: bool) -> void:
    if passes:
        successes += 1
    else:
        failures.append(label)
        push_error("SHOP EVENT FAIL: " + label)

func _initialize() -> void:
    call_deferred("run_tests")

func prepare(seed_value: int, save_name: String) -> CampaignController:
    var c := CampaignController.new()
    c.save_path = "user://" + save_name
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    var items: Dictionary=helper.make_items(c.roller,seed_value)
    helper.free()
    assert_test("initial six equipment " + save_name,c.adopt_initial(items))
    assert_test("begin " + save_name,c.begin(seed_value))
    var state: Dictionary=c.state.duplicate(true)
    state.run.routes=["shop"]
    assert_test("force shop route fixture " + save_name,c._commit(state))
    return c

func find_button(root_node: Node,needle: String) -> Button:
    for child in root_node.get_children():
        if child is Button and needle in str(child.text): return child
        var found: Button=find_button(child,needle)
        if found != null: return found
    return null

func has_text(root_node: Node,needle: String) -> bool:
    for child in root_node.get_children():
        if child is Label and needle in str(child.text): return true
        if has_text(child,needle): return true
    return false

func run_tests() -> void:
    var merchant: CampaignController=prepare(28711,"sce_single_npc_merchant.json")
    assert_test("merchant chosen",merchant.choose_route(0,"merchant"))
    assert_test("merchant shop has three offers",merchant.state.run.get("shop_npc","")=="merchant" and merchant.state.run.stock.size()==3)
    var merchant_before: String=JSON.stringify(merchant.state)
    assert_test("merchant refuses healing",not merchant.service("heal") and merchant_before==JSON.stringify(merchant.state))
    assert_test("merchant refuses support",not merchant.service("block") and merchant_before==JSON.stringify(merchant.state))
    assert_test("merchant reopens from save",merchant.load_saved() and merchant.state.run.shop_npc=="merchant")

    var ui: Region1RunUI=Region1RunUI.new()
    root.add_child(ui)
    ui.run=merchant
    ui.build(Node.new())
    assert_test("merchant heading",has_text(ui,"遺品商 —"))
    assert_test("merchant has buy option",find_button(ui,"280G")!=null)
    assert_test("merchant has refresh",find_button(ui,"商品更新")!=null)
    assert_test("merchant has no priest action",find_button(ui,"35%回復")==null and find_button(ui,"全回復")==null)
    assert_test("merchant uses no tabs",ui.find_child("ShopNPCSections",true,false)==null)
    ui.queue_free()
    await process_frame

    var priest: CampaignController=prepare(28712,"sce_single_npc_priest.json")
    assert_test("priest chosen",priest.choose_route(0,"priest"))
    assert_test("priest has no shop offers",priest.state.run.get("shop_npc","")=="priest" and priest.state.run.stock.is_empty())
    var priest_before: String=JSON.stringify(priest.state)
    assert_test("priest refuses buy",not priest.service("buy",0) and priest_before==JSON.stringify(priest.state))
    assert_test("priest refuses refresh",not priest.service("refresh") and priest_before==JSON.stringify(priest.state))
    assert_test("priest reload stable",priest.load_saved() and priest.state.run.shop_npc=="priest")
    ui=Region1RunUI.new()
    root.add_child(ui)
    ui.run=priest
    ui.build(Node.new())
    assert_test("priest heading",has_text(ui,"僧侶 —"))
    assert_test("priest heals",find_button(ui,"35%回復")!=null and find_button(ui,"全回復")!=null)
    assert_test("priest has no merchant actions",find_button(ui,"280G")==null and find_button(ui,"商品更新")==null)
    assert_test("priest uses no tabs",ui.find_child("ShopNPCSections",true,false)==null)
    ui.queue_free()
    await process_frame
    assert_test("priest room leaves",priest.service("leave") and priest.state.phase=="route" and not priest.state.run.has("shop_npc"))

    # Old saves had a combined shop with stock and no NPC field. It is
    # interpreted as the merchant, preserving the old purchase choices.
    var old_save: Dictionary=merchant.state.duplicate(true)
    old_save.run.erase("shop_npc")
    assert_test("old save still valid",merchant.valid_state(old_save))
    assert_test("legacy merchant saved",merchant._commit(old_save) and merchant.load_saved())
    assert_test("legacy inventory retained",merchant.state.run.stock.size()==3)
    assert_test("legacy refuses priest actions",not merchant.service("full_heal"))

    # Coop P2 consumes a local RNG draw but uses the P1-selected NPC, rather
    # than independently rolling the other NPC for the same shared room.
    var guest: CampaignController=prepare(28713,"sce_single_npc_coop_guest.json")
    assert_test("guest follows host NPC",guest.choose_route(0,str(merchant.state.run.get("shop_npc","merchant"))) and guest.state.run.shop_npc=="merchant")

    for path in [merchant.save_path,priest.save_path,guest.save_path]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("SHOP SINGLE NPC TEST: %d PASS / %d FAIL"%[successes,failures.size()])
    if not failures.is_empty():print(failures)
    quit(0 if failures.is_empty() else 1)
