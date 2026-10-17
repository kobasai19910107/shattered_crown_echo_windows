class_name CoopBattleController
extends RefCounted

var players: Array[CoopPlayerState] = []
var active: int = 0
var round_number: int = 1
var next_target: int = 0
var finished: bool = false
var victory: bool = false
var poison_owner: Dictionary = {}
var enemy_rng = RandomNumberGenerator.new()

func start(seed_value: int, loadouts: Array, hp: Array, ids: Array, supports: Array) -> bool:
    if loadouts.size()!=2 or hp.size()!=2 or supports.size()!=2: return false
    var roller=Step8EquipmentRoller.new()
    if not roller.load_data(): return false
    players.clear()
    active=0; round_number=1; next_target=0; finished=false; victory=false; poison_owner.clear()
    enemy_rng.seed=seed_value+7919
    for i in range(2):
        var b=CoopPlayerState.new()
        var deck: Array=roller.inspect_deck(loadouts[i]).get("deck",[])
        if deck.size()!=24 or not b.start_region1(seed_value+i*104729,deck,ids,loadouts[i],maxi(1,int(hp[i])),supports[i]): return false
        b.seat=i
        if int(hp[i])==0: b.player_hp=0
        players.append(b)
    players[1].enemies=players[0].enemies
    for b in players: b.party=weakref(self)
    if players[0].player_hp<=0: active=1
    return true

func finish(won: bool, reason: String) -> void:
    if finished: return
    finished=true; victory=won
    for b in players: b.finalize_team(won,reason)

func check_finish() -> void:
    if finished: return
    if players.all(func(b): return b.player_hp<=0):
        finish(false,"team_hp_zero"); return
    if players[0].enemies.all(func(e): return int(e.hp)<=0): finish(true,"all_enemies_defeated")

func apply(seat: int, action: Dictionary) -> bool:
    if finished or seat!=active or seat<0 or seat>1 or players[seat].player_hp<=0: return false
    var before=export_state()
    var poison: Array=players[0].enemies.map(func(e):return int(e.attribute_traits.get("猛毒",0)))
    var policy=AutoBattlePolicy.new()
    if not policy.execute(players[seat],action):
        import_state(before)
        return false
    if str(action.get("kind",""))!="end":
        for i in range(players[0].enemies.size()):
            var amount: int=int(players[0].enemies[i].attribute_traits.get("猛毒",0))
            if i<poison.size() and amount>int(poison[i]): poison_owner[str(i)]=seat
            if amount==0: poison_owner.erase(str(i))
    check_finish()
    if not finished and players[active].player_hp<=0: end_turn(active,true)
    return true

func end_turn(seat: int, dead: bool=false) -> void:
    if finished or seat!=active: return
    var b: CoopPlayerState=players[seat]
    if not dead and (b.is_hand_selection_active() or not b.resolving_card.is_empty()): return
    if b.player_hp>0: b.finish_player_turn_effects()
    else:
        b.resolving_card={}; b.pending_hand_selection={"mode":"","remaining":0}
    check_finish()
    if finished: return
    if seat==0 and players[1].player_hp>0:
        active=1
        if round_number>1: players[1]._player_turn_start(false)
        return
    enemy_phase()
    if finished: return
    round_number+=1
    for player in players: player.turn_number=round_number
    active=0 if players[0].player_hp>0 else 1
    players[active]._player_turn_start(false)

func target_from(cursor: int) -> int:
    if players[cursor].player_hp>0: return cursor
    return 1-cursor

func enemy_phase() -> void:
    for b in players:
        b.first_slow_engine_used=false; b.first_retaliation_engine_used=false
    var shared: Array=players[0].enemies
    # New summons wait until the next enemy phase, exactly as in solo play.
    var count: int=shared.size()
    for i in range(count):
        var enemy: Dictionary=shared[i]
        if int(enemy.hp)<=0 or int(enemy.get("summoned_turn",-1))==round_number: continue
        var phase: int=int(enemy.get("phase_index",0))
        var target: int=target_from(next_target)
        var intent: Dictionary=players[target].get_enemy_intent(i)
        for raw in intent.get("actions",[]):
            if finished or int(enemy.hp)<=0 or int(enemy.get("phase_index",0))!=phase: break
            var action: Dictionary=raw
            if str(action.get("type",""))=="attack":
                target=target_from(next_target)
                next_target=1-target
            var b: CoopPlayerState=players[target]
            var rng=b.battle_rng
            b.battle_rng=enemy_rng
            b.perform_enemy_action(i,action,phase)
            b.battle_rng=rng
            check_finish()
            if finished: return
    for i in range(shared.size()):
        var owner: int=int(poison_owner.get(str(i),0))
        players[owner].resolve_enemy_poison(i)
        if int(shared[i].attribute_traits.get("猛毒",0))==0: poison_owner.erase(str(i))
        check_finish()
        if finished: return
    check_finish()
    if finished: return
    for b in players:
        if b.player_hp>0: CampaignCombat.enemy_turn_end(b)
    check_finish()
    if finished: return
    for enemy in shared:
        if int(enemy.hp)>0: enemy.hp=mini(int(enemy.max_hp),int(enemy.hp)+int(enemy.r1_status.get("Regen",0)))
    for b in players:
        b.first_slow_engine_used=false; b.first_retaliation_engine_used=false
    for enemy in shared:
        if int(enemy.hp)>0 and int(enemy.get("summoned_turn",-1))!=round_number:
            RegionEnemyCatalog.new().advance(enemy,enemy_rng)

func intent_targets() -> Array:
    var result: Array=[]
    var cursor: int=next_target
    for i in range(players[0].enemies.size()):
        var target: int=target_from(cursor)
        var intent: Dictionary=players[target].get_enemy_intent(i)
        var targets: Array=[]
        for action in intent.get("actions",[]):
            if str(action.get("type",""))=="attack":
                target=target_from(cursor); targets.append(target+1); cursor=1-target
        result.append({"intent":intent,"targets":targets})
    return result

func export_state() -> Dictionary:
    return {"players":players.map(func(b):return b.export_region1_state()),"active":active,"round":round_number,
        "next_target":next_target,"finished":finished,"victory":victory,"poison_owner":poison_owner.duplicate(true),"enemy_rng":str(enemy_rng.state)}

func import_state(data: Dictionary) -> bool:
    if not data.get("players") is Array or data.players.size()!=2: return false
    if int(data.get("active",-1)) not in [0,1] or int(data.get("next_target",-1)) not in [0,1] or int(data.get("round",0))<1: return false
    if not str(data.get("enemy_rng","")).is_valid_int() or not data.get("poison_owner") is Dictionary: return false
    if not data.get("finished") is bool or not data.get("victory") is bool: return false
    var restored: Array[CoopPlayerState]=[]
    for i in range(2):
        if not data.players[i] is Dictionary: return false
        var b=CoopPlayerState.new()
        if not b.import_region1_state(data.players[i]) or int(b.seat)!=i: return false
        restored.append(b)
    if JSON.stringify(restored[0].enemies)!=JSON.stringify(restored[1].enemies): return false
    for key in data.poison_owner:
        if not str(key).is_valid_int() or int(key)<0 or int(key)>=restored[0].enemies.size() or int(data.poison_owner[key]) not in [0,1]: return false
    players=restored
    players[1].enemies=players[0].enemies
    for b in players: b.party=weakref(self)
    active=int(data.active); next_target=int(data.next_target); round_number=int(data.round)
    finished=bool(data.finished); victory=bool(data.victory); poison_owner=data.poison_owner.duplicate(true)
    enemy_rng.state=int(str(data.enemy_rng))
    return true

func dispose() -> void:
    for b in players: b.party=null
