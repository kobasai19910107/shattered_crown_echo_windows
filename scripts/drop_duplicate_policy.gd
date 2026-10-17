class_name DropDuplicatePolicy
extends RefCounted

# Filters only generated equipment offers; never changes card or equipment rolls.
const RECENT_MAX: int = 12
const MAX_RETRIES: int = 10
const HISTORY_RETRY_RATE: float = 0.70

static func pair_key(item: Dictionary) -> String:
    var card_ids: Array = item.get("random_cards", [])
    if card_ids.size() != 2:
        return ""
    var sorted_ids: Array[String] = [str(card_ids[0]), str(card_ids[1])]
    sorted_ids.sort()
    return "%s|%s|%s" % [str(item.get("slot", "")), sorted_ids[0], sorted_ids[1]]

static func record_acquired(next: Dictionary, item: Dictionary) -> void:
    var key: String = pair_key(item)
    if key == "":
        return
    var history: Array = next.get("recent_drop_pairs", []).duplicate()
    history.append(key)
    while history.size() > RECENT_MAX:
        history.pop_front()
    next["recent_drop_pairs"] = history

static func valid_history(history: Variant, slots: Array, cards: Dictionary) -> bool:
    if not history is Array or history.size() > RECENT_MAX:
        return false
    for entry in history:
        if not entry is String:
            return false
        var parts: PackedStringArray = str(entry).split("|")
        if parts.size() != 3 or not slots.has(parts[0]):
            return false
        if not cards.has(parts[1]) or not cards.has(parts[2]):
            return false
        if parts[1] >= parts[2]:
            return false
    return true
