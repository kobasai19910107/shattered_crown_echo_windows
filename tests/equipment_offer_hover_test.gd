extends SceneTree

# Run: godot --headless --path . -s res://tests/equipment_offer_hover_test.gd
var passes: int=0
var failures: Array[String]=[]

func check(title: String,condition: bool) -> void:
    if condition:passes+=1
    else:
        failures.append(title)
        push_error("FAIL: "+title)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    root.size=Vector2i(1280,900)
    var panel=EquipmentOfferHoverPanel.new()
    root.add_child(panel)
    await process_frame
    var card_source=CardDatabase.new()
    check("official cards available",card_source.load_data() and card_source.official_card_ids.size()==120)
    var item: Dictionary={
        "equipment_id":"TEST_HOVER","name":"確認用装備","slot":"body",
        "rarity":"Epic","base_hp":21,"effective_hp":24,
        "rolled_attribute":"物理","affinity_weapon":"片手剣",
        "fixed_cards":["C001","C002"],"random_cards":["C003","C004"],
        "cards":["C001","C002","C003","C004"],
        "special_effect_slots":2,
        "special_effects":[{"effect_id":"U01"},{"effect_id":"U02"}]
    }
    var before: String=JSON.stringify(item)
    panel.show_item(item)
    check("preview visible name",panel.heading.text.contains("確認用装備"))
    check("preview shows rarity",panel.heading.text.contains("Epic"))
    check("preview shows HP",panel.information.text.contains("24"))
    check("full local special effect names",panel.effects.text.contains("初陣の刃") and panel.effects.text.contains("刃の研磨"))
    check("four card buttons",panel.cards_grid.get_child_count()==4)
    check("fixed labels",str(panel.cards_grid.get_child(0).text).contains("固定") and str(panel.cards_grid.get_child(1).text).contains("固定"))
    check("random labels",str(panel.cards_grid.get_child(2).text).contains("ランダム") and str(panel.cards_grid.get_child(3).text).contains("ランダム"))
    check("initial card formal text",panel.card_details.text.contains(str(card_source.cards["C001"].text)))
    var c2: Button=panel.cards_grid.get_child(1)
    c2.mouse_entered.emit()
    check("card hover switches formal text",panel.card_details.text.contains(str(card_source.cards["C002"].text)))
    check("card tooltip full text",c2.tooltip_text.contains(str(card_source.cards["C002"].text)))
    check("item unchanged",JSON.stringify(item)==before)
    check("button summary",EquipmentOfferHoverPanel.offer_button_text(item,1).contains("2.") and EquipmentOfferHoverPanel.offer_button_text(item).contains("特殊効果2"))
    panel.show_item({})
    check("sold item clears preview",panel.cards_grid.get_child_count()==0 and panel.heading.text.contains("カーソル"))
    panel.queue_free()
    await process_frame
    print("EQUIPMENT_OFFER_HOVER_TEST: %d PASS / %d FAIL"%[passes,failures.size()])
    quit(0 if failures.is_empty() else 1)
