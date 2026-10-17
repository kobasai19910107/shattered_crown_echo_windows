class_name LoadoutBuilder
extends RefCounted

const CARDS_PER_SLOT := 4
const TOTAL_SLOTS := 6
const TOTAL_DECK_SIZE := 24

var equipment_db: EquipmentDatabase
var card_db: CardDatabase
var selected_by_slot: Dictionary = {}

func _init() -> void:
    equipment_db = EquipmentDatabase.new()
    card_db = CardDatabase.new()

func load_data() -> bool:
    if not equipment_db.load_data():
        return false
    if not card_db.load_data():
        return false
    selected_by_slot.clear()
    for slot_id in equipment_db.get_slot_ids():
        selected_by_slot[slot_id] = ""
    return true

func load_prototype_loadout() -> void:
    for slot_id in equipment_db.get_slot_ids():
        var item_id = str(equipment_db.prototype_loadout.get(slot_id, ""))
        selected_by_slot[slot_id] = item_id if equipment_db.is_item_valid_for_slot(item_id, slot_id) else ""

func unequip_all() -> void:
    for slot_id in equipment_db.get_slot_ids():
        selected_by_slot[slot_id] = ""

func set_equipment(slot_id: String, item_id: String) -> bool:
    if not selected_by_slot.has(slot_id):
        return false
    if not equipment_db.is_item_valid_for_slot(item_id, slot_id):
        return false
    selected_by_slot[slot_id] = item_id
    return true

func get_selected_item_id(slot_id: String) -> String:
    return str(selected_by_slot.get(slot_id, ""))

func get_cards_for_slot(slot_id: String) -> Array[String]:
    var result: Array[String] = []
    var item_id = get_selected_item_id(slot_id)
    var source: Array = equipment_db.fallback_cards
    if item_id != "":
        var item = equipment_db.get_item(item_id)
        source = item.get("cards", [])
    for raw_id in source:
        result.append(str(raw_id))
    return result


func get_hp_for_slot(slot_id: String) -> int:
    var item_id = get_selected_item_id(slot_id)
    if item_id == "":
        return equipment_db.fallback_hp_per_slot
    var item = equipment_db.get_item(item_id)
    return max(0, int(item.get("base_hp", 0)))

func calculate_player_max_hp() -> int:
    var total = 0
    for slot_id in equipment_db.get_slot_ids():
        total += get_hp_for_slot(slot_id)
    return max(1, total)

func build_deck_ids() -> Array[String]:
    var result: Array[String] = []
    for slot_id in equipment_db.get_slot_ids():
        for card_id in get_cards_for_slot(slot_id):
            result.append(card_id)
    return result

func is_valid() -> bool:
    var slot_ids = equipment_db.get_slot_ids()
    if slot_ids.size() != TOTAL_SLOTS:
        return false
    for slot_id in slot_ids:
        var cards = get_cards_for_slot(slot_id)
        if cards.size() != CARDS_PER_SLOT:
            return false
        for card_id in cards:
            if not card_db.cards.has(card_id):
                return false
        var item_id = get_selected_item_id(slot_id)
        if item_id != "" and not equipment_db.validate_item_special_effects(item_id):
            return false
    return build_deck_ids().size() == TOTAL_DECK_SIZE

func get_snapshot() -> Dictionary:
    var snapshot = {}
    for slot_id in equipment_db.get_slot_ids():
        var item_id = get_selected_item_id(slot_id)
        var base_hp = get_hp_for_slot(slot_id)
        var item = {} if item_id == "" else equipment_db.get_item(item_id)
        snapshot[slot_id] = {
            "item_id": item_id,
            "item_name": "Unequipped / Basic cards" if item_id == "" else str(item.get("name", item_id)),
            "cards": get_cards_for_slot(slot_id),
            "base_hp": base_hp,
            "hp_bonus": 0,
            "effective_hp": base_hp,
            "rarity": "None" if item_id == "" else str(item.get("rarity", "Common")),
            "special_effects": [] if item_id == "" else Array(item.get("special_effects", [])).duplicate(true)
        }
    return snapshot

func get_summary_text() -> String:
    var lines: Array[String] = []
    for slot_id in equipment_db.get_slot_ids():
        var item_id = get_selected_item_id(slot_id)
        var item = {} if item_id == "" else equipment_db.get_item(item_id)
        var name = "Unequipped / Basic cards" if item_id == "" else str(item.get("name", item_id))
        var rarity = "None" if item_id == "" else str(item.get("rarity", "Common"))
        var effect_texts: Array[String] = []
        if item_id != "":
            for raw_effect in item.get("special_effects", []):
                effect_texts.append(equipment_db.describe_special_effect(raw_effect))
        var effects_label = "none" if effect_texts.is_empty() else "; ".join(effect_texts)
        lines.append("%s: %s [%s] | HP %d | %s\n  Special: %s" % [equipment_db.get_slot_label(slot_id), name, rarity, get_hp_for_slot(slot_id), ", ".join(get_cards_for_slot(slot_id)), effects_label])
    lines.append("Deck: %d / %d" % [build_deck_ids().size(), TOTAL_DECK_SIZE])
    lines.append("Player Max HP: %d (sum of six equipment slots)" % calculate_player_max_hp())
    return "\n".join(lines)
