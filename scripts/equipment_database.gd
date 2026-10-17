class_name EquipmentDatabase
extends RefCounted

const DATA_PATH := "res://data/equipment_prototype.json"

var slots: Array[Dictionary] = []
var items: Dictionary = {}
var fallback_cards: Array[String] = []
var prototype_loadout: Dictionary = {}
var fallback_hp_per_slot: int = 8
var rarity_rules: Dictionary = {}
var special_effect_catalog: Dictionary = {}

func load_data() -> bool:
    slots.clear()
    items.clear()
    fallback_cards.clear()
    prototype_loadout.clear()
    rarity_rules.clear()
    special_effect_catalog.clear()
    fallback_hp_per_slot = 8
    if not FileAccess.file_exists(DATA_PATH):
        push_error("Equipment data not found: %s" % DATA_PATH)
        return false
    var file = FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        return false
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    for raw_slot in parsed.get("slots", []):
        var slot: Dictionary = raw_slot
        slots.append(slot.duplicate(true))
    var raw_items: Dictionary = parsed.get("items", {})
    for raw_id in raw_items.keys():
        var item: Dictionary = raw_items[raw_id]
        items[str(raw_id)] = item.duplicate(true)
    for raw_id in parsed.get("fallback_cards", []):
        fallback_cards.append(str(raw_id))
    var raw_loadout: Dictionary = parsed.get("prototype_loadout", {})
    prototype_loadout = raw_loadout.duplicate(true)
    fallback_hp_per_slot = max(1, int(parsed.get("fallback_hp_per_slot", 8)))
    var raw_rarity_rules: Dictionary = parsed.get("rarity_rules", {})
    rarity_rules = raw_rarity_rules.duplicate(true)
    var raw_effect_catalog: Dictionary = parsed.get("special_effect_catalog", {})
    special_effect_catalog = raw_effect_catalog.duplicate(true)
    return slots.size() == 6 and fallback_cards.size() == 4 and not rarity_rules.is_empty()

func get_slot_ids() -> Array[String]:
    var result: Array[String] = []
    for slot in slots:
        result.append(str(slot.get("id", "")))
    return result

func get_slot_label(slot_id: String) -> String:
    for slot in slots:
        if str(slot.get("id", "")) == slot_id:
            return str(slot.get("label", slot_id))
    return slot_id

func get_items_for_slot(slot_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var ids: Array = items.keys()
    ids.sort()
    for raw_id in ids:
        var item: Dictionary = items[raw_id]
        if str(item.get("slot", "")) == slot_id:
            result.append(item.duplicate(true))
    return result

func get_item(item_id: String) -> Dictionary:
    if not items.has(item_id):
        return {}
    var item: Dictionary = items[item_id]
    return item.duplicate(true)

func is_item_valid_for_slot(item_id: String, slot_id: String) -> bool:
    if item_id == "":
        return true
    if not items.has(item_id):
        return false
    return str(items[item_id].get("slot", "")) == slot_id

func get_item_rarity(item_id: String) -> String:
    if item_id == "":
        return "None"
    return str(get_item(item_id).get("rarity", "Common"))

func get_special_effect_slot_count_for_rarity(rarity: String) -> int:
    var rule: Dictionary = rarity_rules.get(rarity, {})
    return max(0, int(rule.get("special_effect_slots", 0)))

func get_item_special_effects(item_id: String) -> Array:
    if item_id == "":
        return []
    var item = get_item(item_id)
    return Array(item.get("special_effects", [])).duplicate(true)

func is_special_effect_supported(effect: Dictionary) -> bool:
    var effect_type = str(effect.get("type", ""))
    if not special_effect_catalog.has(effect_type):
        return false
    if int(effect.get("amount", 0)) <= 0:
        return false
    if effect_type == "battle_start_weapon_trait":
        return str(effect.get("trait", "")) in ["流転", "精密", "連刃", "重撃", "魔導", "納刀"]
    if effect_type == "battle_start_attribute_trait":
        return str(effect.get("trait", "")) in ["剛力", "帯電", "堅牢", "恩寵", "魔珠", "疾風"]
    return effect_type in ["turn_start_block", "turn_start_mana", "first_turn_draw"]

func validate_item_special_effects(item_id: String) -> bool:
    if item_id == "":
        return true
    var item = get_item(item_id)
    if item.is_empty():
        return false
    var rarity = str(item.get("rarity", "Common"))
    if not rarity_rules.has(rarity):
        return false
    var effects: Array = item.get("special_effects", [])
    if effects.size() > get_special_effect_slot_count_for_rarity(rarity):
        return false
    for raw_effect in effects:
        if typeof(raw_effect) != TYPE_DICTIONARY:
            return false
        if not is_special_effect_supported(raw_effect):
            return false
    return true

func describe_special_effect(effect: Dictionary) -> String:
    var effect_type = str(effect.get("type", ""))
    var amount = int(effect.get("amount", 0))
    if effect_type == "battle_start_weapon_trait":
        return "Battle start: %s +%d" % [str(effect.get("trait", "?")), amount]
    if effect_type == "battle_start_attribute_trait":
        return "Battle start: %s +%d" % [str(effect.get("trait", "?")), amount]
    if effect_type == "turn_start_block":
        return "Each player turn: Block +%d" % amount
    if effect_type == "turn_start_mana":
        return "Each player turn: Mana +%d" % amount
    if effect_type == "first_turn_draw":
        return "First player turn: Draw +%d" % amount
    return effect_type
