extends SceneTree

var checks: int=0
var failures: Array[String]=[]

func expect(message: String, ok: bool) -> void:
    checks+=1
    if not ok:
        failures.append(message)
        printerr("FAIL "+message)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    if OS.get_environment("SCE_HUB_ISOLATED_TEST")!="1":
        printerr("Requires SCE_HUB_ISOLATED_TEST=1 and a private user:// directory")
        quit(2)
        return
    var run=Region1RunController.new()
    run.save_path="user://hub_merchant_loadout_fixture.json"
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    var initial: Dictionary=helper.make_items(run.roller,783010)
    helper.free()
    expect("initial six equipment",run.adopt_initial(initial))
    expect("24 card deck",run.roller.inspect_deck(run.items_from_state()).deck.size()==24)
    var original: Dictionary=run.state.loadout.duplicate(true)
    var extra: Dictionary=run.roller.generate_item(str(run.roller.get_templates_for_slot("offhand")[0].EquipmentID),994011)
    extra.instance_id="EXTRA_OFFHAND_994011"
    var next: Dictionary=run.state.duplicate(true)
    next.inventory[extra.instance_id]=extra
    expect("add spare",run._commit(next))
    var target: Dictionary=original.duplicate(true)
    target["offhand"]=extra.instance_id
    expect("single-transaction equip six",run.equip_loadout(target))
    expect("swap only offhand",run.state.loadout==target)
    var reloaded=Region1RunController.new()
    reloaded.save_path=run.save_path
    expect("six slot save reload",reloaded.load_saved() and reloaded.state.loadout==target)
    var invalid: Dictionary=target.duplicate(true)
    invalid["offhand"]=str(target.head)
    var snapshot: String=JSON.stringify(run.state)
    expect("reject cross slot",not run.equip_loadout(invalid))
    expect("failed equip atomic",snapshot==JSON.stringify(run.state))
    next=run.state.duplicate(true)
    next.forge_pending={"uid":extra.instance_id,"slot":0,"choices":["C001","C002"]}
    run.state=next
    expect("forbid pending forge",not run.equip_loadout(original))
    run.state=JSON.parse_string(snapshot)
    expect("merchant first stock",run.ensure_hub_shop())
    expect("three valid choices",run.state.hub_stock.size()==3)
    for item in run.state.hub_stock:
        expect("legal merchant gear",run.roller.validate_item(item) and EquipmentSpecialEffectPolicy.validate_effects(item,false))
    var stock_json: String=JSON.stringify(run.state.hub_stock)
    expect("reenter shop retains stock",run.ensure_hub_shop() and JSON.stringify(run.state.hub_stock)==stock_json)
    reloaded=Region1RunController.new()
    reloaded.save_path=run.save_path
    expect("merchant stock survives reload",reloaded.load_saved() and JSON.stringify(reloaded.state.hub_stock)==stock_json)
    next=run.state.duplicate(true)
    next.base_gold=10000
    expect("grant test gold",run._commit(next))
    var bought: Dictionary=run.state.hub_stock[0].duplicate(true)
    var price: int=run.hub_buy_price(bought)
    var gold_before: int=int(run.state.base_gold)
    expect("purchase item",run.buy_hub_item(0,str(bought.instance_id)))
    expect("price and sold slot",int(run.state.base_gold)==gold_before-price and run.state.hub_stock[0].is_empty())
    expect("purchase persisted",run.state.inventory.has(str(bought.instance_id)))
    expect("no double purchase",not run.buy_hub_item(0,str(bought.instance_id)))
    expect("cannot sell equipped",not run.sell_hub_item(str(run.state.loadout.main_weapon)))
    gold_before=int(run.state.base_gold)
    var sell_price: int=run.hub_sell_price(bought)
    expect("sell owned spare",run.sell_hub_item(str(bought.instance_id)))
    expect("sale credits gold and deletes owned item",int(run.state.base_gold)==gold_before+sell_price and not run.state.inventory.has(str(bought.instance_id)))
    gold_before=int(run.state.base_gold)
    expect("paid merchant refresh",run.refresh_hub_shop())
    expect("refresh preserves bought gear and costs 100G",int(run.state.base_gold)==gold_before-100 and run.state.hub_stock.size()==3)
    reloaded=Region1RunController.new()
    reloaded.save_path=run.save_path
    expect("final reload",reloaded.load_saved() and reloaded.state.loadout==target and reloaded.state.hub_stock.size()==3)
    # Pre-merchant saves omit both optional keys; do not reject or overwrite them.
    next=run.state.duplicate(true)
    next.erase("hub_stock")
    next.erase("hub_shop_revision")
    expect("legacy merchant fields optional",run.valid_state(next))
    print("HUB_MERCHANT_LOADOUT checks=%d failures=%d"%[checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
