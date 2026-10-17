class_name RankedInitialDeckGenerator
extends RefCounted

const BaseGenerator = preload("res://scripts/initial_deck_generator.gd")
const Policy = preload("res://scripts/initial_deck_rank_policy.gd")
const PROFILE_VERSION = "initial_ranked_v1"
const SLOTS = ["main_weapon","offhand","head","body","hands","feet"]
const POLICIES = ["baseline","defense1","search2"]
var base = BaseGenerator.new()
var evaluator = Policy.new()
var cancellation: Callable
var progress: Callable

func cancelled() -> bool:
    return cancellation.is_valid() and bool(cancellation.call())

func stage(label: String) -> void:
    if progress.is_valid():
        progress.call(label)

func failure(reason: String) -> Dictionary:
    return {"ok":false,"items":{},"profile":PROFILE_VERSION,"reason":reason}

func build_package(items: Dictionary) -> Dictionary:
    var builder = LoadoutBuilder.new()
    if not builder.load_data():
        return {}
    for slot in SLOTS:
        var item: Dictionary = items[slot]
        builder.equipment_db.items[item.instance_id] = item.duplicate(true)
        if not builder.set_equipment(slot,item.instance_id):
            return {}
    if not builder.is_valid() or builder.build_deck_ids().size()!=24:
        return {}
    return {"deck":builder.build_deck_ids(),"snapshot":builder.get_snapshot(),"max_hp":builder.calculate_player_max_hp()}

func candidate_pool(template_ids: Dictionary, seed_value: int) -> Dictionary:
    var generated: Dictionary = base.generate_initial_loadout(template_ids,seed_value,base.PROFILE_VERSION,256,cancellation)
    if not generated.get("ok",false):
        return failure(str(generated.get("status","BASE_FAILED")))
    var baseline: Dictionary = generated.items
    var main: Dictionary = baseline.main_weapon
    var context: Dictionary = {"weapon":main.affinity_weapon,"attribute":main.rolled_attribute,"core_cards":main.fixed_cards.duplicate()}
    var rng = RandomNumberGenerator.new()
    rng.seed = hash("STEP23_external|%d" % seed_value)
    var accepted: Array = []
    var seen: Dictionary = {}
    var trials: int = 0
    for attempt in range(256):
        if cancelled():
            return failure("CANCELLED")
        trials += 1
        var candidate: Dictionary = baseline.duplicate(true)
        if attempt>0:
            for slot in SLOTS:
                var item: Dictionary = candidate[slot]
                var sampled: Array = base._sample_random_package(item,context,rng)
                item.random_cards = sampled
                item.cards = item.fixed_cards + sampled
                if slot=="main_weapon" and sampled.size()==2:
                    item.secondary_attribute = str(base.database.cards[sampled[0]].attribute)
        if not base.validate_package(candidate):
            continue
        var key: String = str(base.roller.inspect_deck(candidate).deck)
        if seen.has(key):
            continue
        var evidence: Dictionary = base.verify_synergy(candidate)
        if not evidence.get("ok",false):
            continue
        seen[key] = true
        var index: int = accepted.size()
        for slot in SLOTS:
            candidate[slot].instance_id = str(baseline[slot].instance_id)+"_EXTERNAL_STEP23_"+str(index)
        var package: Dictionary = build_package(candidate)
        if package.is_empty():
            return failure("PACKAGE_ERROR")
        accepted.append({"id":index,"items":candidate,"package":package,"score":0.0,"eligible":true})
        if accepted.size()>=8:
            break
    if accepted.is_empty():
        return failure("NO_BASE_CANDIDATE")
    return {"ok":true,"candidates":accepted,"trials":trials}

func measure(package: Dictionary, seed_value: int, policy: String, turns: int, actions: int) -> Dictionary:
    return evaluator.evaluate(package,seed_value,policy,{"turns":turns,"actions":actions},cancellation)

func fatal_error(result: Dictionary) -> bool:
    return str(result.get("error","")) not in ["","POLICY_ACTION_LIMIT"]

func collect(candidate: Dictionary, first_seed: int = 181300) -> Array:
    var results: Array = []
    for battle_seed in range(first_seed,first_seed+16):
        stage("継続比較: 候補%d %d/16" % [int(candidate.id),battle_seed-first_seed+1])
        for policy in POLICIES:
            if cancelled():
                return []
            var result: Dictionary = measure(candidate.package,battle_seed,policy,60,48)
            results.append(result)
            if fatal_error(result):
                return results
    return results

func generate(template_ids: Dictionary, seed_value: int, cancel: Callable = Callable(), notify: Callable = Callable()) -> Dictionary:
    cancellation = cancel
    progress = notify
    stage("候補確認")
    var pool: Dictionary = candidate_pool(template_ids,seed_value)
    if not pool.get("ok",false):
        return pool
    stage("初ターン比較")
    var candidates: Array = pool.candidates
    for candidate in candidates:
        var total: float = 0.0
        for battle_seed in range(181100,181104):
            for policy in POLICIES:
                if cancelled():
                    return failure("CANCELLED")
                var result: Dictionary = measure(candidate.package,battle_seed,policy,1,12)
                if fatal_error(result):
                    return failure(str(result.error))
                if result.error!="":
                    candidate.eligible = false
                    continue
                var first: Dictionary = result.turns[0]
                total += 0.40*(1.0 if first.same_turn_pairs>0 else 0.0)
                total += 0.35*clampf(float(first.hp_after_enemy_phase)/float(candidate.package.max_hp),0.0,1.0)
                total += 0.25*clampf(float(result.enemy_hp_start-first.enemy_hp_after_cards)/float(result.enemy_hp_start),0.0,1.0)
        candidate.score = total/12.0
    var ranked: Array = candidates.filter(func(c):return c.eligible)
    ranked.sort_custom(func(a,b):return a.score>b.score if a.score!=b.score else a.id<b.id)
    var selected: Array = [0]
    for i in range(mini(2,ranked.size())):
        if not selected.has(ranked[i].id):
            selected.append(ranked[i].id)
    stage("継続比較")
    var rows: Dictionary = {}
    for id in selected:
        rows[id] = collect(candidates[id])
        if cancelled():
            return failure("CANCELLED")
        for result in rows[id]:
            if fatal_error(result):
                return failure(str(result.error))
    var metrics: Array = []
    for id in selected:
        metrics.append(evaluator.comparison(rows[0],rows[id],id))
    var qualified: Array = metrics.filter(func(m):return m.eligible or m.id==0)
    qualified.sort_custom(func(a,b):
        if a.total_wins!=b.total_wins:return a.total_wins>b.total_wins
        if a.paired_turn_delta!=b.paired_turn_delta:return a.paired_turn_delta<b.paired_turn_delta
        if a.combos!=b.combos:return a.combos>b.combos
        if a.id==0 or b.id==0:return a.id==0
        return a.id<b.id)
    var chosen_id: int = int(qualified[0].id)
    var items: Dictionary = candidates[chosen_id].items.duplicate(true)
    if cancelled():
        return failure("CANCELLED")
    if not base.validate_package(items) or not base.verify_synergy(items).get("ok",false):
        return failure("FINAL_VALIDATION_FAILED")
    # Namespace includes all six template IDs, avoiding collisions across input packages.
    var namespace_parts: Array[String] = []
    for slot in SLOTS:
        namespace_parts.append(str(template_ids[slot]))
    var package_namespace: String = "_".join(namespace_parts)
    for slot in SLOTS:
        items[slot].instance_id = "STEP27_%s_%s_%d_%s" % [PROFILE_VERSION,package_namespace,seed_value,slot]
    return {"ok":true,"items":items,"profile":PROFILE_VERSION,"reason":"","audit":{"chosen_id":chosen_id,"selected":selected,"trials":pool.trials,"scores":candidates.map(func(c):return c.score),"metrics":metrics,"candidates":candidates.size()}}
