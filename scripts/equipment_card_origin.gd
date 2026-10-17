class_name EquipmentCardOrigin
extends RefCounted

# Metadata-only bridge from the frozen 24-card loadout into battle cards.
# No RNG calls, card-master changes, or modifications to item templates.
const SLOTS = ["main_weapon", "offhand", "head", "body", "hands", "feet"]

static func attach(deck: Array, requested_ids: Array, items_by_slot: Dictionary) -> bool:
    # Validation is completed before any card is touched (atomic fallback).
    if deck.size() != 24 or requested_ids.size() != 24 or items_by_slot.size() != 6:
        return false
    var origin_entries: Array[Dictionary] = []
    var used_uids: Dictionary = {}
    for slot in SLOTS:
        if not items_by_slot.get(slot) is Dictionary:
            return false
        var item: Dictionary = items_by_slot[slot]
        var uid: String = str(item.get("instance_id", ""))
        var ids = item.get("cards", [])
        if uid == "" or used_uids.has(uid) or not ids is Array or ids.size() != 4:
            return false
        used_uids[uid] = true
        for index in range(4):
            var deck_index: int = origin_entries.size()
            var card_id: String = str(ids[index])
            if card_id == "" or str(requested_ids[deck_index]) != card_id:
                return false
            if not deck[deck_index] is Dictionary or str(deck[deck_index].get("id", "")) != card_id:
                return false
            origin_entries.append({
                "source_equipment_uid": uid,
                "source_slot": slot,
                "card_instance_uid": "%s:%s:%d" % [uid, slot, index]
            })
    if origin_entries.size() != 24:
        return false
    for i in range(24):
        deck[i].merge(origin_entries[i], true)
    return true

static func matching_equipment(card: Dictionary, equipment: Dictionary) -> bool:
    var uid: String = str(card.get("source_equipment_uid", ""))
    var slot: String = str(card.get("source_slot", ""))
    return uid != "" and slot != "" and str(equipment.get("instance_id", "")) == uid and str(equipment.get("slot", "")) == slot
