class_name Step8EquipmentRoller
extends RefCounted

# STEP 8: v1.7 battle UI integration of STEP 7 120-card / 108-equipment roll.
# Battle effects remain on the v1.7 battle runtime until separate STEP 4 effects migration.
const POLICY_PATH := "res://data/step8_equipment_policy.json"
const WEAPON_CODES := {"SWORD": "片手剣", "RAPIER": "レイピア", "DAGGER": "短剣", "GREATSWORD": "大剣", "MAGICSWORD": "魔法剣", "KATANA": "刀"}
const SLOT_CODES := {"Weapon": "main_weapon", "Offhand": "offhand", "Head": "head", "Body": "body", "Hands": "hands", "Feet": "feet"}
const PREFERRED_ROLES := {
    "SHIELD": ["defense", "prep"], "GRIMOIRE": ["cycle", "salvage"], "SCABBARD": ["prep", "cycle"], "HOLYSIGIL": ["defense", "healing"], "ORB": ["trait", "cycle"],
    "HELM": ["defense", "prep"], "CIRCLET": ["cycle", "salvage"], "HOOD": ["cycle", "trait"], "MASK": ["prep", "attack"],
    "PLATE": ["defense", "trait"], "COAT": ["attack", "defense"], "ROBE": ["cycle", "trait"], "VESTMENT": ["defense", "healing"],
    "GAUNTLETS": ["attack", "finisher"], "GLOVES": ["cycle", "salvage"], "BRACERS": ["trait", "attack"], "HANDWRAPS": ["prep", "defense"],
    "GREAVES": ["defense", "prep"], "BOOTS": ["cycle", "attack"], "SANDALS": ["trait", "healing"], "STRIDERS": ["cycle", "prep"]
}

var templates: Dictionary = {}
var cards: Dictionary = {}
var pairs: Array = []
var pairs_by_weapon: Dictionary = {}
var attributes: Array[String] = []
var weapons: Array[String] = []
var cross_ids: Dictionary = {}

func load_data() -> bool:
    if not FileAccess.file_exists(POLICY_PATH):
        return false
    var file = FileAccess.open(POLICY_PATH, FileAccess.READ)
    if file == null:
        return false
    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        return false
    templates.clear()
    cards.clear()
    pairs.clear()
    pairs_by_weapon.clear()
    attributes.clear()
    weapons.clear()
    cross_ids.clear()
    for raw_template in data.get("equipment_templates", []):
        var template: Dictionary = raw_template
        templates[str(template.get("EquipmentID", ""))] = template.duplicate(true)
    for raw_card in data.get("card_metadata", []):
        var card: Dictionary = raw_card
        var id = str(card.get("id", ""))
        cards[id] = card.duplicate(true)
        var attr = str(card.get("attr", ""))
        var weapon = str(card.get("weapon", ""))
        if not attributes.has(attr):
            attributes.append(attr)
        if not weapons.has(weapon):
            weapons.append(weapon)
        if bool(card.get("cross_eligible", false)):
            cross_ids[id] = true
    for raw_pair in data.get("card_pair_catalog", []):
        var pair: Dictionary = raw_pair
        pairs.append(pair.duplicate(true))
        var weapon = str(pair.get("weapon", ""))
        if not pairs_by_weapon.has(weapon):
            pairs_by_weapon[weapon] = []
        pairs_by_weapon[weapon].append(pair.duplicate(true))
    return templates.size() == 108 and cards.size() == 120 and pairs.size() == 60

func get_templates_for_slot(slot_id: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var keys: Array = templates.keys()
    keys.sort()
    for key in keys:
        var t: Dictionary = templates[key]
        if str(SLOT_CODES.get(str(t.get("Slot", "")), "")) == slot_id:
            result.append(t.duplicate(true))
    return result

func _pair_ids(p: Dictionary) -> Array[String]:
    if str(p.get("status", "")) == "SC":
        return [str(p.get("set_id", "")), str(p.get("con_id", ""))]
    var found: Array[String] = []
    for id in cards.keys():
        var c: Dictionary = cards[id]
        if str(c.get("attr", "")) == str(p.get("attr", "")) and str(c.get("weapon", "")) == str(p.get("weapon", "")):
            found.append(str(id))
    found.sort()
    return found

func _weight_pick(entries: Array, weights: Array, rng: RandomNumberGenerator) -> Variant:
    if entries.is_empty():
        return null
    var total := 0.0
    for weight in weights:
        total += maxf(weight, 0.1)
    var value := rng.randf() * total
    for i in range(entries.size()):
        value -= maxf(weights[i], 0.1)
        if value <= 0.0:
            return entries[i]
    return entries.back()

func _choose_nonweapon_fixed(base: String, attr: String, affinity: String, context: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
    var chosen: Array[String] = []
    var wishes: Array = PREFERRED_ROLES.get(base, ["defense", "cycle"])
    for index in range(2):
        var role = str(wishes[index])
        var pool: Array = []
        var weights: Array[float] = []
        for id in cards.keys():
            if chosen.has(str(id)):
                continue
            var card: Dictionary = cards[id]
            var tags: Array = card.get("tags", [])
            var score := 0.3
            if tags.has(role):
                score += 18.0
            if str(card.get("attr", "")) == attr:
                score += 4.0
            if str(card.get("weapon", "")) == affinity:
                score += 5.0
            if str(card.get("type", "")) == "Skill":
                score += 1.5
            if index == 1:
                for chosen_id in chosen:
                    if _are_counterparts(str(chosen_id), str(id)):
                        score += 45.0
            if str(card.get("weapon", "")) == affinity and context.get("core_cards", []).has(str(id)):
                score += 12.0
            if base == "SCABBARD" and str(card.get("weapon", "")) == affinity and (tags.has("prep") or tags.has("cycle")):
                score += 8.0
            pool.append(str(id))
            weights.append(score)
        var selected = _weight_pick(pool, weights, rng)
        if selected == null:
            return []
        chosen.append(str(selected))
    return chosen

func _are_counterparts(a: String, b: String) -> bool:
    if not cards.has(a) or not cards.has(b):
        return false
    var left: Dictionary = cards[a]
    var right: Dictionary = cards[b]
    if str(left.get("weapon", "")) != str(right.get("weapon", "")) or str(left.get("attr", "")) != str(right.get("attr", "")):
        return false
    for p in pairs_by_weapon.get(str(left.get("weapon", "")), []):
        if str(p.get("status", "")) == "SC" and _pair_ids(p).has(a) and _pair_ids(p).has(b):
            return true
    return false

func _choose_nonweapon_random(rarity: String, attr: String, affinity: String, fixed: Array[String], wishes: Array, context: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
    if rng.randf() < 0.82:
        var pool: Array = []
        var weights: Array[float] = []
        for p in pairs_by_weapon.get(affinity, []):
            var ids = _pair_ids(p)
            if ids.size() != 2 or fixed.has(ids[0]) or fixed.has(ids[1]):
                continue
            var score := 2.0 + (7.0 if str(p.get("status", "")) == "SC" else 3.0)
            if str(p.get("attr", "")) == attr:
                score += 8.0
            for id in ids:
                var tags: Array = cards[id].get("tags", [])
                if tags.has("cycle"):
                    score += 3.5
                if tags.has("defense"):
                    score += 1.5
            if context.get("core_cards", []).size() == 2 and ids.has(str(context["core_cards"][0])) and ids.has(str(context["core_cards"][1])):
                score += 24.0
            pool.append(ids)
            weights.append(score)
        var selected = _weight_pick(pool, weights, rng)
        if selected != null:
            return selected
    var chosen: Array[String] = fixed.duplicate()
    var random: Array[String] = []
    for index in range(2):
        var cross_used := 0
        for id in random:
            if str(cards[id].get("weapon", "")) != affinity:
                cross_used += 1
        var pool: Array = []
        var weights: Array[float] = []
        for id in cards.keys():
            if chosen.has(str(id)):
                continue
            var c: Dictionary = cards[id]
            var is_cross := str(c.get("weapon", "")) != affinity
            if is_cross and (rarity == "Common" or cross_used >= 1 or not cross_ids.has(str(id))):
                continue
            var tags: Array = c.get("tags", [])
            var score := 0.6
            if str(c.get("attr", "")) == attr:
                score += 4.0
            if not is_cross:
                score += 6.0
            for existing_id in chosen:
                if _are_counterparts(existing_id, str(id)):
                    score += 16.0
            if tags.has("cycle") or tags.has("salvage"):
                score += 4.0
            if tags.has("defense"):
                score += 2.0
            if tags.has("skill") and index == 1:
                score += 4.0
            if tags.has("salvage") and wishes.has("salvage"):
                score += 2.0
            pool.append(str(id))
            weights.append(score)
        var selected = _weight_pick(pool, weights, rng)
        if selected == null:
            return []
        random.append(str(selected))
        chosen.append(str(selected))
    return random

func generate_item(template_id: String, seed_value: int, context: Dictionary = {}) -> Dictionary:
    if not templates.has(template_id):
        return {}
    var template: Dictionary = templates[template_id]
    var rng = RandomNumberGenerator.new()
    rng.seed = hash("%d|%s" % [seed_value, template_id])
    var raw_slot := str(template.get("Slot", ""))
    var slot := str(SLOT_CODES.get(raw_slot, ""))
    var base := str(template.get("BaseCode", ""))
    var rarity := str(template.get("Rarity", "Common"))
    var attr := ""
    var affinity := ""
    var secondary := ""
    var fixed: Array[String] = []
    var random_cards: Array[String] = []
    if raw_slot == "Weapon":
        affinity = str(WEAPON_CODES.get(base, ""))
        var sc_pool: Array = []
        for p in pairs_by_weapon.get(affinity, []):
            if str(p.get("status", "")) == "SC":
                sc_pool.append(p)
        if sc_pool.is_empty():
            return {}
        var core: Dictionary = sc_pool[rng.randi_range(0, sc_pool.size() - 1)]
        attr = str(core.get("attr", ""))
        fixed = _pair_ids(core)
        var alt_pool: Array = []
        var weights: Array[float] = []
        for p in pairs_by_weapon.get(affinity, []):
            if str(p.get("attr", "")) != attr:
                alt_pool.append(p)
                weights.append(7.0 if str(p.get("status", "")) == "SC" else 3.0)
        var secondary_pair = _weight_pick(alt_pool, weights, rng)
        if secondary_pair == null:
            return {}
        secondary = str(secondary_pair.get("attr", ""))
        random_cards = _pair_ids(secondary_pair)
    else:
        attr = attributes[rng.randi_range(0, attributes.size() - 1)]
        if context.has("attribute") and attributes.has(str(context["attribute"])) and rng.randf() < 0.65:
            attr = str(context["attribute"])
        if base == "SCABBARD":
            var choices: Array = ["刀", "片手剣", "レイピア"]
            if choices.has(str(context.get("weapon", ""))) and rng.randf() < 0.8:
                affinity = str(context.get("weapon", ""))
            else:
                var j = _weight_pick(choices, [7.0, 2.0, 1.0], rng)
                affinity = str(j)
        else:
            affinity = weapons[rng.randi_range(0, weapons.size() - 1)]
            if weapons.has(str(context.get("weapon", ""))) and rng.randf() < 0.85:
                affinity = str(context.get("weapon", ""))
        fixed = _choose_nonweapon_fixed(base, attr, affinity, context, rng)
        random_cards = _choose_nonweapon_random(rarity, attr, affinity, fixed, PREFERRED_ROLES.get(base, []), context, rng)
    if fixed.size() != 2 or random_cards.size() != 2:
        return {}
    var all_cards: Array[String] = fixed.duplicate()
    all_cards.append_array(random_cards)
    var result = {
        "instance_id": "STEP8_%s_%d" % [template_id.replace("-", "_"), seed_value],
        "equipment_id": template_id,
        "slot": slot,
        "base_code": base,
        "name": str(template.get("DisplayName", template_id)),
        "rarity": rarity,
        "rolled_attribute": attr,
        "affinity_weapon": affinity,
        "secondary_attribute": secondary,
        "fixed_cards": fixed,
        "random_cards": random_cards,
        "cards": all_cards,
        "seed": seed_value,
        "reroll_counts": [0, 0],
        "special_reroll_count": 0,
        "base_hp": max(1, int(template.get("Drop_HP", 8))),
        "socket_cap": int(template.get("SocketCap", 0)),
        "special_effect_slots": int(template.get("SpecialEffectSlots", 0)),
        "special_effects": [],
        "step8_roll": true
    }
    if not validate_item(result):
        push_error("STEP8 invalid generated item: %s" % template_id)
        return {}
    return result

func validate_item(item: Dictionary) -> bool:
    var ids: Array = item.get("cards", [])
    var fixed: Array = item.get("fixed_cards", [])
    var random: Array = item.get("random_cards", [])
    if ids.size() != 4 or fixed.size() != 2 or random.size() != 2:
        return false
    var seen: Dictionary = {}
    for id in ids:
        if not cards.has(str(id)) or seen.has(str(id)):
            return false
        seen[str(id)] = true
    if ids != fixed + random:
        return false
    var affinity := str(item.get("affinity_weapon", ""))
    var cross_count := 0
    for id in random:
        if str(cards[str(id)].get("weapon", "")) != affinity:
            cross_count += 1
            if not cross_ids.has(str(id)):
                return false
    if cross_count > (0 if str(item.get("rarity", "")) == "Common" else 1):
        return false
    if str(item.get("slot", "")) == "main_weapon":
        if str(cards[str(fixed[0])].get("weapon", "")) != affinity:
            return false
        if not _are_counterparts(str(fixed[0]), str(fixed[1])):
            return false
        if str(cards[str(fixed[0])].get("action", "")) == "NEUTRAL":
            return false
    return true

func inspect_deck(items_by_slot: Dictionary) -> Dictionary:
    var counts: Dictionary = {}
    var deck: Array[String] = []
    var attack := 0
    var cycle := 0
    var salvage := 0
    var heavy := 0
    for slot_id in ["main_weapon", "offhand", "head", "body", "hands", "feet"]:
        var item: Dictionary = items_by_slot.get(slot_id, {})
        for raw_id in item.get("cards", []):
            var id := str(raw_id)
            deck.append(id)
            counts[id] = int(counts.get(id, 0)) + 1
            var c: Dictionary = cards.get(id, {})
            if str(c.get("type", "")) == "Attack":
                attack += 1
            if int(c.get("cost", 0)) >= 2:
                heavy += 1
            if c.get("tags", []).has("cycle"):
                cycle += 1
            if c.get("tags", []).has("salvage"):
                salvage += 1
    var completed := 0
    var orphan := 0
    for p in pairs:
        if str(p.get("status", "")) != "SC":
            continue
        var a := int(counts.get(str(p.get("set_id", "")), 0))
        var b := int(counts.get(str(p.get("con_id", "")), 0))
        if a > 0 and b > 0:
            completed += 1
        orphan += abs(a - b)
    return {"card_count": deck.size(), "attack": attack, "cycle": cycle, "salvage": salvage, "cost2_plus": heavy, "completed_sc": completed, "orphan": orphan, "deck": deck}
