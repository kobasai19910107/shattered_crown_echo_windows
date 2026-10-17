class_name CampaignCombat
extends RefCounted

static func gain(b, status: String, amount: int) -> void:
    if amount<=0: return
    var caps: Dictionary={"Poison":8,"Burn":6,"Weak":3,"Vulnerable":3,"Shock":5,"Frost":3,"Marked":2}
    if not caps.has(status): return
    if status=="Frost" and int(b.campaign_status.get("Frozen",0))>0: return
    b.campaign_status[status]=mini(int(caps[status]),int(b.campaign_status.get(status,0))+amount)
    if not b.campaign_status.has("Expires"): b.campaign_status["Expires"]={}
    if status in ["Weak","Vulnerable","Marked"]: b.campaign_status.Expires[status]=b.turn_number+int(b.campaign_status[status])
    if status=="Shock": b.campaign_status.Expires[status]=b.turn_number+2
    if status=="Burn": b.campaign_status["BurnTicks"]=2
    if status=="Frost" and int(b.campaign_status.Frost)>=3:
        b.campaign_status.Frost=0
        b.campaign_status["Frozen"]=1
        b.campaign_status.Expires["Frozen"]=b.turn_number+1

static func player_turn_end(b) -> void:
    for status in b.campaign_status.get("Expires",{}).keys():
        if b.turn_number>=int(b.campaign_status.Expires[status]):
            b.campaign_status[status]=0
            b.campaign_status.Expires.erase(status)
        elif status in ["Weak","Vulnerable","Marked"]:
            b.campaign_status[status]=mini(int(b.campaign_status.get(status,0)),int(b.campaign_status.Expires[status])-b.turn_number)
    if int(b.campaign_status.get("Frost",0))>0: b.campaign_status.Frost=int(b.campaign_status.Frost)-1

static func enemy_turn_end(b) -> void:
    for status in ["Poison","Burn"]:
        var loss: int=mini(maxi(0,b.player_hp),int(b.campaign_status.get(status,0)))
        if loss>0:
            var hp_before: int=b.player_hp
            b.player_hp-=loss
            b._metric_add("damage_taken",loss)
            b._log("DIAG HP_CHANGE cause=%s before=%d after=%d actual_loss=%d block_absorbed=0" % [status,hp_before,b.player_hp,loss])
            b._log("Player %s: HP -%d"%[status,loss])
        if status=="Poison": b.campaign_status[status]=maxi(0,int(b.campaign_status.get(status,0))-1)
        elif int(b.campaign_status.get("BurnTicks",0))>0:
            b.campaign_status.BurnTicks=int(b.campaign_status.BurnTicks)-1
            if int(b.campaign_status.BurnTicks)==0: b.campaign_status.Burn=0
        if b.player_hp<=0:
            b._finalize_battle("DEFEAT",status.to_lower())
            return

static func action(b, enemy: Dictionary, a: Dictionary) -> bool:
    match str(a.get("type","")):
        "player_status":
            if str(a.status)=="Bleed": return true # Legacy intent: no status and no damage.
            gain(b,str(a.status),int(a.amount))
            b._log("DIAG PLAYER_STATUS_APPLIED status=%s amount=%d total=%d" % [str(a.status),int(a.amount),int(b.campaign_status.get(str(a.status),0))])
        "remove_player_block": b.player_block=maxi(0,b.player_block-int(a.amount))
        "mana_tax": b.campaign_status["ManaTax"]=mini(2,int(b.campaign_status.get("ManaTax",0))+int(a.amount))
        "cleanse":
            enemy.vulnerable=0
            for key in enemy.attribute_traits: enemy.attribute_traits[key]=0
        "heal_ally":
            var target: Dictionary={}
            var ratio: float=2.0
            for ally in b.enemies:
                if int(ally.hp)<=0: continue
                var next_ratio: float=float(ally.hp)/maxi(1,int(ally.max_hp))
                if next_ratio<ratio: ratio=next_ratio; target=ally
            if not target.is_empty(): target.hp=mini(int(target.max_hp),int(target.hp)+int(a.amount))
        "retire": enemy.hp=0
        "summon":
            var alive: int=0
            for ally in b.enemies:
                if int(ally.hp)>0: alive+=1
            var limit: int=int(enemy.r1_data.summon_limit)
            if limit<=0: limit=4
            if alive>=limit:
                for ally in b.enemies:
                    if int(ally.hp)>0:
                        ally.block=int(ally.block)+4
                        ally.r1_status.Strength=mini(6,int(ally.r1_status.Strength)+1)
            else:
                var summon_id: String=str(enemy.r1_data.summon_enemy_path).get_file().get_basename().replace("_","-")
                var catalog=RegionEnemyCatalog.new()
                if catalog.entries.has(summon_id):
                    var summoned: Dictionary=catalog.create(summon_id,b.enemies.size()+1,b.battle_rng)
                    summoned["summoned_turn"]=b.turn_number
                    b.enemies.append(summoned)
                    b._log("Summon %s — first action next enemy phase"%summon_id)
        _: return false
    return true

static func phase_if_needed(b, enemy: Dictionary) -> bool:
    if RegionEnemyCatalog.advance_phase(enemy,b.battle_rng):
        b._log("%s Phase %d/%d — HP %d"%[str(enemy.id),int(enemy.phase_index)+1,enemy.phase_hp.size(),int(enemy.hp)])
        return true
    return false
