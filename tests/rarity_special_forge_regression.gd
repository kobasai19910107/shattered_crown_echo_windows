extends SceneTree

# Run only in a private user:// sandbox; never use production save files.
var checks: int=0
var errors: Array[String]=[]

func check(label: String, passed: bool) -> void:
    checks+=1
    if not passed:
        errors.append(label)
        printerr("FAIL: "+label)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    if OS.get_environment("SCE_HUB_ISOLATED_TEST")!="1":
        printerr("Set SCE_HUB_ISOLATED_TEST=1 in a private user data directory")
        quit(2)
        return
    var c=Region1RunController.new()
    c.save_path="user://rarity_special_forge_regression.json"
    var commons: int=0
    for t in c.roller.templates.values():
        if str(t.Rarity)=="Common":
            commons+=1
            check("Common has 0 sockets: "+str(t.EquipmentID),int(t.SocketCap)==0 and int(t.InitialSocketMax)==0 and int(t.InitialSocketMin)==0)
    check("27 Common templates",commons==27)
    var rng=RandomNumberGenerator.new()
    rng.seed=100345
    for i in range(40):
        var next=c.state.duplicate(true)
        next["hub_shop_revision"]=i
        c._roll_hub_stock(next)
        check("hub merchant has 3 choices",next.hub_stock.size()==3)
        for item in next.hub_stock:
            check("hub merchant never offers Legendary",str(item.get("rarity",""))!="Legendary")
        # In-run shop uses independent weights, checked after a run starts.
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new()
    var six: Dictionary=helper.make_items(c.roller,547198)
    helper.free()
    check("fixture initial inventory adopted",c.adopt_initial(six))
    check("start test run",c.begin(1038971))
    var run_state=c.state.duplicate(true)
    var shop_offers: Array=c._offer(run_state,"shop",rng)
    for item in shop_offers:
        check("in-run merchant never offers Legendary",str(item.get("rarity",""))!="Legendary")
    # Re-open hub for the forge regression without changing the test save.
    var hub_state=c.state.duplicate(true)
    hub_state.phase="hub"
    hub_state.run={}
    check("reset test fixture hub",c._commit(hub_state))
    var state=c.state.duplicate(true)
    state.base_gold=15000
    state.materials=100
    var uid: String=""
    var effect_index: int=0
    for id in state.inventory.keys():
        var item: Dictionary=state.inventory[id]
        if str(item.rarity)=="Common":continue
        var pool: Array[String]=EquipmentSpecialEffectPolicy.eligible_ids(item)
        if pool.size()>=4:
            uid=str(id)
            item.special_effects=[{"effect_id":pool[0]}]
            effect_index=0
            break
    check("affix eligible fixture exists",uid!="")
    if uid=="":
        quit(1)
        return
    check("persist fixture",c._commit(state))
    var first_name: String=str(c.state.inventory[uid].special_effects[0].effect_id)
    for attempt in range(3):
        var pre_gold: int=int(c.state.base_gold)
        var pre_mat: int=int(c.state.materials)
        check("special reroll opens 2 choices",c.forge(uid,"special_reroll",effect_index))
        check("pay 250G material1",int(c.state.base_gold)==pre_gold-250 and int(c.state.materials)==pre_mat-1)
        check("candidate exactly 2",c.state.forge_pending.choices.size()==2)
        check("unique candidates",c.state.forge_pending.choices[0]!=c.state.forge_pending.choices[1])
        check("pending checkpoint valid",c.valid_state(c.state))
        var fresh=Region1RunController.new()
        fresh.save_path=c.save_path
        check("pending survives reload",fresh.load_saved() and fresh.state.forge_pending==c.state.forge_pending)
        var select: int=-1 if attempt==0 else attempt-1
        check("confirm candidate or keep",c.resolve_forge(select))
        check("3-use cumulative count",int(c.state.inventory[uid].special_reroll_count)==attempt+1)
        check("pending cleared",c.state.forge_pending.is_empty())
        check("save remains valid",c.valid_state(c.state))
        if attempt==0:
            check("keep leaves current affix intact",str(c.state.inventory[uid].special_effects[0].effect_id)==first_name)
    check("fourth special reroll forbidden",not c.forge(uid,"special_reroll",0))
    var reloaded=Region1RunController.new()
    reloaded.save_path=c.save_path
    check("3-use cap survives reload",reloaded.load_saved() and int(reloaded.state.inventory[uid].special_reroll_count)==3)
    # v1.9.1 saves did not contain special_reroll_count and Common could have 1 socket.
    var old: Dictionary=c.state.duplicate(true)
    old.inventory[uid].erase("special_reroll_count")
    check("old save reroll counter optional",c.valid_state(old))
    var common_item: Dictionary={"rarity":"Common","socket_count":1,"socket_cap":1}
    var old_snapshot: Dictionary={"inventory":{"OLD":common_item},"hub_stock":[],"run":{}}
    Region1RunController.normalize_legacy_common_sockets(old_snapshot)
    check("old Common socket converted to 0",int(old_snapshot.inventory.OLD.socket_count)==0 and int(old_snapshot.inventory.OLD.socket_cap)==0)
    print("RARITY_SPECIAL_FORGE_TEST checks=%d failures=%d"%[checks,errors.size()])
    quit(0 if errors.is_empty() else 1)
