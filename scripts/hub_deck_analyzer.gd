class_name HubDeckAnalyzer
extends RefCounted

const SLOTS=["main_weapon","offhand","head","body","hands","feet"]
var cards: Dictionary={}
var roller=Step8EquipmentRoller.new()
var loaded: bool=false

func _init() -> void:
    var database=CardDatabase.new()
    if not database.load_data() or not roller.load_data():return
    for id in database.get_official_card_ids():cards[id]=database.get_card_copy(id)
    loaded=true

func categories(field: String) -> Array:
    var values: Array=[]
    for card in cards.values():
        var value: String=str(card.get(field,""))
        if not values.has(value):values.append(value)
    values.sort()
    return values

func analyze(items: Dictionary) -> Dictionary:
    var result: Dictionary=roller.inspect_deck(items)
    result["hp"]=0
    result["missing_slots"]=[]
    result["warnings"]=[]
    result["completed_pairs"]=[]
    # Number of SC definitions with exactly one side present (not card copy imbalance).
    result["orphan_pairs"]=0
    result["distribution"]={}
    for field in ["attribute","weapon","role","card_type"]:
        var bins: Dictionary={}
        for value in categories(field):bins[value]=0
        result.distribution[field]=bins
    for slot in SLOTS:
        var item: Dictionary=items.get(slot,{})
        if item.is_empty():result.missing_slots.append(slot);continue
        result.hp+=int(item.get("effective_hp",item.get("base_hp",0)))
        if item.get("cards",[]).size()!=4:result.warnings.append("%s：4カードではありません。"%slot)
        if item.get("fixed_cards",[])+item.get("random_cards",[])!=item.get("cards",[]):
            result.warnings.append("%s：固定・ランダム枠とカード配列が一致しません。"%slot)
    var counts: Dictionary={}
    for raw_id in result.deck:
        var id: String=str(raw_id)
        counts[id]=int(counts.get(id,0))+1
        if not cards.has(id):
            result.warnings.append("未解決カードID："+id);continue
        for field in result.distribution:
            var value: String=str(cards[id].get(field,""))
            result.distribution[field][value]=int(result.distribution[field].get(value,0))+1
    for pair in roller.pairs:
        if str(pair.get("status",""))!="SC":continue
        var has_set: bool=int(counts.get(str(pair.get("set_id","")),0))>0
        var has_consume: bool=int(counts.get(str(pair.get("con_id","")),0))>0
        if has_set and has_consume:
            result.completed_pairs.append(pair.duplicate(true))
        elif has_set or has_consume:
            result["orphan_pairs"]+=1
    result["complete"]=result.missing_slots.is_empty() and int(result.card_count)==24 and result.warnings.is_empty()
    return result

func card_description(id: String) -> String:
    if not cards.has(id):return "未解決カードID：%s（効果を表示できません）"%id
    var card: Dictionary=cards[id]
    var action: String=str(card.get("weapon_trait_action",roller.cards.get(id,{}).get("action","")))
    return "%s　Cost %d　%s\n属性 %s / 武器 %s / 役割 %s\n武器特性 %s\n%s"%[id,int(card.cost),str(card.card_type).capitalize(),str(card.attribute),str(card.weapon),str(card.role),action,WeaponTraitCardDescription.combined_text(card)]
