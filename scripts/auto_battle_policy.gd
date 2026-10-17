class_name AutoBattlePolicy
extends RefCounted

# Public-information, receding-horizon beam search. BattleController owns effects.
const DEPTH := 5
const WIDTH := 20
const PARTICLES := 3
var max_states: int = 3000
# Measured initial Windows work budget. A fixed count keeps decisions reproducible
# across frame timing; 100 ms is a measured target, not a nondeterministic cutoff.
var work_states: int = 240
var time_limit_ms: float = 100.0
var result: Dictionary = {}
var expanded: int = 0
var elapsed_ms: float = 0.0
var done: bool = true
var _properties: Array[String] = []
var _roots: Array = []
var _beam: Array = []
var _next: Array = []
var _tasks: Array = []
var _task_index: int = 0
var _particle: int = 0
var _depth: int = 0
var _scores: Dictionary = {}
var _fallback: Dictionary = {}
var _root_hp: int = 0
var _root_enemy_hp: int = 0
var _root_live: int = 0
var _started: int = 0
var _cpu_us: int = 0

func _init() -> void:
    for prop in BattleController.new().get_script().get_script_property_list():
        _properties.append(str(prop.name))

func _copy(source: BattleController) -> BattleController:
    var copy = BattleController.new()
    for key in _properties:
        # NEVER read the real draw pile or battle RNG (even to clone them).
        if key in ["draw_pile", "battle_rng", "logs"]: continue
        var value = source.get(key)
        copy.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
    return copy

func _clone_sim(source: BattleController) -> BattleController:
    var copy = _copy(source)
    copy.draw_pile = source.draw_pile.duplicate(true) # belief-state samples only
    copy.battle_rng.seed = source.battle_rng.seed
    copy.battle_rng.state = source.battle_rng.state
    copy.logs.assign(source.logs)
    return copy

func _public_root(source: BattleController, sample: int) -> BattleController:
    var copy = _copy(source)
    # Deck composition is public; remove the visible zones as a multiset.
    var remaining: Array = source.battle_deck_ids.duplicate()
    for zone in [source.hand, source.discard_pile, source.power_zone]:
        for card in zone: remaining.erase(str(card.id))
    if not source.resolving_card.is_empty(): remaining.erase(str(source.resolving_card.id))
    remaining.sort()
    copy.draw_pile = copy.database.create_deck_from_ids(remaining)
    # Deterministic, independent belief RNG. No future shuffle stream is copied.
    copy.battle_rng.seed = 71131 + sample * 104729
    copy._shuffle_with_battle_rng(copy.draw_pile)
    return copy

func begin(source: BattleController) -> void:
    result = {}
    expanded = 0
    elapsed_ms = 0
    _cpu_us = 0
    _started = Time.get_ticks_usec()
    done = false
    _roots.clear()
    _scores.clear()
    _fallback.clear()
    _root_hp = source.player_hp
    _root_enemy_hp = _enemy_hp(source)
    _root_live = _live(source)
    for sample in range(PARTICLES): _roots.append(_public_root(source, sample))
    _particle = 0
    _start_particle()

func _start_particle() -> void:
    _depth = 0
    _beam = [{"state": _roots[_particle], "first": {}, "path": ""}]
    _prepare_tasks()

func _prepare_tasks() -> void:
    _tasks.clear()
    _task_index = 0
    _next.clear()
    for node in _beam:
        for action in actions(node.state): _tasks.append({"node": node, "action": action})

func actions(b: BattleController) -> Array:
    var values: Array = []
    if b.combat_over: return values
    if b.is_hand_selection_active():
        var salvage: bool = b.is_salvage_selection_active()
        var indices: Array = b.get_salvage_selectable_indices() if salvage else range(b.hand.size())
        for i in indices:
            var card: Dictionary = b.discard_pile[i] if salvage else b.hand[i]
            values.append({"kind": "salvage" if salvage else "select", "index": i, "id": str(card.id), "target": -1})
    elif b.resolving_card.is_empty():
        for i in range(b.hand.size()):
            if not b.can_use_card(i): continue
            if b.get_effective_target_type(i) == "enemy":
                for target in range(b.enemies.size()):
                    if b.is_enemy_target_valid(target): values.append({"kind": "card", "index": i, "id": str(b.hand[i].id), "target": target})
            else: values.append({"kind": "card", "index": i, "id": str(b.hand[i].id), "target": -1})
        values.append({"kind": "end", "index": -1, "id": "~END", "target": -1})
    values.sort_custom(func(a, c): return action_key(a) < action_key(c))
    return values

func action_key(action: Dictionary) -> String:
    return "%s/%s/%03d/%03d" % [str(action.id), str(action.kind), int(action.target)+1, int(action.index)+1]

func execute(b: BattleController, action: Dictionary) -> bool:
    match str(action.get("kind", "")):
        "card":
            var i: int = int(action.index)
            if i < 0 or i >= b.hand.size() or str(b.hand[i].id) != str(action.id): return false
            return b.use_card(i, int(action.target))
        "select":
            var i: int = int(action.index)
            if i < 0 or i >= b.hand.size() or str(b.hand[i].id) != str(action.id): return false
            return b.select_hand_for_pending(i)
        "salvage":
            var i: int = int(action.index)
            if i < 0 or i >= b.discard_pile.size() or str(b.discard_pile[i].id) != str(action.id): return false
            return b.select_discard_for_pending(i)
        "end":
            if b.combat_over or b.is_hand_selection_active() or not b.resolving_card.is_empty(): return false
            b.end_player_turn()
            return true
    return false

func _enemy_hp(b: BattleController) -> int:
    var total: int = 0
    for enemy in b.enemies: total += maxi(0, int(enemy.hp))
    return total

func _live(b: BattleController) -> int:
    var count: int = 0
    for enemy in b.enemies:
        if int(enemy.hp) > 0: count += 1
    return count

func _value(b: BattleController, ended: bool = false) -> Array:
    var pending: bool = b.is_hand_selection_active()
    var hp_loss: int = maxi(0, _root_hp - b.player_hp)
    var killed: int = _root_live - _live(b)
    var damage: int = _root_enemy_hp - _enemy_hp(b)
    var future: float = 6.0 * b.power_zone.size()
    for trait_name in b.weapon_traits:
        if b.weapon_traits[trait_name]: future += 2.0
    for trait_name in b.attribute_traits: future += float(b.attribute_traits[trait_name]) * 0.4
    var combos: int = 0
    for line in b.logs:
        if "ON consumed" in line: combos += 1
    var prediction = _clone_sim(b)
    var taken_before: int = int(prediction.playtest_stats.get("damage_taken", 0))
    if not ended and not pending and not b.combat_over:
        # Only the imminent enemy phase is scored; future draw has no value here.
        prediction.draw_pile.clear()
        prediction.discard_pile.clear()
        prediction.end_player_turn()
    var incoming: int = maxi(0, int(prediction.playtest_stats.get("damage_taken", 0))-taken_before)
    if ended: incoming = hp_loss
    var survive: int = 0 if prediction.combat_over and not prediction.victory else 1
    var win_now: int = 1 if b.combat_over and b.victory else 0
    if ended: win_now = 0 # enemy-phase victories are scored, but aren't a turn kill
    var utility: float = damage + 3.0 * combos + future + 2.0 * prediction.player_hp - incoming * 2.0
    if pending: utility -= 30.0
    # Ordered priorities, then specification tie-breaks. Remaining Mana rewards economy.
    return [win_now, survive, killed, utility, -hp_loss, -incoming, b.current_mana, future]

func _better(a: Array, b: Array) -> bool:
    for i in range(a.size()):
        if not is_equal_approx(float(a[i]), float(b[i])): return float(a[i]) > float(b[i])
    return false

func _record(table: Dictionary, key: String, action: Dictionary, value: Array) -> void:
    if not table.has(key): table[key] = {"action": action, "samples": {}}
    var samples: Dictionary = table[key].samples
    if not samples.has(_particle) or _better(value, samples[_particle]): samples[_particle] = value

func step(slice_ms: float = 4.0) -> void:
    if done: return
    var slice_start: int = Time.get_ticks_usec()
    while not done and Time.get_ticks_usec()-slice_start < int(slice_ms*1000):
        if _depth >= 1 and expanded >= ((_particle+1)*mini(max_states,work_states)/PARTICLES):
            _particle += 1
            if _particle >= PARTICLES:
                _finish()
                break
            _start_particle()
            continue
        if _task_index >= _tasks.size():
            _depth += 1
            _next.sort_custom(func(a, b): return _better(a.value,b.value) if a.value != b.value else a.path < b.path)
            _beam = _next.slice(0, WIDTH)
            if _depth >= DEPTH or _beam.is_empty() or expanded >= ((_particle+1)*mini(max_states,work_states)/PARTICLES):
                _particle += 1
                if _particle >= PARTICLES:
                    _finish()
                    break
                _start_particle()
            else: _prepare_tasks()
            continue
        var task: Dictionary = _tasks[_task_index]
        _task_index += 1
        expanded += 1
        var action: Dictionary = task.action
        var b = _clone_sim(task.node.state)
        var ended: bool = str(action.kind) == "end"
        if not execute(b, action): continue
        var first: Dictionary = action if task.node.first.is_empty() else task.node.first
        var key: String = action_key(first)
        var value: Array = _value(b,ended)
        # Unresolved mandatory choices are never treated as completed turn plans.
        if not b.is_hand_selection_active(): _record(_scores,key,first,value)
        if _depth == 0: _record(_fallback,key,first,value)
        if not ended and not b.combat_over:
            _next.append({"state": b, "first": first, "value": value, "path": str(task.node.path)+action_key(action)})
    _cpu_us += Time.get_ticks_usec()-slice_start
    elapsed_ms = float(_cpu_us)/1000.0

func _finish() -> void:
    var best: Array = []
    var best_key: String = ""
    for key in _fallback:
        var entry: Dictionary = _scores.get(key,_fallback[key])
        var total: Array = []
        for sample in range(PARTICLES):
            var value: Array = entry.samples.get(sample,_fallback[key].samples.get(sample,[]))
            if value.is_empty(): total.clear(); break
            if total.is_empty(): total.resize(value.size()); total.fill(0.0)
            for i in range(value.size()): total[i] += float(value[i])/PARTICLES
        if total.is_empty(): continue
        if best.is_empty() or _better(total,best) or (total == best and str(key)<best_key):
            best = total
            best_key = str(key)
            result = entry.action.duplicate()
    done = true

func choose(b: BattleController) -> Dictionary:
    begin(b)
    while not done: step(4.0)
    return result
