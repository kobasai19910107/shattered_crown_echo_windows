class_name InitialDeckRankPolicy
extends RefCounted

# STEP26 approved finite ranking policy. All battle effects stay in BattleController.
const Sim = preload("res://scripts/battle_simulation_runner.gd")
var sim = Sim.new()
var policy: String = "baseline"
var variables: Array[String] = []
var branch_count: int = 0
var choice_count: int = 0
var clone_errors: int = 0
var run_turn_limit: int = 60
var run_action_limit: int = 48
var cancellation: Callable

func _init() -> void:
    var specimen = BattleController.new()
    for prop in specimen.get_script().get_script_property_list():
        if specimen.get(str(prop.name)) != null:
            variables.append(str(prop.name))

func cancelled() -> bool:
    return cancellation.is_valid() and bool(cancellation.call())

func evaluate(package: Dictionary, seed_value: int, policy_name: String, limits: Dictionary = {}, cancel: Callable = Callable()) -> Dictionary:
    cancellation = cancel
    policy = policy_name
    run_turn_limit = int(limits.get("turns",60))
    run_action_limit = int(limits.get("actions",48))
    if not policy in ["baseline","defense1","search2"] or variables.size()!=40:
        return {"error":"INVALID_POLICY_STATE"}
    var previous_errors: int = clone_errors
    var result: Dictionary = run_battle(package,seed_value)
    if cancelled():
        result.error = "CANCELLED"
    elif clone_errors != previous_errors:
        result.error = "CLONE_MISMATCH"
    result["battle_seed"] = seed_value
    result["policy"] = policy_name
    return result

func hand_ids(b) -> Array:
    var result: Array = []
    for c in b.hand:
        result.append(c["id"])
    return result

func active_consumer(b, c: Dictionary) -> bool:
    if str(c.get("weapon_trait_action","")) != "CONSUME":
        return false
    if not bool(b.weapon_traits.get(str(c["weapon_trait"]),false)):
        return false
    match str(c["weapon"]):
        "刀": return bool(c.get("iai_compatible",false))
        "魔法剣": return int(c.get("attribute_trait_gain",0)) > 0
        "レイピア", "短剣", "大剣": return str(c["card_type"]) == "attack"
        "片手剣": return true
    return false

func score(b, c: Dictionary, i: int) -> float:
    var value: float = sim._score_card_for_autoplay(b,c,i)
    if active_consumer(b,c):
        value += 500.0
    if str(c.get("weapon_trait_action","")) == "SET":
        for other in b.hand:
            if str(other.get("weapon_trait_action","")) == "CONSUME" and str(other["weapon"]) == str(c["weapon"]):
                var future_cost: int = 0 if str(other["weapon"]) == "刀" and bool(other.get("iai_compatible",false)) else int(other["cost"])
                if b.get_effective_cost(i) + future_cost <= b.current_mana:
                    value += 350.0
                    break
    if int(c.get("draw_count",0)) > 0:
        value += 180.0
    return value

func resolve_selection(b) -> bool:
    for _i in range(16):
        if cancelled():
            return false
        if not b.is_hand_selection_active():
            return b.resolving_card.is_empty() or b.combat_over
        if b.is_salvage_selection_active():
            var eligible: Array = b.get_salvage_selectable_indices()
            var chosen: int = -1
            var best: float = -INF
            for j in eligible:
                var value: float = sim._score_card_for_autoplay(b,b.discard_pile[j],0)
                if value > best:
                    best = value
                    chosen = j
            if chosen < 0 or not b.select_discard_for_pending(chosen):
                return false
        else:
            var chosen: int = -1
            var worst: float = INF
            for j in range(b.hand.size()):
                var value: float = score(b,b.hand[j],j)
                if value < worst:
                    worst = value
                    chosen = j
            if chosen < 0 or not b.select_hand_for_pending(chosen):
                return false
    return false

func choose_baseline(b) -> int:
    var best: int = -1
    var best_score: float = -INF
    for i in range(b.hand.size()):
        if cancelled():
            return -1
        if not b.can_use_card(i):
            continue
        if b.get_effective_target_type(i) == "enemy" and sim._choose_target(b) < 0:
            continue
        var current: float = score(b,b.hand[i],i)
        if current > best_score:
            best_score = current
            best = i
    return best

func state_signature(b) -> String:
    var data: Dictionary = {}
    for key in variables:
        var value = b.get(key)
        if key == "database":
            continue
        if key == "battle_rng":
            data[key] = [value.seed,value.state]
        else:
            data[key] = value
    return JSON.stringify(data)

func copy_battle(b):
    var c = BattleController.new()
    for key in variables:
        var value = b.get(key)
        if key == "battle_rng":
            c.battle_rng.seed = b.battle_rng.seed
            c.battle_rng.state = b.battle_rng.state
        elif value is Dictionary or value is Array:
            c.set(key,value.duplicate(true))
        else:
            c.set(key,value)
    if state_signature(c) != state_signature(b):
        clone_errors += 1
    return c

func enemy_hp(b) -> int:
    var total: int = 0
    for e in b.enemies:
        total += maxi(0,int(e.hp))
    return total

func utility(b, original_enemy_hp: int, combo_events: int) -> float:
    var c = copy_battle(b)
    var damage: int = original_enemy_hp - enemy_hp(c)
    if not c.combat_over:
        c.end_player_turn()
    if c.victory:
        return 100000.0 + c.player_hp
    if c.combat_over:
        return -100000.0 + damage
    return 4.0*c.player_hp + damage + 10.0*combo_events + 5.0*c.power_zone.size()

func consume_count(b) -> int:
    var count: int = 0
    for line in b.logs:
        for state in ["流転","精密","連刃","重撃","魔導","納刀"]:
            if line.begins_with(state + "ON consumed"):
                count += 1
    return count

func branch(b, index: int):
    var c = copy_battle(b)
    c.logs.clear()
    var target: int = sim._choose_target(c) if c.get_effective_target_type(index) == "enemy" else -1
    branch_count += 1
    if not c.use_card(index,target) or not resolve_selection(c):
        clone_errors += 1
        return null
    return c

func choose(b) -> int:
    if policy == "baseline":
        return choose_baseline(b)
    var signature: String = state_signature(b)
    var best: int = -1
    var best_value: float = -INF
    var original_hp: int = enemy_hp(b)
    for i in range(b.hand.size()):
        if cancelled():
            return -1
        if not b.can_use_card(i):
            continue
        var c = branch(b,i)
        if c == null:
            continue
        var events: int = consume_count(c)
        var value: float = utility(c,original_hp,events)
        if policy == "search2" and not c.combat_over:
            for j in range(c.hand.size()):
                if cancelled():
                    return -1
                if not c.can_use_card(j):
                    continue
                var d = branch(c,j)
                if d != null:
                    value = maxf(value,utility(d,original_hp,events+consume_count(d)))
        if value > best_value:
            best = i
            best_value = value
    choice_count += 1
    if signature != state_signature(b):
        clone_errors += 1
    return best

func run_battle(p: Dictionary, battle_seed: int) -> Dictionary:
    var b = BattleController.new()
    b.start_battle(battle_seed,p["deck"],"standard_trio",p["snapshot"])
    var enemy_hp_start: int = enemy_hp(b)
    var initial: Array = hand_ids(b)
    var turns: Array = []
    var checkpoint20: Dictionary = {}
    var error: String = ""
    var first_combo_turn: int = 0
    while not cancelled() and not b.combat_over and b.turn_number <= run_turn_limit:
        var t: Dictionary = {"turn":b.turn_number,"hand_start":hand_ids(b),"mana_start":b.current_mana,"hp_start":b.player_hp,"actions":[],"consumptions":0,"same_turn_pairs":0,"effect_draw":0,"mana_gained":0}
        var setters: Dictionary = {}
        var action_count: int = 0
        while not cancelled() and not b.combat_over and action_count < run_action_limit:
            var index: int = choose(b)
            if index < 0:
                break
            var card: Dictionary = b.hand[index].duplicate(true)
            var target: int = sim._choose_target(b) if b.get_effective_target_type(index) == "enemy" else -1
            var detail: Dictionary = {"hand_before":hand_ids(b),"block_before":b.player_block,"hp_before":b.player_hp,"enemies_before":b.enemies.duplicate(true),"score":score(b,card,index)}
            var mana_before: int = b.current_mana
            var drawn_before: int = int(b.playtest_stats["cards_drawn"])
            var gained_before: int = int(b.playtest_stats["mana_gained"])
            b.logs.clear()
            if not b.use_card(index,target) or not resolve_selection(b):
                error = "Card use or pending selection could not complete: " + str(card["id"])
                break
            var consumed_states: Array = []
            for line in b.logs:
                for state in ["流転","精密","連刃","重撃","魔導","納刀"]:
                    if line.begins_with(state + "ON consumed"):
                        consumed_states.append(state)
            if str(card.get("weapon_trait_action","")) == "SET":
                var state: String = str(card["weapon_trait"])
                if bool(b.weapon_traits.get(state,false)):
                    setters[state] = str(card["id"])
            for state in consumed_states:
                t["consumptions"] += 1
                if setters.has(state):
                    t["same_turn_pairs"] += 1
                if first_combo_turn == 0:
                    first_combo_turn = b.turn_number
            var drawn: int = int(b.playtest_stats["cards_drawn"]) - drawn_before
            var gained: int = int(b.playtest_stats["mana_gained"]) - gained_before
            t["effect_draw"] += drawn
            t["mana_gained"] += gained
            detail.merge({"card":card["id"],"target":target,"mana_before":mana_before,"mana_after":b.current_mana,"draw":drawn,"mana_gain":gained,"consumed":consumed_states,"from_initial_hand":initial.has(card["id"]),"hand_after":hand_ids(b),"block_after":b.player_block,"hp_after":b.player_hp,"enemies_after":b.enemies.duplicate(true),"logs":b.logs.duplicate()})
            t["actions"].append(detail)
            action_count += 1
            if b.current_mana < 0 or b.hand.size() > 10:
                error = "Negative Mana or hand limit violated"
                break
        t["mana_unused"] = b.current_mana
        t["hp_after_cards"] = b.player_hp
        t["enemy_hp_after_cards"] = enemy_hp(b)
        if action_count >= run_action_limit:
            error = "POLICY_ACTION_LIMIT"
        if error != "":
            turns.append(t)
            break
        if not b.combat_over:
            b.end_player_turn()
        t["hp_after_enemy_phase"] = b.player_hp
        turns.append(t)
        if t["turn"] == 20:
            checkpoint20 = b.get_playtest_report()
    var outcome: String = "victory" if b.victory else ("defeat" if b.combat_over else "turn_limit")
    return {"enemy_hp_start":enemy_hp_start,"enemy_hp_end":enemy_hp(b),"checkpoint20":checkpoint20,"initial_hand":initial,"initial_mana":turns[0]["mana_start"] if not turns.is_empty() else -1,"outcome":outcome,"turns_played":turns.size(),"first_combo_turn":first_combo_turn,"turns":turns,"stats":b.get_playtest_report(),"error":error}

func row_key(r: Dictionary) -> String:
    return "%d/%s" % [int(r.battle_seed),str(r.policy)]

func invalid_comparison(candidate_id: int, reason: String) -> Dictionary:
    return {"id":candidate_id,"eligible":false,"reasons":[reason],"regressions":[],"wins":{},"reference_wins":{},"total_wins":0,"combos":0,"paired_count":0,"paired_turn_delta":0.0,"incomplete":48}

func comparison(current: Array, candidate: Array, candidate_id: int) -> Dictionary:
    if current.size()!=48 or candidate.size()!=48:
        return invalid_comparison(candidate_id,"missing_rows")
    var by_key: Dictionary = {}
    for r in candidate:
        by_key[row_key(r)] = r
    if by_key.size()!=48:
        return invalid_comparison(candidate_id,"duplicate_rows")
    for r in current:
        if not by_key.has(row_key(r)):
            return invalid_comparison(candidate_id,"missing_rows")
    var eligible: bool = true
    var reasons: Array = []
    var regressions: Array = []
    var wins: Dictionary = {"baseline":0,"defense1":0,"search2":0}
    var reference_wins: Dictionary = wins.duplicate()
    var total_wins: int = 0
    var combos: int = 0
    var delta_sum: int = 0
    var paired_count: int = 0
    var incomplete: int = 0
    for r in current:
        var s: Dictionary = by_key[row_key(r)]
        if r.error!="" or r.outcome not in ["victory","defeat"]:
            eligible = false
            if not reasons.has("current_incomplete"):
                reasons.append("current_incomplete")
        if s.error!="" or s.outcome not in ["victory","defeat"]:
            eligible = false
            incomplete += 1
            if not reasons.has("candidate_incomplete"):
                reasons.append("candidate_incomplete")
        if r.outcome=="victory":
            reference_wins[r.policy] += 1
        if s.outcome=="victory":
            wins[s.policy] += 1
            total_wins += 1
        if s.turns[0].same_turn_pairs>0:
            combos += 1
        if r.outcome=="victory" and s.outcome=="defeat":
            regressions.append(row_key(r))
            eligible = false
        if r.outcome=="victory" and s.outcome=="victory":
            delta_sum += int(s.turns_played)-int(r.turns_played)
            paired_count += 1
    if not regressions.is_empty():
        reasons.append("current_victory_to_candidate_defeat")
    for current_policy in wins:
        if wins[current_policy]<reference_wins[current_policy]:
            eligible = false
            reasons.append("fewer_wins_"+str(current_policy))
    return {"id":candidate_id,"eligible":eligible,"reasons":reasons,"regressions":regressions,"wins":wins,"reference_wins":reference_wins,"total_wins":total_wins,"combos":combos,"paired_count":paired_count,"paired_turn_delta":float(delta_sum)/paired_count if paired_count>0 else 0.0,"incomplete":incomplete}
