class_name HubLoadoutAdvisor
extends RefCounted

# Advisory only: read copies of owned items, never mutate Region1RunController.state.
# The ranking is a transparent deck-structure heuristic, not a simulated win rate.
const PROFILES = [
    {"title":"コンボ重視", "id":"combo"},
    {"title":"手札循環重視", "id":"cycle"},
    {"title":"攻撃重視", "id":"attack"},
    {"title":"最大HP重視", "id":"hp"}
]

func suggest(inventory: Dictionary, equipped: Dictionary, analyzer: HubDeckAnalyzer) -> Array:
    if not analyzer.loaded:
        return []
    var buckets: Dictionary = {}
    var equipped_uids: Dictionary = {}
    for slot in HubDeckAnalyzer.SLOTS:
        buckets[slot] = []
        equipped_uids[slot] = str(equipped.get(slot, ""))

    for raw_uid in inventory.keys():
        var uid: String = str(raw_uid)
        var item: Dictionary = inventory[raw_uid]
        var slot: String = str(item.get("slot", ""))
        if not buckets.has(slot) or item.get("cards", []).size() != 4:
            continue
        if item.get("fixed_cards", []).size() != 2 or item.get("random_cards", []).size() != 2:
            continue
        buckets[slot].append(uid)

    for slot in HubDeckAnalyzer.SLOTS:
        var choices: Array = buckets[slot]
        choices.sort_custom(func(a: String, b: String) -> bool:
            var left: int = int(inventory[a].get("effective_hp", inventory[a].get("base_hp", 0)))
            var right: int = int(inventory[b].get("effective_hp", inventory[b].get("base_hp", 0)))
            return left > right if left != right else a < b)
        if choices.is_empty():
            return []
        # Retain the current item even if the warehouse grows beyond the UI review budget.
        if choices.size() > 24:
            var subset: Array = choices.slice(0, 24)
            if not subset.has(equipped_uids[slot]) and choices.has(equipped_uids[slot]):
                subset[23] = equipped_uids[slot]
            buckets[slot] = subset

    var baseline: Dictionary = {}
    for slot in HubDeckAnalyzer.SLOTS:
        baseline[slot] = equipped_uids[slot] if buckets[slot].has(equipped_uids[slot]) else str(buckets[slot][0])

    var suggestions: Array = []
    var used: Dictionary = {}
    for profile in PROFILES:
        var key: String = str(profile.id)
        var best: Dictionary = _optimize(key, baseline, buckets, inventory, analyzer)
        var unique: Dictionary = _best_unused_neighbor(best, key, used, buckets, inventory, analyzer)
        var signature: String = _signature(unique)
        if used.has(signature):
            continue
        used[signature] = true
        suggestions.append(_record(str(profile.title), unique, equipped_uids, inventory, analyzer))

    return suggestions

func _items(uids: Dictionary, inventory: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for slot in HubDeckAnalyzer.SLOTS:
        var uid: String = str(uids.get(slot, ""))
        if inventory.has(uid):
            result[slot] = inventory[uid]
    return result

func _rank(profile: String, items: Dictionary, analyzer: HubDeckAnalyzer) -> float:
    var data: Dictionary = analyzer.analyze(items)
    var sc: float = float(data.get("completed_sc", 0))
    var orphan: float = float(data.get("orphan_pairs", 0))
    var duplicate_orphan: float = float(data.get("orphan", 0))
    var cycle: float = float(data.get("cycle", 0))
    var attack: float = float(data.get("attack", 0))
    var hp: float = float(data.get("hp", 0))
    match profile:
        "combo": return sc*140.0-orphan*28.0-duplicate_orphan*6.0+cycle*12.0+attack*4.0+hp*0.20
        "cycle": return cycle*75.0+sc*68.0-orphan*18.0-duplicate_orphan*4.0+attack*3.0+hp*0.15
        "attack": return attack*37.0+sc*85.0-orphan*18.0-duplicate_orphan*4.0+cycle*8.0+hp*0.18
        "hp": return hp*2.3+sc*36.0-orphan*12.0-duplicate_orphan*3.0+cycle*4.0+attack*4.0
    return 0.0

func _optimize(profile: String, baseline: Dictionary, buckets: Dictionary, inventory: Dictionary, analyzer: HubDeckAnalyzer) -> Dictionary:
    var starts: Array = [baseline.duplicate(true)]
    var highest_hp: Dictionary = {}
    for slot in HubDeckAnalyzer.SLOTS:
        highest_hp[slot] = buckets[slot][0]
    if _signature(highest_hp) != _signature(baseline):
        starts.append(highest_hp)

    var winner: Dictionary = baseline.duplicate(true)
    var winner_score: float = -INF
    for seed in starts:
        var current: Dictionary = seed.duplicate(true)
        var score: float = _rank(profile, _items(current, inventory), analyzer)
        for _pass in range(2):
            var improved: bool = false
            for slot in HubDeckAnalyzer.SLOTS:
                var best_uid: String = str(current[slot])
                var best_score: float = score
                for raw_uid in buckets[slot]:
                    var uid: String = str(raw_uid)
                    if uid == best_uid:
                        continue
                    var candidate: Dictionary = current.duplicate(true)
                    candidate[slot] = uid
                    var candidate_score: float = _rank(profile, _items(candidate, inventory), analyzer)
                    if candidate_score > best_score + 0.0001:
                        best_score = candidate_score
                        best_uid = uid
                if best_uid != str(current[slot]):
                    current[slot] = best_uid
                    score = best_score
                    improved = true
            if not improved:
                break
        if score > winner_score:
            winner = current
            winner_score = score
    return winner

func _best_unused_neighbor(original: Dictionary, profile: String, used: Dictionary, buckets: Dictionary, inventory: Dictionary, analyzer: HubDeckAnalyzer) -> Dictionary:
    if not used.has(_signature(original)):
        return original
    var best: Dictionary = original
    var best_score: float = -INF
    # A distinct candidate may require one or two slot substitutions; do not change
    # anything in the actual loadout to generate the alternatives.
    for slot in HubDeckAnalyzer.SLOTS:
        for raw_uid in buckets[slot]:
            var uid: String = str(raw_uid)
            if uid == str(original[slot]):
                continue
            var proposal: Dictionary = original.duplicate(true)
            proposal[slot] = uid
            if used.has(_signature(proposal)):
                continue
            var score: float = _rank(profile, _items(proposal, inventory), analyzer)
            if score > best_score:
                best = proposal
                best_score = score
    return best

func _signature(uids: Dictionary) -> String:
    var chunks: PackedStringArray = []
    for slot in HubDeckAnalyzer.SLOTS:
        chunks.append(str(uids.get(slot, "")))
    return "|".join(chunks)

func _record(title: String, uids: Dictionary, equipped: Dictionary, inventory: Dictionary, analyzer: HubDeckAnalyzer) -> Dictionary:
    var changes: int = 0
    for slot in HubDeckAnalyzer.SLOTS:
        if str(uids.get(slot, "")) != str(equipped.get(slot, "")):
            changes += 1
    return {"title":title, "uids":uids.duplicate(true), "analysis":analyzer.analyze(_items(uids, inventory)), "changes":changes}
