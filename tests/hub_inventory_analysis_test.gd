extends SceneTree
var passed: int=0
var failures: Array=[]
func check(label: String,ok: bool) -> void:
    if ok:passed+=1
    else:failures.append(label);print("FAIL "+label)
func _initialize() -> void:call_deferred("run_tests")
func make_items(roller: Step8EquipmentRoller,seed_value: int) -> Dictionary:
    var items: Dictionary={}
    var context: Dictionary={}
    for i in range(HubDeckAnalyzer.SLOTS.size()):
        var slot: String=HubDeckAnalyzer.SLOTS[i]
        var templates: Array=roller.get_templates_for_slot(slot)
        var item: Dictionary=roller.generate_item(str(templates[i%templates.size()].EquipmentID),seed_value+i*1009,context)
        items[slot]=item
        if i==0:context={"weapon":item.affinity_weapon,"attribute":item.rolled_attribute,"core_cards":item.fixed_cards.duplicate()}
    return items
func run_tests() -> void:
    var analyzer=HubDeckAnalyzer.new()
    check("official data loaded",analyzer.loaded and analyzer.cards.size()==120)
    check("10 attributes / 6 weapons / 8 roles",analyzer.categories("attribute").size()==10 and analyzer.categories("weapon").size()==6 and analyzer.categories("role").size()==8)
    var master_before: String=JSON.stringify(analyzer.cards)
    for id in analyzer.cards:
        check("formal text "+str(id),analyzer.card_description(str(id)).contains(str(analyzer.cards[id].text)))
    var inventory: Dictionary={}
    var loadout: Dictionary={}
    for seed_value in range(24):
        var items: Dictionary=make_items(analyzer.roller,773100+seed_value*10000)
        var input_before: String=JSON.stringify(items)
        var report: Dictionary=analyzer.analyze(items)
        check("24 cards seed%d"%seed_value,report.complete and int(report.card_count)==24)
        var expected_deck: Array=[]
        var hp: int=0
        for slot in HubDeckAnalyzer.SLOTS:
            var item: Dictionary=items[slot]
            expected_deck.append_array(item.cards);hp+=int(item.get("effective_hp",item.base_hp))
            inventory[str(item.instance_id)]=item.duplicate(true)
            if seed_value==0:loadout[slot]=str(item.instance_id)
        check("fixed ordered deck seed%d"%seed_value,report.deck==expected_deck and int(report.hp)==hp)
        for field in ["attribute","weapon","role","card_type"]:
            var expected: Dictionary={}
            for value in analyzer.categories(field):expected[value]=0
            for id in expected_deck:expected[str(analyzer.cards[str(id)][field])]+=1
            check("copy distributions %s seed%d"%[field,seed_value],expected==report.distribution[field])
        var core: Dictionary=analyzer.roller.inspect_deck(items)
        check("existing inspect metrics seed%d"%seed_value,int(report.completed_sc)==int(core.completed_sc) and int(report.orphan)==int(core.orphan) and int(report.cycle)==int(core.cycle) and int(report.salvage)==int(core.salvage) and int(report.cost2_plus)==int(core.cost2_plus))
        check("pair details consistent seed%d"%seed_value,report.completed_pairs.size()==int(core.completed_sc))
        var orphan_expected: int=0
        for pair in analyzer.roller.pairs:
            if str(pair.get("status",""))!="SC":continue
            var has_set: bool=expected_deck.has(str(pair.get("set_id","")))
            var has_consume: bool=expected_deck.has(str(pair.get("con_id","")))
            if has_set!=has_consume:orphan_expected+=1
        check("orphan_pairs supplied seed%d"%seed_value,report.has("orphan_pairs"))
        check("orphan_pairs values seed%d"%seed_value,int(report.get("orphan_pairs",-1))==orphan_expected)
        check("analyzer no item mutation seed%d"%seed_value,JSON.stringify(items)==input_before)
    var state: Dictionary={"inventory":inventory,"loadout":loadout}
    var state_before: String=JSON.stringify(state)
    var rows: Array=HubInventoryQuery.rows(state,{},analyzer.cards)
    check("144 distinct owned instances",rows.size()==144 and rows.map(func(row):return row.uid).size()==inventory.size())
    var unique: Dictionary={}
    for row in rows:unique[row.uid]=true
    check("no duplicate UID",unique.size()==144)
    check("equipped source loadout",HubInventoryQuery.rows(state,{"equipped":true},analyzer.cards).size()==6)
    for key in ["slot","rarity","rolled_attribute","card_attribute","card_weapon"]:
        var values: Array=HubDeckAnalyzer.SLOTS if key=="slot" else (["Common","Rare","Epic","Legendary"] if key=="rarity" else analyzer.categories("weapon" if key=="card_weapon" else "attribute"))
        for value in values:
            var expected: Array=[]
            for uid in inventory:
                var item: Dictionary=inventory[uid]
                var match_value: bool=false
                if key.begins_with("card_"):
                    for id in item.cards:
                        if str(analyzer.cards[str(id)][key.trim_prefix("card_")])==str(value):match_value=true
                else:match_value=str(item.get(key,""))==str(value)
                if match_value:expected.append(str(uid))
            expected.sort()
            var filtered: Array=HubInventoryQuery.rows(state,{key:value},analyzer.cards).map(func(row):return row.uid)
            filtered.sort()
            check("filter %s %s"%[key,str(value)],filtered==expected)
    var first_uid: String=str(rows[0].uid)
    check("search by instance ID",HubInventoryQuery.rows(state,{"search":first_uid},analyzer.cards).size()==1)
    check("empty search result",HubInventoryQuery.rows(state,{"search":"NONEXISTENT_EQUIPMENT_123"},analyzer.cards).is_empty())
    check("sorting repeatable",JSON.stringify(rows)==JSON.stringify(HubInventoryQuery.rows(state,{},analyzer.cards)))
    rows[0].item.cards[0]="INVALID_COPY"
    check("query copy detached",JSON.stringify(state)==state_before)
    var tie_item: Dictionary=inventory[first_uid].duplicate(true)
    var tie_state: Dictionary={"inventory":{"B":tie_item.duplicate(true),"A":tie_item.duplicate(true)},"loadout":{}}
    check("sort final UID tie break",HubInventoryQuery.rows(tie_state,{},analyzer.cards).map(func(row):return row.uid)==["A","B"])
    var sorting: Dictionary={"inventory":{},"loadout":{}}
    for entry in [["C","Common",100,"A"],["L","Legendary",1,"Z"],["R","Rare",10,"B"]]:
        var item: Dictionary=tie_item.duplicate(true)
        item.instance_id=entry[0];item.rarity=entry[1];item.effective_hp=entry[2];item.name=entry[3]
        sorting.inventory[entry[0]]=item
    check("rarity descending primary",HubInventoryQuery.rows(sorting,{},analyzer.cards).map(func(row):return row.uid)==["L","R","C"])
    check("HP descending primary",HubInventoryQuery.rows(sorting,{"sort":"hp"},analyzer.cards).map(func(row):return row.uid)==["C","R","L"])
    check("name ascending primary",HubInventoryQuery.rows(sorting,{"sort":"name"},analyzer.cards).map(func(row):return row.uid)==["C","R","L"])
    var empty_report: Dictionary=analyzer.analyze({})
    check("empty deck always has orphan_pairs key",empty_report.has("orphan_pairs") and int(empty_report.orphan_pairs)==0)
    var partial: Dictionary=make_items(analyzer.roller,914123)
    partial.erase("feet")
    var incomplete: Dictionary=analyzer.analyze(partial)
    check("missing slot not supplemented",not incomplete.complete and incomplete.card_count==20 and incomplete.missing_slots==["feet"])
    var unknown: Dictionary=make_items(analyzer.roller,914123)
    unknown.main_weapon.cards[0]="UNKNOWN_ID";unknown.main_weapon.fixed_cards[0]="UNKNOWN_ID"
    var unresolved: Dictionary=analyzer.analyze(unknown)
    check("unknown ID visible without invented effect",not unresolved.complete and unresolved.warnings.has("未解決カードID：UNKNOWN_ID") and analyzer.card_description("UNKNOWN_ID").contains("効果を表示できません"))
    check("unknown ID retained in deck",unresolved.deck.size()==24 and unresolved.deck.has("UNKNOWN_ID"))
    check("master immutable",JSON.stringify(analyzer.cards)==master_before)
    print("HUB_ANALYSIS PASS=%d FAIL=%d"%[passed,failures.size()]);quit(0 if failures.is_empty() else 1)
