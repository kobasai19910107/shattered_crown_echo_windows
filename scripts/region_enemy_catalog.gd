class_name RegionEnemyCatalog
extends Region1EnemyCatalog

static var all_entries: Dictionary = {}
const PHASES = {"R3-B03":[182,64],"R6-B03":[48,47,47,47,47],"R6-B04":[42,42,41,41,41,41]}

func _init() -> void:
    super()
    if all_entries.is_empty():
        all_entries=entries.duplicate(true)
        for region in range(2,7):
            var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/region%d_enemies.json"%region))
            if raw is Dictionary:
                for entry in raw.get("enemies",[]): all_entries[str(entry.enemy_id)]=entry
    entries=all_entries

func create(enemy_id: String, order_index: int, rng: RandomNumberGenerator) -> Dictionary:
    var enemy: Dictionary=super.create(enemy_id,order_index,rng)
    if PHASES.has(enemy_id):
        enemy["phase_hp"]=PHASES[enemy_id].duplicate()
        enemy["phase_index"]=0
        enemy.hp=int(enemy.phase_hp[0])
        enemy.max_hp=int(enemy.phase_hp[0])
    return enemy

static func advance_phase(enemy: Dictionary, rng: RandomNumberGenerator) -> bool:
    if not enemy.has("phase_hp") or int(enemy.hp)>0: return false
    var index: int=int(enemy.phase_index)+1
    if index>=enemy.phase_hp.size(): return false
    enemy.phase_index=index
    enemy.hp=int(enemy.phase_hp[index])
    enemy.max_hp=int(enemy.phase_hp[index])
    enemy.block=0
    enemy.intent_index=0
    if str(enemy.id)=="R3-B03": enemy.r1_status.Strength=mini(6,int(enemy.r1_status.Strength)+2)
    RegionEnemyCatalog.new().advance(enemy,rng,false)
    return true

func intent(enemy: Dictionary, player_status: Dictionary = {}) -> Dictionary:
    if str(enemy.id).begins_with("R1-"): return super.intent(enemy,player_status)
    var d: Dictionary=enemy.r1_data
    var mode: String=str(enemy.r1_action)
    var actions: Array=[]
    if mode.begins_with("attackx"):
        actions.append({"type":"attack","damage":int(enemy.r1_roll),"hits":maxi(1,int(mode.trim_prefix("attackx")))})
    elif mode=="attack": actions.append({"type":"attack","damage":int(enemy.r1_roll),"hits":1})
    elif mode in ["poison","weak","vulnerable","shock","burn","frost","marked"]:
        actions.append({"type":"player_status","status":mode.capitalize(),"amount":1 if mode in ["frost","marked"] else 2})
    elif mode=="summon": actions.append({"type":"summon"})
    elif mode=="cleanse": actions.append({"type":"cleanse"})
    elif mode=="heal": actions.append({"type":"heal","amount":maxi(4,int(d.signature_heal))})
    elif mode=="signature": actions=_signature(enemy,player_status)
    else: return super.intent(enemy,player_status)
    return {"label":mode,"actions":actions}

func _signature(enemy: Dictionary, player: Dictionary) -> Array:
    var d: Dictionary=enemy.r1_data
    var actions: Array=[]
    var damage: int=int(d.signature_damage)
    var hits: int=maxi(1,int(d.signature_hits))
    var heal_handled: bool=false
    var block_handled: bool=false
    var condition: int=int(player.get(str(d.signature_condition_status),0))
    var key: String=str(d.signature_action_key)
    match key:
        "charge_strike":
            damage+=int(enemy.r1_status.Charge)*5
            actions.append({"type":"clear_status","status":"Charge"})
        "block_scaling": damage+=mini(12,int(enemy.block)/2)
        "status_scaling": damage+=condition*int(d.signature_bonus_damage)
        "status_heal":
            heal_handled=true
            if condition>0:
                damage+=int(d.signature_bonus_damage)
                actions.append({"type":"heal","amount":int(d.signature_heal)})
        "corrode": actions.append({"type":"remove_player_block","amount":6})
        "plague":
            if int(player.get("Poison",0))>=4: actions.append(_player("Weak",1))
        "dual_curse": actions.append(_player("Vulnerable",1))
        "summon": actions.append({"type":"summon"})
        "self_destruct": damage=maxi(damage,18)
        "ally_buff": actions.append({"type":"ally_buff"})
        "heal_ally":
            heal_handled=true
            actions.append({"type":"heal_ally","amount":int(d.signature_heal)})
        "heal_cleanse", "cleanse": actions.append({"type":"cleanse"})
        "escalating_hits": hits=clampi(2+int(enemy.intent_index)/2,2,5)
        "mana_tax": actions.append({"type":"mana_tax","amount":1})
        "copy_type":
            match str(player.get("LastType","")):
                "attack": damage+=5
                "skill": actions.append({"type":"block","amount":8})
                "power": actions.append({"type":"status","status":"Strength","amount":2})
                _: damage+=2
        "frost_shock_combo":
            if int(player.get("Shock",0))>0: actions.append(_player("Frost",1))
            if int(player.get("Frost",0))+int(player.get("Frozen",0))>0: actions.append(_player("Shock",1))
        "burn_mark_combo":
            if int(player.get("Burn",0))>0:
                actions.append(_player("Marked",1))
                if int(player.get("Marked",0))>0: damage+=6
        "polarity":
            if int(enemy.intent_index)%2==0:
                actions.append({"type":"block","amount":8})
                actions.append({"type":"heal","amount":4})
            else: actions.append(_player("Weak",1)); actions.append(_player("Vulnerable",1))
        "stance_shift":
            if int(enemy.intent_index)%2==0:
                actions.append({"type":"block","amount":8})
                actions.append({"type":"status","status":"Thorns","amount":2})
            else: hits=maxi(hits,3)
        "dual_status": actions.append(_player("Poison" if int(player.get("Shock",0))>0 else "Shock",1))
        "phase_shift":
            var status: String
            if str(enemy.id)=="R6-B03": status=["Burn","Poison","Vulnerable","Burn","Vulnerable"][int(enemy.get("phase_index",0))]
            else: status="Burn" if float(enemy.hp)/maxi(1,int(enemy.max_hp))>0.66 else ("Poison" if float(enemy.hp)/maxi(1,int(enemy.max_hp))>0.33 else "Vulnerable")
            actions.append(_player(status,1))
        "attribute_shift": actions.append(_player(["Burn","Frost","Shock","Poison","Weak"][int(enemy.intent_index)%5],1))
        "adaptive":
            actions.append({"type":"status","status":"StatusResist","amount":1})
            actions.append({"type":"block","amount":6})
        "fortress":
            block_handled=true
            actions.append({"type":"block","amount":maxi(8,int(d.signature_block))})
            actions.append({"type":"status","status":"StatusResist","amount":1})
        "region_master": actions.append({"type":"status","status":"Strength","amount":1})
        "rebirth": actions.append({"type":"status","status":"Regen","amount":2})
        "final_cycle":
            match int(enemy.get("phase_index",0)):
                0: actions.append({"type":"block","amount":10})
                1: actions.append(_player("Poison",2))
                2: actions.append(_player("Burn",2))
                3: actions.append(_player("Shock",2))
                4: actions.append({"type":"heal","amount":6})
                5: actions.append(_player("Vulnerable",1))
    if int(d.signature_block)>0 and not block_handled: actions.append({"type":"block","amount":int(d.signature_block)})
    if int(d.signature_heal)>0 and not heal_handled: actions.append({"type":"heal","amount":int(d.signature_heal)})
    if str(d.signature_self_status)!="": actions.append({"type":"status","status":str(d.signature_self_status),"amount":int(d.signature_self_status_value)})
    if damage>0: actions.append({"type":"attack","damage":damage,"hits":hits})
    if str(d.signature_player_status)!="": actions.append(_player(str(d.signature_player_status),int(d.signature_player_status_value)))
    if bool(d.signature_consume_condition) and str(d.signature_condition_status)!="": actions.append({"type":"clear_player_status","status":str(d.signature_condition_status)})
    if key=="self_destruct": actions.append({"type":"retire"})
    return actions

func _player(status: String, amount: int) -> Dictionary:
    return {"type":"player_status","status":status,"amount":amount}
