class_name DeckBuilder
extends RefCounted

const DECK_SIZE := 24

var database: CardDatabase
var deck_ids: Array[String] = []

func _init() -> void:
    database = CardDatabase.new()

func load_data() -> bool:
    return database.load_data()

func load_prototype_deck() -> void:
    deck_ids.clear()
    for entry in database.prototype_deck:
        var card_id = str(entry.get("id", ""))
        var count = int(entry.get("count", 0))
        for _i in range(count):
            if database.cards.has(card_id):
                deck_ids.append(card_id)

func clear_deck() -> void:
    deck_ids.clear()

func set_deck_ids(card_ids: Array) -> bool:
    if card_ids.size() != DECK_SIZE:
        return false
    var next_ids: Array[String] = []
    for raw_id in card_ids:
        var card_id = str(raw_id)
        if not database.cards.has(card_id):
            return false
        next_ids.append(card_id)
    deck_ids = next_ids
    return true

func add_card(card_id: String) -> bool:
    if deck_ids.size() >= DECK_SIZE:
        return false
    if not database.official_card_ids.has(card_id):
        return false
    deck_ids.append(card_id)
    return true

func remove_one(card_id: String) -> bool:
    var index = deck_ids.find(card_id)
    if index < 0:
        return false
    deck_ids.remove_at(index)
    return true

func get_deck_ids() -> Array[String]:
    return deck_ids.duplicate()

func is_ready() -> bool:
    return deck_ids.size() == DECK_SIZE

func get_status_text() -> String:
    if is_ready():
        return "Deck ready: %d / %d" % [deck_ids.size(), DECK_SIZE]
    return "Deck: %d / %d — add %d card(s)" % [deck_ids.size(), DECK_SIZE, DECK_SIZE - deck_ids.size()]

func get_card(card_id: String) -> Dictionary:
    return database.get_card_copy(card_id)

func get_filtered_card_ids(attribute_filter: String = "ALL", weapon_filter: String = "ALL", role_filter: String = "ALL", query: String = "") -> Array[String]:
    var result: Array[String] = []
    var normalized_query = query.strip_edges().to_lower()
    for card_id in database.get_official_card_ids():
        var card: Dictionary = database.cards.get(card_id, {})
        if card.is_empty():
            continue
        if attribute_filter != "ALL" and str(card.get("attribute", "")) != attribute_filter:
            continue
        if weapon_filter != "ALL" and str(card.get("weapon", "")) != weapon_filter:
            continue
        if role_filter != "ALL" and str(card.get("role", "")) != role_filter:
            continue
        if normalized_query != "":
            var haystack = (str(card.get("id", "")) + " " + str(card.get("display_name", "")) + " " + str(card.get("text", ""))).to_lower()
            if not haystack.contains(normalized_query):
                continue
        result.append(card_id)
    result.sort()
    return result

func get_deck_count_map() -> Dictionary:
    var counts = {}
    for card_id in deck_ids:
        counts[card_id] = int(counts.get(card_id, 0)) + 1
    return counts

func describe_card(card_id: String) -> String:
    var card = get_card(card_id)
    if card.is_empty():
        return "Unknown card: %s" % card_id
    return "%s\nAttribute: %s / Trait: %s\nWeapon: %s / Trait: %s\nRole: %s / Type: %s / Cost: %d\nTarget: %s\n\n%s" % [
        card.get("display_name", card_id),
        card.get("attribute", "-"), card.get("attribute_trait", "-"),
        card.get("weapon", "-"), card.get("weapon_trait", "-"),
        card.get("role", "-"), card.get("card_type", "-"), int(card.get("cost", 0)),
        card.get("target_type", "-"),
        WeaponTraitCardDescription.combined_text(card)
    ]
