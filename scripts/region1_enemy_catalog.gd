class_name Region1EnemyCatalog
extends RefCounted

# Approved Region 1 Stage I adapter. Card definitions remain in CardDatabase.
var entries: Dictionary = {}
static var cached_entries: Dictionary = {}
func _init() -> void:
    if not cached_entries.is_empty():
        entries=cached_entries
        return
    var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/region1_enemies.json"))
    if raw is Dictionary:
        for entry in raw.get("enemies", []):
            entries[str(entry.enemy_id)] = entry
    cached_entries=entries

func create(enemy_id: String, order_index: int, rng: RandomNumberGenerator) -> Dictionary:
    if not entries.has(enemy_id): return {}
    var d: Dictionary = entries[enemy_id].duplicate(true)
    var enemy: Dictionary = {"id":enemy_id,"name":enemy_id,"order_index":order_index,
        "hp":int(d.max_hp),"max_hp":int(d.max_hp),"block":0,"vulnerable":0,
        "is_boss":str(d.enemy_rank)=="Boss","attribute_traits":{"爆発":0,"鈍化":0,"呪印":0,"猛毒":0},
        "r1_data":d,"r1_status":{"Strength":0,"Charge":0,"Thorns":0,"StatusResist":0,"BlockStrength":0,"Regen":0},
        "intent_index":0,"intents":[]}
    advance(enemy,rng,false)
    return enemy

func advance(enemy: Dictionary, rng: RandomNumberGenerator, increment: bool = true) -> void:
    if increment: enemy.intent_index = int(enemy.intent_index)+1
    var d: Dictionary = enemy.r1_data
    var pattern: Array = d.ai_pattern
    enemy["r1_action"] = str(pattern[int(enemy.intent_index)%pattern.size()])
    enemy["r1_roll"] = rng.randi_range(int(d.attack_min),int(d.attack_max))

func intent(enemy: Dictionary, player_status: Dictionary = {}) -> Dictionary:
    var d: Dictionary = enemy.r1_data
    var status: Dictionary = enemy.r1_status
    var mode: String = str(enemy.r1_action)
    var actions: Array = []
    var base: int = int(enemy.r1_roll)
    if mode == "defend": actions.append({"type":"block","amount":int(d.defend_amount)})
    elif mode == "charge": actions.append({"type":"status","status":"Charge","amount":1})
    elif mode in ["thorns","resist","regen"]:
        actions.append({"type":"status","status":{"thorns":"Thorns","resist":"StatusResist","regen":"Regen"}[mode],"amount":1 if mode=="resist" else 2})
    elif mode == "barrier":
        actions.append({"type":"block","amount":maxi(int(d.defend_amount),int(d.signature_block))})
        actions.append({"type":"status","status":"StatusResist","amount":1})
    elif mode == "buff":
        var buff: String = "Thorns" if str(d.signature_self_status)=="Thorns" else "Strength"
        actions.append({"type":"status","status":buff,"amount":int(d.buff_amount)})
    elif mode == "signature":
        var key: String = str(d.signature_action_key)
        base = int(d.signature_damage)
        if key == "charge_strike":
            base += int(status.Charge)*5
            actions.append({"type":"clear_status","status":"Charge"})
        elif key == "block_scaling": base += mini(12,int(enemy.block)/2)
        elif key == "status_scaling":
            base += int(player_status.get(str(d.signature_condition_status),0))*int(d.signature_bonus_damage)
            if bool(d.signature_consume_condition): actions.append({"type":"clear_player_status","status":str(d.signature_condition_status)})
        elif key == "ally_buff": actions.append({"type":"ally_buff","amount":4})
        elif key == "fortress":
            actions.append({"type":"block","amount":maxi(8,int(d.signature_block))})
            actions.append({"type":"status","status":"StatusResist","amount":1})
        elif key == "thorns_counter":
            var amount: int = maxi(2,int(d.signature_self_status_value))
            actions.append({"type":"status","status":"Thorns","amount":amount})
            base += mini(8,mini(5,int(status.Thorns)+amount)*2)
        elif key == "region_master": actions.append({"type":"status","status":"Strength","amount":1})
        if int(d.signature_block)>0 and key != "fortress": actions.append({"type":"block","amount":int(d.signature_block)})
        if int(d.signature_heal)>0: actions.append({"type":"heal","amount":int(d.signature_heal)})
        if str(d.signature_self_status)!="" and key!="thorns_counter":
            actions.append({"type":"status","status":str(d.signature_self_status),"amount":int(d.signature_self_status_value)})
        if base>0: actions.append({"type":"attack","damage":base,"hits":maxi(1,int(d.signature_hits))})
        if str(d.signature_player_status)!="": actions.append({"type":"player_status","status":str(d.signature_player_status),"amount":int(d.signature_player_status_value)})
    else: actions.append({"type":"attack","damage":base,"hits":2 if mode=="attackx2" else 1})
    if actions.is_empty(): actions.append({"type":"wait","label":"Wait"})
    return {"label":mode,"actions":actions}
