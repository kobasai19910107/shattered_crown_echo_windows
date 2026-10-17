class_name InitialDeckGenerator
extends RefCounted

# Approved STEP17 profile. Only unminted initial six-item packages are searched.
# Single-item drops and already saved items continue to use their existing paths.
const RollerScript = preload("res://scripts/step8_equipment_roller.gd")
const BattleScript = preload("res://scripts/battle_controller.gd")
const SLOTS = ["main_weapon", "offhand", "head", "body", "hands", "feet"]
const PROFILE_VERSION = "initial_synergy_v1"
const MAX_ATTEMPTS = 256

var roller = RollerScript.new()
var database = CardDatabase.new()
var ready: bool = false

func load_data() -> bool:
    ready = roller.load_data() and database.load_data()
    return ready

func generate_initial_loadout(template_ids: Dictionary, seed_value: int, profile_version: String = PROFILE_VERSION, attempt_limit: int = MAX_ATTEMPTS, cancel: Callable = Callable()) -> Dictionary:
    if profile_version != PROFILE_VERSION or attempt_limit < 1 or attempt_limit > MAX_ATTEMPTS:
        return _failure("INVALID_INPUT", 0, "Unsupported profile or search budget")
    if not ready and not load_data():
        return _failure("DATA_ERROR", 0, "Equipment/card data unavailable")
    if template_ids.size() != SLOTS.size():
        return _failure("INVALID_INPUT", 0, "Exactly six templates required")
    var baseline: Dictionary = {}
    var context: Dictionary = {}
    for i in range(SLOTS.size()):
        var slot: String = SLOTS[i]
        var tid: String = str(template_ids.get(slot, ""))
        if not roller.templates.has(tid):
            return _failure("INVALID_INPUT", 0, "Unknown template: " + tid)
        var template: Dictionary = roller.templates[tid]
        if str(roller.SLOT_CODES.get(str(template.get("Slot", "")), "")) != slot:
            return _failure("INVALID_INPUT", 0, "Wrong template slot: " + tid)
        var item: Dictionary = roller.generate_item(tid, seed_value + i * 1009, context)
        if item.is_empty():
            return _failure("DATA_ERROR", 0, "Cannot generate: " + tid)
        baseline[slot] = item
        if i == 0:
            context = {"weapon": item["affinity_weapon"], "attribute": item["rolled_attribute"], "core_cards": item["fixed_cards"].duplicate()}
    var rng = RandomNumberGenerator.new()
    rng.seed = hash("%s|%d" % [profile_version, seed_value])
    var last_reason: String = ""
    for attempt in range(attempt_limit):
        if cancel.is_valid() and bool(cancel.call()):
            return _failure("CANCELLED", attempt, "Generation cancelled")
        var candidate: Dictionary = baseline.duplicate(true)
        if attempt > 0:
            for slot in SLOTS:
                var item: Dictionary = candidate[slot]
                var random_cards: Array = _sample_random_package(item, context, rng)
                item["random_cards"] = random_cards
                item["cards"] = item["fixed_cards"] + random_cards
                if slot == "main_weapon" and random_cards.size() == 2:
                    item["secondary_attribute"] = str(database.cards[random_cards[0]]["attribute"])
        if not validate_package(candidate):
            last_reason = "Illegal package candidate"
            continue
        var evidence: Dictionary = verify_synergy(candidate)
        if not bool(evidence.get("ok", false)):
            last_reason = str(evidence.get("reason", "No runtime witness"))
            continue
        for slot in SLOTS:
            candidate[slot]["instance_id"] = "STEP17_%s_%s_%d" % [profile_version, candidate[slot]["equipment_id"].replace("-", "_"), seed_value]
        return {"ok": true, "status": "PASS", "items": candidate, "attempts": attempt + 1, "profile_version": profile_version, "evidence": evidence}
    return _failure("EXHAUSTED", attempt_limit, last_reason)

func _failure(status: String, attempts: int, reason: String) -> Dictionary:
    # No references to live loadout/UI/save state: failed searches cannot mutate it.
    return {"ok": false, "status": status, "items": {}, "attempts": attempts, "reason": reason}

func _sample_random_package(item: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> Array:
    if str(item["slot"]) != "main_weapon":
        var fixed: Array[String] = []
        fixed.assign(item["fixed_cards"])
        return roller._choose_nonweapon_random(str(item["rarity"]), str(item["rolled_attribute"]), str(item["affinity_weapon"]), fixed, roller.PREFERRED_ROLES.get(str(item["base_code"]), []), context, rng)
    var candidates: Array = []
    var weights: Array = []
    for pair in roller.pairs_by_weapon.get(str(item["affinity_weapon"]), []):
        if str(pair["attr"]) != str(item["rolled_attribute"]):
            candidates.append(pair)
            weights.append(7.0 if str(pair["status"]) == "SC" else 3.0)
    var selected = roller._weight_pick(candidates, weights, rng)
    return [] if selected == null else roller._pair_ids(selected)

func validate_package(items: Dictionary) -> bool:
    if items.size() != 6:
        return false
    for slot in SLOTS:
        var item: Dictionary = items.get(slot, {})
        if item.is_empty() or str(item.get("slot", "")) != slot or not roller.validate_item(item):
            return false
        var cross: int = 0
        for cid in item["cards"]:
            if not database.cards.has(cid) or not database.official_card_ids.has(cid):
                return false
        for cid in item["random_cards"]:
            var c: Dictionary = database.cards[cid]
            if str(c["weapon"]) != str(item["affinity_weapon"]):
                cross += 1
                if str(c["weapon_trait_action"]) != "NEUTRAL" or not roller.cross_ids.has(cid):
                    return false
        if cross > (0 if str(item["rarity"]) == "Common" or slot == "main_weapon" else 1):
            return false
        if slot == "main_weapon":
            for cid in item["cards"]:
                if str(database.cards[cid]["weapon"]) != str(item["affinity_weapon"]):
                    return false
            var r: Array = item["random_cards"]
            if str(database.cards[r[0]]["attribute"]) != str(database.cards[r[1]]["attribute"]) or str(database.cards[r[0]]["attribute"]) == str(item["rolled_attribute"]):
                return false
    return int(roller.inspect_deck(items)["card_count"]) == 24

func verify_synergy(items: Dictionary) -> Dictionary:
    if not ready and not load_data():
        return {"ok": false, "reason": "Data unavailable"}
    if not validate_package(items):
        return {"ok": false, "reason": "Illegal package"}
    var audit: Dictionary = roller.inspect_deck(items)
    if int(audit["completed_sc"]) < 2:
        return {"ok": false, "reason": "Fewer than two distinct complete SC pairs"}
    var deck: Array = audit["deck"]
    var draw_candidates: Array = []
    for cid in deck:
        var c: Dictionary = database.cards[cid]
        # Conditional/fallback Draw and Power triggers are not unconditional Draw.
        if int(c.get("draw_count", 0)) > 0 and str(c.get("step9_salvage", "")) == "":
            draw_candidates.append(cid)
    if draw_candidates.size() < 2:
        return {"ok": false, "reason": "Fewer than two unconditional Draw copies"}
    var draw_witnesses: Array = []
    var draw_cache: Dictionary = {}
    for cid in draw_candidates:
        if not draw_cache.has(cid):
            draw_cache[cid] = _draw_witness(deck, str(cid))
        if bool(draw_cache[cid].get("ok", false)):
            draw_witnesses.append(draw_cache[cid].duplicate(true))
        if draw_witnesses.size() == 2:
            break
    if draw_witnesses.size() < 2:
        return {"ok": false, "reason": "Draw cards not executable from initial state"}
    # Same-weapon SETs across attributes are also valid suppliers of weapon state.
    var unique_ids: Array = []
    for cid in deck:
        if not unique_ids.has(cid):
            unique_ids.append(cid)
    unique_ids.sort()
    for set_id in unique_ids:
        var setter: Dictionary = database.cards[set_id]
        if str(setter["weapon_trait_action"]) != "SET":
            continue
        for consume_id in unique_ids:
            var consumer: Dictionary = database.cards[consume_id]
            if str(consumer["weapon_trait_action"]) != "CONSUME" or str(consumer["weapon"]) != str(setter["weapon"]):
                continue
            var witness: Dictionary = _combo_witness(deck, str(set_id), str(consume_id))
            if bool(witness.get("ok", false)):
                return {"ok": true, "complete_sc": audit["completed_sc"], "draw_copies": draw_witnesses, "combo": witness}
    return {"ok": false, "reason": "No SET-to-CONSUME runtime witness from Mana3"}

func _proof_battle(deck: Array, held: Array):
    var b = BattleScript.new()
    b.start_battle(170017, deck, "standard_trio")
    b.hand.clear()
    b.draw_pile = b.database.create_deck_from_ids(deck)
    b.discard_pile.clear()
    for cid in held:
        for i in range(b.draw_pile.size()):
            if str(b.draw_pile[i]["id"]) == str(cid):
                b.hand.append(b.draw_pile.pop_at(i))
                break
    for enemy in b.enemies:
        enemy["hp"] = 100000
        enemy["max_hp"] = 100000
        enemy["block"] = 0
        enemy["vulnerable"] = 0
    b.logs.clear()
    return b

func _play_and_finish(b, cid: String, protected_id: String = "") -> bool:
    var index: int = -1
    for i in range(b.hand.size()):
        if str(b.hand[i]["id"]) == cid:
            index = i
            break
    if index < 0 or not b.use_card(index, 0):
        return false
    for _step in range(16):
        if b.resolving_card.is_empty():
            return not b.combat_over
        if b.is_salvage_selection_active():
            var eligible: Array = b.get_salvage_selectable_indices()
            if eligible.is_empty() or not b.select_discard_for_pending(int(eligible[0])):
                return false
        elif b.is_hand_selection_active():
            var selected: int = -1
            for j in range(b.hand.size() - 1, -1, -1):
                if str(b.hand[j]["id"]) != protected_id:
                    selected = j
                    break
            if selected < 0 or not b.select_hand_for_pending(selected):
                return false
        else:
            return false
    return false

func _draw_witness(deck: Array, cid: String) -> Dictionary:
    var b = _proof_battle(deck, [cid])
    var before: int = int(b.playtest_stats["cards_drawn"])
    var ok: bool = _play_and_finish(b, cid)
    var drawn: int = int(b.playtest_stats["cards_drawn"]) - before
    return {"ok": ok and drawn > 0, "card": cid, "drawn": drawn, "mana_start": 3, "mana_end": b.current_mana, "logs": b.logs.duplicate()}

func _combo_witness(deck: Array, set_id: String, consume_id: String) -> Dictionary:
    var b = _proof_battle(deck, [set_id, consume_id])
    if not _play_and_finish(b, set_id, consume_id):
        return {"ok": false}
    var weapon_state: String = str(database.cards[set_id]["weapon_trait"])
    if not bool(b.weapon_traits.get(weapon_state, false)):
        return {"ok": false}
    var mana_after_set: int = b.current_mana
    var log_start: int = b.logs.size()
    if not _play_and_finish(b, consume_id):
        return {"ok": false}
    var consumed: bool = false
    for i in range(log_start, b.logs.size()):
        if b.logs[i].begins_with(weapon_state + "ON consumed"):
            consumed = true
    return {"ok": consumed, "cards": [set_id, consume_id], "weapon_trait": weapon_state, "mana_start": 3, "mana_after_set": mana_after_set, "mana_end": b.current_mana, "logs": b.logs.duplicate()}
