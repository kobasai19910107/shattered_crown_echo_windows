class_name CardDatabase
extends RefCounted

const MASTER_DATA_PATH := "res://data/cards_master.json"
const DEBUG_DATA_PATH := "res://data/cards_prototype.json"

var cards: Dictionary = {}
var official_card_ids: Array[String] = []
var prototype_deck: Array = []

func load_data() -> bool:
    cards.clear()
    official_card_ids.clear()
    prototype_deck.clear()

    var master = _load_json_dictionary(MASTER_DATA_PATH)
    if master.is_empty():
        return false

    var master_cards: Dictionary = master.get("cards", {})
    for card_id in master_cards.keys():
        cards[str(card_id)] = master_cards[card_id]
        official_card_ids.append(str(card_id))
    official_card_ids.sort()
    prototype_deck = master.get("prototype_deck", [])

    # DEBUG cards are kept outside the 120-card official master.
    # This lets the battle UI test edge cases without polluting the official catalog.
    if FileAccess.file_exists(DEBUG_DATA_PATH):
        var debug_data = _load_json_dictionary(DEBUG_DATA_PATH)
        var debug_cards: Dictionary = debug_data.get("cards", {})
        for card_id in debug_cards.keys():
            var id = str(card_id)
            if id.begins_with("DBG_") or id.begins_with("BASIC_"):
                cards[id] = debug_cards[card_id]

    if official_card_ids.size() != 120:
        push_error("Expected 120 official cards, loaded %d." % official_card_ids.size())
        return false

    return true

func _load_json_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Card data not found: %s" % path)
        return {}
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Could not open card data: %s" % path)
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Card JSON is invalid: %s" % path)
        return {}
    return parsed

func create_card_copy(card_id: String) -> Dictionary:
    if not cards.has(card_id):
        return {}
    return cards[card_id].duplicate(true)

func create_prototype_deck() -> Array:
    var result: Array = []
    for entry in prototype_deck:
        var card_id: String = str(entry.get("id", ""))
        var count: int = int(entry.get("count", 0))
        if not cards.has(card_id):
            push_warning("Prototype deck card missing: %s" % card_id)
            continue
        for _i in range(count):
            result.append(cards[card_id].duplicate(true))
    return result

func get_official_card_count() -> int:
    return official_card_ids.size()

func get_official_card_ids() -> Array[String]:
    return official_card_ids.duplicate()

func create_deck_from_ids(card_ids: Array) -> Array:
    var result: Array = []
    for raw_id in card_ids:
        var card_id = str(raw_id)
        if not cards.has(card_id):
            push_warning("Custom deck card missing: %s" % card_id)
            continue
        result.append(cards[card_id].duplicate(true))
    return result

func get_card_copy(card_id: String) -> Dictionary:
    return create_card_copy(card_id)
