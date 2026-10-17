class_name Region1RunController
extends RefCounted

const SLOTS = ["main_weapon","offhand","head","body","hands","feet"]
const RARITIES = ["Common","Rare","Epic","Legendary"]
const SAVE_PATH = "user://region1_run_v1.json"
const WEIGHTS = {"battle":[55,32,12,1],"elite":[25,40,30,5],"boss":[0,25,55,20],"chest":[40,38,19,3],"shop":[35,40,25,0],"event":[45,35,17,3]}
var roller = Step8EquipmentRoller.new()
var state: Dictionary = {}
var battle: BattleController
var save_path: String = SAVE_PATH
var notice: String = ""
var save_blocked: bool = false

func _init() -> void:
    roller.load_data()
    state = {"schema_version":1,"phase":"hub","base_gold":1000,"materials":0,"bosses":0,
        "region2_unlocked":false,"inventory":{},"loadout":{},"run":{},"sequence":0,"forge_pending":{},"initial_claimed":false,"recent_drop_pairs":[],"hub_stock":[],"hub_shop_revision":0}

func load_saved() -> bool:
    var saved: Dictionary = Region1Save.read(save_path)
    normalize_legacy_common_sockets(saved)
    # Old saved merchant inventory may contain Legendary. Reroll the unowned shop
    # display only, preserving player-owned gear and campaign progression.
    if saved.has("inventory") and saved.get("hub_stock", []) is Array:
        for stock_item in saved.get("hub_stock", []):
            if stock_item is Dictionary and str(stock_item.get("rarity", "")) == "Legendary":
                _roll_hub_stock(saved)
                break
    # Legacy shop checkpoints may omit stock. Never access an optional key by dot.
    var legacy_run_data: Variant = saved.get("run", null)
    if legacy_run_data is Dictionary and str(legacy_run_data.get("kind", "")) == "shop":
        var legacy_stock: Variant = legacy_run_data.get("stock", null)
        if legacy_stock is Array:
            for i in range(legacy_stock.size()):
                if legacy_stock[i] is Dictionary and str(legacy_stock[i].get("rarity", "")) == "Legendary":
                    legacy_stock[i] = {} # Old unpurchased item; do not materialize it.
    if not valid_state(saved):
        if FileAccess.file_exists(save_path): notice="保存データが不正です。上書きせず、現在の状態を保持します。"
        save_blocked=FileAccess.file_exists(save_path)
        return false
    var restored: BattleController
    if str(saved.phase)=="battle":
        restored=BattleController.new()
        if not restored.import_region1_state(saved.run.get("battle",{})): return false
    state=saved
    if not state.has("initial_claimed"): state.initial_claimed=not state.inventory.is_empty()
    if not state.has("recent_drop_pairs"): state.recent_drop_pairs=[]
    if not state.has("hub_stock"): state.hub_stock=[]
    if not state.has("hub_shop_revision"): state.hub_shop_revision=0
    battle=restored
    return true

# Compatibility migration for Common items saved with the former 0-1 sockets.
# Does not modify Rare+ items or card/effect data and never auto-writes disk.
static func normalize_legacy_common_sockets(candidate: Dictionary) -> void:
    if candidate.is_empty(): return
    var collections: Array=[]
    if candidate.has("inventory") and candidate.inventory is Dictionary:
        collections.append(candidate.inventory.values())
    if candidate.has("hub_stock") and candidate.hub_stock is Array:
        collections.append(candidate.hub_stock)
    if candidate.has("run") and candidate.run is Dictionary:
        var saved_run: Dictionary=candidate.run
        # A legacy hub/checkpoint can have a run dictionary without an "items" key.
        # Checking get(..., {}) would pass for that missing key, then .items would crash.
        var legacy_items: Variant = saved_run.get("items", null)
        if legacy_items is Dictionary:
            collections.append(legacy_items.values())
        # Optional arrays may be absent in older save checkpoints.
        # Never index saved_run[field] just because get(field, []) is an Array:
        # the default [] is an Array even when the key does not exist.
        for field in ["bag", "stock", "rewards"]:
            var legacy_collection: Variant = saved_run.get(field, null)
            if legacy_collection is Array:
                collections.append(legacy_collection)
    for collection in collections:
        for item in collection:
            if item is Dictionary and str(item.get("rarity", "")) == "Common" and not item.is_empty():
                item["socket_count"] = 0
                item["socket_cap"] = 0
                # No Gems were implemented for Common items in this version.

func valid_state(candidate: Dictionary) -> bool:
    for key in ["phase","base_gold","materials","bosses","region2_unlocked","inventory","loadout","run","sequence","forge_pending"]:
        if not candidate.has(key): return false
    if int(candidate.get("schema_version",0))!=1: return false
    if str(candidate.get("phase","")) not in ["hub","route","battle","reward","service","defeat"]: return false
    if int(candidate.get("base_gold",-1))<0 or int(candidate.get("materials",-1))<0: return false
    if int(candidate.get("bosses",-1))<0 or int(candidate.bosses)>4: return false
    if not candidate.get("inventory") is Dictionary or not candidate.get("loadout") is Dictionary: return false
    if not candidate.run is Dictionary or not candidate.forge_pending is Dictionary: return false
    if not candidate.region2_unlocked is bool or bool(candidate.region2_unlocked)!=(int(candidate.bosses)==4): return false
    if int(candidate.sequence)<0: return false
    # Hub merchant fields are optional for old campaign saves.
    if int(candidate.get("hub_shop_revision",0))<0:return false
    var hub_stock = candidate.get("hub_stock",[])
    if not hub_stock is Array or hub_stock.size()>3:return false
    for shop_item in hub_stock:
        if not shop_item is Dictionary:return false
        if shop_item.is_empty():continue # Sold slot, kept until a paid refresh.
        if not roller.validate_item(shop_item) or not EquipmentSpecialEffectPolicy.validate_effects(shop_item,false):return false
        if not roller.templates.has(str(shop_item.get("equipment_id",""))):return false
        var shop_template: Dictionary=roller.templates[str(shop_item.equipment_id)]
        if int(shop_item.get("socket_count",-1))<int(shop_template.InitialSocketMin) or int(shop_item.get("socket_count",-1))>int(shop_template.SocketCap):return false
        if int(shop_item.get("enhance_level",-1))!=0:return false
        if int(shop_item.get("effective_hp",shop_item.get("base_hp",-1)))!=int(shop_item.get("base_hp",-1)):return false
        if shop_item.get("reroll_counts",[])!=[0,0]:return false
        if int(shop_item.get("special_reroll_count",0))!=0:return false
        if candidate.inventory.has(str(shop_item.get("instance_id",""))):return false
    # Optional field: pre-v1.9.1 save files contain no acquired-pair history.
    if not DropDuplicatePolicy.valid_history(candidate.get("recent_drop_pairs", []), SLOTS, roller.cards): return false
    for uid in candidate.inventory:
        var item = candidate.inventory[uid]
        if not item is Dictionary or str(item.get("instance_id",""))!=str(uid) or not roller.validate_item(item): return false
        if not EquipmentSpecialEffectPolicy.validate_effects(item, false): return false
        if not roller.templates.has(str(item.get("equipment_id",""))): return false
        var template: Dictionary=roller.templates[str(item.equipment_id)]
        var level: int=int(item.get("enhance_level",0))
        var sockets: int=int(item.get("socket_count",int(template.InitialSocketMin)))
        if level<0 or level>int(template.EnhanceCap) or sockets<int(template.InitialSocketMin) or sockets>int(template.SocketCap): return false
        if int(item.get("effective_hp",item.base_hp))!=int(item.base_hp)+level*int(template.HP_Per_Enhance): return false
        if not item.get("reroll_counts") is Array or item.reroll_counts.size()!=2: return false
        for count in item.reroll_counts:
            if int(count)<0 or int(count)>3: return false
        if int(item.get("special_reroll_count",0))<0 or int(item.get("special_reroll_count",0))>3:return false
    for slot in candidate.loadout:
        if not SLOTS.has(str(slot)) or not candidate.inventory.has(str(candidate.loadout[slot])): return false
        if str(candidate.inventory[str(candidate.loadout[slot])].slot)!=str(slot): return false
    if not candidate.forge_pending.is_empty():
        var pending: Dictionary=candidate.forge_pending
        if str(candidate.phase)!="hub" or not candidate.inventory.has(str(pending.get("uid",""))): return false
        if not pending.get("choices") is Array or pending.choices.size()!=2:return false
        if pending.choices[0]==pending.choices[1]: return false
        var pending_item: Dictionary=candidate.inventory[str(pending.uid)]
        if str(pending.get("kind", "card"))=="special_effect":
            var ei: int=int(pending.get("effect_index",-1))
            var effects: Array=pending_item.get("special_effects",[])
            if ei<0 or ei>=effects.size() or int(pending_item.get("special_reroll_count",0))<1:return false
            var pool: Array[String]=EquipmentSpecialEffectPolicy.eligible_ids(pending_item)
            for effect_id in pending.choices:
                if not pool.has(str(effect_id)):return false
                for j in range(effects.size()):
                    if j!=ei and str(effects[j].get("effect_id", ""))==str(effect_id):return false
                if str(effects[ei].get("effect_id",""))==str(effect_id):return false
        elif str(pending.get("kind", "card"))=="card":
            if int(pending.get("slot",-1)) not in [0,1]:return false
            for cid in pending.choices:
                if not roller.cards.has(str(cid)): return false
        else:return false
    if str(candidate.phase)!="hub":
        var run = candidate.get("run")
        if not run is Dictionary or run.get("items",{}).size()!=6 or run.get("deck",[]).size()!=24: return false
        if int(run.get("gold",-1))<0 or int(run.get("hp",-1))<0 or int(run.get("max_hp",0))<1: return false
        if int(run.hp)>int(run.max_hp) or int(run.get("body_cap",0)) not in [2,3,4]: return false
        for key in ["bag","routes","stock","rewards","deck"]:
            if not run.get(key) is Array: return false
        if not run.get("support") is Dictionary or not run.get("battle") is Dictionary: return false
        for key in run.support:
            if str(key) not in ["attack","block","draw"] or int(run.support[key])!=1: return false
        # A shop event contains exactly one NPC. Missing field is an old save:
        # restore as merchant so existing shop stock stays purchasable.
        if run.has("shop_npc") and str(run.shop_npc) not in ["merchant","priest"]: return false
        for route in run.routes:
            if str(route) not in ["battle","elite","boss","shop","chest","rest","event"]: return false
        for key in ["bag","stock","rewards"]:
            for item in run[key]:
                if not item is Dictionary: return false
                if key=="stock" and item.is_empty(): continue
                if not roller.validate_item(item) or not EquipmentSpecialEffectPolicy.validate_effects(item, false): return false
        if run.has("target_boss_number"):
            var boss_number: int = int(run.get("target_boss_number",0))
            if boss_number < 1 or boss_number > 4: return false
            if not run.get("replay_boss",false) is bool: return false
            if boss_number > _boss_count(candidate)+1: return false
            if bool(run.replay_boss) and boss_number > _boss_count(candidate): return false
        if not str(run.get("rng_state","")).is_valid_int(): return false
        for item in run.items.values():
            if not roller.validate_item(item) or not EquipmentSpecialEffectPolicy.validate_effects(item, false): return false
        if roller.inspect_deck(run.items).deck!=run.deck: return false
        if str(candidate.phase)=="battle":
            var validator=BattleController.new()
            if not validator.import_region1_state(run.battle): return false
    return true

func items_from_state(candidate: Dictionary = {}) -> Dictionary:
    var source: Dictionary = state if candidate.is_empty() else candidate
    var items: Dictionary = {}
    for slot in SLOTS:
        var uid: String = str(source.loadout.get(slot,""))
        if source.inventory.has(uid): items[slot]=source.inventory[uid].duplicate(true)
    return items

func adopt_initial(items: Dictionary) -> bool:
    if str(state.phase)!="hub" or items.size()!=6 or bool(state.get("initial_claimed",false)): return false
    var next: Dictionary = state.duplicate(true)
    for slot in SLOTS:
        if not items.has(slot) or not roller.validate_item(items[slot]): return false
        var item: Dictionary = items[slot].duplicate(true)
        var uid: String = str(item.instance_id)
        if next.inventory.has(uid) and next.inventory[uid]!=item: return false
        next.inventory[uid]=item
        next.loadout[slot]=uid
    next.initial_claimed=true
    return _commit(next)

func _commit(next: Dictionary, next_battle: BattleController = null) -> bool:
    if save_blocked: return false
    if not valid_state(next):
        notice="操作後のデータ検証に失敗しました。直前状態を保持します。"
        return false
    if not Region1Save.write(save_path,next):
        notice="保存に失敗しました。直前状態を保持します。"
        return false
    state=next
    if next_battle!=null: battle=next_battle
    elif str(state.phase)!="battle": battle=null
    notice=""
    return true

func _rng(run: Dictionary) -> RandomNumberGenerator:
    var rng = RandomNumberGenerator.new()
    rng.seed=int(run.seed)
    rng.state=int(str(run.rng_state))
    return rng

func _store_rng(run: Dictionary, rng: RandomNumberGenerator) -> void:
    run.rng_state=str(rng.state)

# requested_boss=0 retains the historical 'next uncleared boss' behavior.
# Explicit cleared stages are replayable without rewinding campaign progress.
func begin(seed_value: int, requested_boss: int = 0) -> bool:
    var cleared: int = _boss_count(state)
    if requested_boss == 0 and cleared >= 4: return false
    if requested_boss < 0 or requested_boss > 4 or (requested_boss > 0 and requested_boss > cleared + 1): return false
    if str(state.phase)!="hub" or not state.forge_pending.is_empty(): return false
    var items: Dictionary = items_from_state()
    if items.size()!=6: notice="初期6装備を選択してください。"; return false
    var next: Dictionary = state.duplicate(true)
    var rng = RandomNumberGenerator.new()
    rng.seed=seed_value
    var hp: int = 0
    for item in items.values(): hp+=int(item.get("effective_hp",item.base_hp))
    next.run={"region_id":_region_id(next),"seed":seed_value,"rng_state":str(rng.state),"items":items,"deck":roller.inspect_deck(items).deck,
        "target_boss_number":(requested_boss if requested_boss > 0 else cleared + 1),
        "replay_boss":requested_boss > 0 and requested_boss <= cleared,
        "hp":hp,"max_hp":hp,"gold":100,"materials":0,"bag":[],"rooms":0,"support":{},
        "body_cap":{"Common":2,"Rare":2,"Epic":3,"Legendary":4}.get(str(items.body.rarity),2),
        "routes":[],"kind":"","rewards":[],"stock":[],"battle":{}}
    next.phase="route"
    _routes(next.run)
    return _commit(next)

func _routes(run: Dictionary) -> void:
    var rng = _rng(run)
    var rooms: int = int(run.rooms)
    var chance: int = 0 if rooms<4 else ([10,25,45,70][rooms-4] if rooms<8 else 100)
    if chance>0 and rng.randi_range(1,100)<=chance: run.routes=["boss"]
    else:
        run.routes=["battle"]
        for i in range(2):
            run.routes.append(_weighted(["battle","event","elite","shop","chest","rest"],[34.0,14.0,12.0+mini(rooms,8),10.0,10.0,12.0],rng))
    _store_rng(run,rng)

func _weighted(values: Array, weights: Array, rng: RandomNumberGenerator):
    var total: float = 0.0
    for weight in weights: total+=float(weight)
    var pick: float = rng.randf()*total
    for i in range(values.size()):
        pick-=float(weights[i])
        if pick<=0: return values[i]
    return values.back()

func _drop(next: Dictionary, kind: String, rng: RandomNumberGenerator) -> Dictionary:
    var adjusted: Array = []
    for i in range(4): adjusted.append(float(WEIGHTS[kind][i])*[1.2,1.0,0.75,0.5][i])
    # Shops explicitly exclude the Legendary category (not just weight 0).
    var rarity: String = str(_weighted(RARITIES.slice(0,3),adjusted.slice(0,3),rng)) if kind=="shop" else str(_weighted(RARITIES,adjusted,rng))
    var options: Array = []
    for tid in roller.templates.keys():
        if str(roller.templates[tid].Rarity)==rarity: options.append(str(tid))
    options.sort()
    var tid: String = str(options[rng.randi_range(0,options.size()-1)])
    var item: Dictionary = roller.generate_item(tid,rng.randi())
    next.sequence=int(next.sequence)+1
    item.instance_id="%s_%d_%d" % [_region_id(next),int(next.run.seed),int(next.sequence)]
    var t: Dictionary = roller.templates[tid]
    item["socket_count"]=rng.randi_range(int(t.InitialSocketMin),int(t.InitialSocketMax))
    item["enhance_level"]=0
    # Draw-only affix roll, independent from run RNG and initial-deck generation.
    item["special_effects"] = EquipmentSpecialEffectPolicy.roll_on_drop(item)
    return item

func _offer(next: Dictionary, kind: String, rng: RandomNumberGenerator) -> Array:
    # Filtering is drop-only. InitialDeckGenerator and Step8EquipmentRoller are untouched.
    # The first three rolls use the original run RNG. Retries and the history coin
    # use a deterministic, isolated stream so combat/route RNG is not advanced.
    var choices: Array = []
    var offered_keys: Dictionary = {}
    var history: Array = next.get("recent_drop_pairs", [])
    for i in range(3):
        var candidate: Dictionary = _drop(next, kind, rng)
        var retry_rng: RandomNumberGenerator = RandomNumberGenerator.new()
        retry_rng.seed = hash("drop-filter|%s|%s|%d|%d" % [str(next.run.seed),kind,int(next.sequence),i])
        for attempt in range(DropDuplicatePolicy.MAX_RETRIES):
            var key: String = DropDuplicatePolicy.pair_key(candidate)
            var in_offer: bool = offered_keys.has(key)
            var in_history: bool = history.has(key)
            # 70% chance is evaluated ONLY if a valid candidate repeats history.
            if not in_offer and (not in_history or retry_rng.randf() >= DropDuplicatePolicy.HISTORY_RETRY_RATE):
                break
            candidate = _drop(next, kind, retry_rng)
        # If the 10-retry cap is reached, keep the last legal generated candidate.
        choices.append(candidate)
        offered_keys[DropDuplicatePolicy.pair_key(candidate)] = true
    return choices

func choose_route(index: int, forced_shop_npc: String = "") -> bool:
    if str(state.phase)!="route" or index<0 or index>=state.run.routes.size(): return false
    var next: Dictionary=state.duplicate(true)
    var run: Dictionary=next.run
    var kind: String=str(run.routes[index])
    if forced_shop_npc!="" and (kind!="shop" or forced_shop_npc not in ["merchant","priest"]): return false
    var rng=_rng(run)
    run.kind=kind
    run.erase("shop_npc")
    run.routes=[]
    if kind in ["battle","elite","boss"]:
        var ids: Array=[]
        var region: String=_region_id(next)
        if kind=="boss": ids=["%s-B%02d" % [region,int(run.get("target_boss_number",_boss_count(next)+1))]]
        elif kind=="elite": ids=["%s-E%02d" % [region,rng.randi_range(1,3)]]
        else:
            var a: int=rng.randi_range(1,7)
            var b: int=rng.randi_range(1,6)
            if b>=a: b+=1
            ids=["%s-N%02d"%[region,a],"%s-N%02d"%[region,b]]
        var combat=BattleController.new()
        if not combat.start_region1(rng.randi(),run.deck,ids,run.items,int(run.hp),run.support): return false
        run.support={}
        run.battle=combat.export_region1_state()
        run["battle_start"]=run.battle.duplicate(true)
        next.phase="battle"
        _store_rng(run,rng)
        return _commit(next,combat)
    next.phase="service"
    if kind=="shop":
        # The random decision is made once on entry and saved with this run.
        # A coop guest still consumes the same one draw, but uses the host's
        # selection to ensure that both players visit the same type of NPC.
        var rolled_npc: String = "merchant" if rng.randi_range(0,1)==0 else "priest"
        run["shop_npc"] = forced_shop_npc if forced_shop_npc!="" else rolled_npc
        run.stock = _offer(next,"shop",rng) if str(run.shop_npc)=="merchant" else []
    elif kind=="chest":
        run.rewards=_offer(next,"chest",rng)
        run.materials=int(run.materials)+1
        next.phase="reward"
    _store_rng(run,rng)
    return _commit(next)

func checkpoint() -> bool:
    if str(state.phase)!="battle" or battle==null: return false
    var next: Dictionary=state.duplicate(true)
    next.run.hp=maxi(0,battle.player_hp)
    next.run.battle=battle.export_region1_state()
    if battle.combat_over:
        if battle.victory:
            var kind: String=str(next.run.kind)
            next.run.gold=int(next.run.gold)+int({"battle":120,"elite":220,"boss":500}[kind])
            next.run.materials=int(next.run.materials)+int({"battle":1,"elite":2,"boss":3}[kind])
            var rng=_rng(next.run)
            next.run.rewards=_offer(next,kind,rng)
            _store_rng(next.run,rng)
            next.phase="reward"
        else: next.phase="defeat"
    if _commit(next,battle if str(next.phase)=="battle" else null): return true
    # Roll back both the model and the actual battle if the checkpoint failed.
    var restored=BattleController.new()
    if restored.import_region1_state(state.run.battle): battle=restored
    return false

func take_reward(index: int) -> bool:
    if str(state.phase)!="reward" or index< -1 or index>=state.run.rewards.size(): return false
    var next: Dictionary=state.duplicate(true)
    if index>=0:
        var acquired: Dictionary = next.run.rewards[index].duplicate(true)
        next.run.bag.append(acquired)
        DropDuplicatePolicy.record_acquired(next, acquired)
    next.run.rewards=[]
    if str(next.run.kind)=="boss":
        _record_boss_win(next)
        _return(next,next.run.bag,true)
    else: _finish_room(next)
    return _commit(next)

func _region_id(_candidate: Dictionary) -> String:
    return "R1"

func _boss_count(candidate: Dictionary) -> int:
    return int(candidate.bosses)

func _record_boss_win(next: Dictionary) -> void:
    if bool(next.run.get("replay_boss",false)): return
    next.bosses=mini(4,int(next.bosses)+1)
    next.region2_unlocked=int(next.bosses)==4

func _finish_room(next: Dictionary) -> void:
    next.run.rooms=int(next.run.rooms)+1
    next.run.erase("shop_npc")
    next.run.stock=[]
    next.phase="route"
    _routes(next.run)

func _return(next: Dictionary, retained: Array, success: bool) -> void:
    for item in retained: next.inventory[str(item.instance_id)]=item.duplicate(true)
    if success:
        next.base_gold=int(next.base_gold)+int(next.run.gold)
        next.materials=int(next.materials)+int(next.run.materials)
    next.run={}
    next.phase="hub"

func resolve_defeat(indices: Array) -> bool:
    if str(state.phase)!="defeat" or indices.size()>int(state.run.body_cap): return false
    var next: Dictionary=state.duplicate(true)
    var retained: Array=[]
    var seen: Array=[]
    for index in indices:
        if int(index)<0 or int(index)>=next.run.bag.size() or seen.has(int(index)): return false
        seen.append(int(index))
        retained.append(next.run.bag[int(index)])
    _return(next,retained,false)
    return _commit(next)

func service(action: String, index: int = -1) -> bool:
    if str(state.phase)!="service": return false
    var next: Dictionary=state.duplicate(true)
    var run: Dictionary=next.run
    var kind: String=str(run.kind)
    if action=="leave": _finish_room(next)
    elif kind=="rest" and action=="heal":
        run.hp=mini(int(run.max_hp),int(run.hp)+maxi(1,int(float(run.max_hp)*0.35)))
        _finish_room(next)
    elif kind=="event":
        if action=="gold": run.gold=int(run.gold)+80
        elif action=="material": run.materials=int(run.materials)+2
        elif action=="heal": run.hp=mini(int(run.max_hp),int(run.hp)+maxi(1,int(float(run.max_hp)*0.20)))
        else: return false
        _finish_room(next)
    elif kind=="shop":
        # A saved event is either merchant OR priest: never allow purchases
        # from the absent NPC, even if a UI or network caller sends a command.
        var shop_npc: String=str(run.get("shop_npc","merchant"))
        if shop_npc=="merchant" and action not in ["buy","refresh"]: return false
        if shop_npc=="priest" and action not in ["heal","full_heal","attack","block","draw"]: return false
        if shop_npc not in ["merchant","priest"]: return false
        var cost: int=0
        if action=="buy":
            if index<0 or index>=run.stock.size() or run.stock[index].is_empty(): return false
            if str(run.stock[index].get("rarity", "")) == "Legendary": return false
            cost=280
            var purchased: Dictionary = run.stock[index].duplicate(true)
            run.bag.append(purchased)
            DropDuplicatePolicy.record_acquired(next, purchased)
            run.stock[index]={}
        elif action=="refresh":
            cost=70
            var rng=_rng(run)
            run.stock=_offer(next,"shop",rng)
            _store_rng(run,rng)
        elif action in ["heal","full_heal"]:
            if int(run.hp)>=int(run.max_hp): return false
            cost=90 if action=="heal" else 220
            run.hp=mini(int(run.max_hp),int(run.hp)+maxi(1,int(float(run.max_hp)*0.35))) if action=="heal" else int(run.max_hp)
        elif action in ["attack","block","draw"]:
            if int(run.support.get(action,0))>0: return false
            cost=60
            run.support[action]=1
        else: return false
        if int(run.gold)<cost: return false
        run.gold=int(run.gold)-cost
    else: return false
    return _commit(next)

# Permanent hub merchant, separate from the run-only merchant/priest encounter.
# Stock only changes on initial opening, purchase or explicitly paid refresh.
func hub_buy_price(item: Dictionary) -> int:
    return {"Common":130,"Rare":320,"Epic":680}.get(str(item.get("rarity","")),0)

func hub_sell_price(item: Dictionary) -> int:
    return {"Common":40,"Rare":110,"Epic":240,"Legendary":500}.get(str(item.get("rarity","")),0)

func _roll_hub_stock(next: Dictionary) -> void:
    var revision: int=int(next.get("hub_shop_revision",0))
    var region_index: int=clampi(int(next.get("active_region",0)),0,5)
    var rng=RandomNumberGenerator.new()
    rng.seed=hash("hub-vendor|%d|%d|%d"%[revision,region_index,int(next.sequence)])
    # Legendary is never part of merchant inventory in any Region.
    var weights: Array=[65.0,30.0,4.5,0.0] if region_index==0 else [maxf(15.0,65.0-region_index*9.0),30.0+region_index*2.0,4.5+region_index*6.0,0.0]
    var stock: Array=[]
    var existing_pairs: Dictionary={}
    var template_keys: Array=roller.templates.keys()
    template_keys.sort()
    for index in range(3):
        var rarity: String=str(_weighted(RARITIES.slice(0,3),weights.slice(0,3),rng))
        var eligible: Array=[]
        for tid in template_keys:
            if str(roller.templates[tid].Rarity)==rarity:eligible.append(str(tid))
        var item: Dictionary={}
        # Best effort to avoid duplicated card pairs inside this one shop refresh.
        for attempt in range(11):
            var tid: String=str(eligible[rng.randi_range(0,eligible.size()-1)])
            item=roller.generate_item(tid,rng.randi())
            var key: String=DropDuplicatePolicy.pair_key(item)
            if not existing_pairs.has(key) or attempt==10:
                existing_pairs[key]=true
                break
        next.sequence=int(next.sequence)+1
        item.instance_id="HUB_%d_%d"%[revision,int(next.sequence)]
        var template: Dictionary=roller.templates[str(item.equipment_id)]
        item["socket_count"]=rng.randi_range(int(template.InitialSocketMin),int(template.InitialSocketMax))
        item["enhance_level"]=0
        item["special_effects"]=EquipmentSpecialEffectPolicy.roll_on_drop(item)
        stock.append(item)
    next["hub_stock"]=stock

func ensure_hub_shop() -> bool:
    if str(state.phase)!="hub" or save_blocked or not state.forge_pending.is_empty():return false
    if state.get("hub_stock",[]).size()==3:return true
    var next: Dictionary=state.duplicate(true)
    _roll_hub_stock(next)
    return _commit(next)

func refresh_hub_shop() -> bool:
    if str(state.phase)!="hub" or save_blocked or not state.forge_pending.is_empty() or int(state.base_gold)<100:return false
    var next: Dictionary=state.duplicate(true)
    next.base_gold=int(next.base_gold)-100
    next["hub_shop_revision"]=int(next.get("hub_shop_revision",0))+1
    _roll_hub_stock(next)
    return _commit(next)

func buy_hub_item(index: int, expected_uid: String = "") -> bool:
    if str(state.phase)!="hub" or save_blocked or not state.forge_pending.is_empty():return false
    var stock: Array=state.get("hub_stock",[])
    if index<0 or index>=stock.size() or not stock[index] is Dictionary or stock[index].is_empty():return false
    var item: Dictionary=stock[index]
    var price: int=hub_buy_price(item)
    var uid: String=str(item.get("instance_id",""))
    if expected_uid!="" and uid!=expected_uid:return false
    if price<=0 or int(state.base_gold)<price or state.inventory.has(uid):return false
    var next: Dictionary=state.duplicate(true)
    next.base_gold=int(next.base_gold)-price
    next.inventory[uid]=item.duplicate(true)
    next.hub_stock[index]={}
    DropDuplicatePolicy.record_acquired(next,item)
    return _commit(next)

func sell_hub_item(uid: String) -> bool:
    if str(state.phase)!="hub" or save_blocked or not state.forge_pending.is_empty():return false
    if not state.inventory.has(uid) or state.loadout.values().has(uid):return false
    var item: Dictionary=state.inventory[uid]
    var price: int=hub_sell_price(item)
    if price<=0:return false
    var next: Dictionary=state.duplicate(true)
    next.inventory.erase(uid)
    next.base_gold=int(next.base_gold)+price
    # Do not erase acquired-pair history; a previously owned item remains history.
    return _commit(next)

func equip(uid: String) -> bool:
    if str(state.phase)!="hub" or not state.inventory.has(uid) or not state.forge_pending.is_empty(): return false
    var next: Dictionary=state.duplicate(true)
    next.loadout[str(next.inventory[uid].slot)]=uid
    return _commit(next)

# Apply all six recommended slots in ONE checked save. Never update mid-run.
func equip_loadout(uids: Dictionary) -> bool:
    if str(state.phase)!="hub" or save_blocked or not state.forge_pending.is_empty():return false
    if uids.size()!=SLOTS.size():return false
    var next: Dictionary=state.duplicate(true)
    var unique_uids: Dictionary={}
    var items: Dictionary={}
    for slot in SLOTS:
        var uid: String=str(uids.get(slot,""))
        if uid=="" or unique_uids.has(uid) or not next.inventory.has(uid):return false
        var item: Dictionary=next.inventory[uid]
        if str(item.get("slot",""))!=slot or not roller.validate_item(item):return false
        unique_uids[uid]=true
        items[slot]=item
        next.loadout[slot]=uid
    if roller.inspect_deck(items).deck.size()!=24:return false
    return _commit(next)

func forge(uid: String, action: String, slot: int = -1) -> bool:
    if str(state.phase)!="hub" or not state.inventory.has(uid) or not state.forge_pending.is_empty(): return false
    var next: Dictionary=state.duplicate(true)
    var item: Dictionary=next.inventory[uid]
    var template: Dictionary=roller.templates[str(item.equipment_id)]
    var cost: int=0
    var material_cost: int=1
    if action=="dismantle":
        if next.loadout.values().has(uid): return false
        next.materials=int(next.materials)+RARITIES.find(str(item.rarity))+1
        next.inventory.erase(uid)
        return _commit(next)
    elif action=="enhance":
        var level: int=int(item.get("enhance_level",0))
        if level>=int(template.EnhanceCap): return false
        cost=100*(level+1)
        item.enhance_level=level+1
        item["effective_hp"]=int(item.base_hp)+(level+1)*int(template.HP_Per_Enhance)
    elif action=="socket":
        var count: int=int(item.get("socket_count",int(template.InitialSocketMin)))
        if count>=int(template.SocketCap): return false
        cost=250+count*150
        item["socket_count"]=count+1
    elif action=="special_reroll":
        var existing: Array=item.get("special_effects",[])
        var used: int=int(item.get("special_reroll_count",0))
        if used>=3 or slot<0 or slot>=existing.size():return false
        var pool: Array[String]=EquipmentSpecialEffectPolicy.eligible_ids(item)
        var blocked: Dictionary={}
        for e in existing:
            if e is Dictionary:blocked[str(e.get("effect_id", ""))]=true
        var options: Array[String]=[]
        for effect_id in pool:
            if not blocked.has(effect_id):options.append(effect_id)
        if options.size()<2:return false
        options.sort()
        cost=250
        var special_rng=RandomNumberGenerator.new()
        special_rng.seed=hash("special-forge|%s|%d|%d|%s"%[uid,slot,used,str(existing)])
        var special_first: String=options.pop_at(special_rng.randi_range(0,options.size()-1))
        var special_second: String=options[special_rng.randi_range(0,options.size()-1)]
        item["special_reroll_count"]=used+1
        next.forge_pending={"uid":uid,"kind":"special_effect","effect_index":slot,"choices":[special_first,special_second]}
    elif action=="reroll":
        if slot<0 or slot>1 or int(item.reroll_counts[slot])>=3: return false
        cost=250
        var options: Array=[]
        var keys: Array=roller.cards.keys()
        keys.sort()
        for cid in keys:
            if item.cards.has(cid): continue
            var trial: Dictionary=item.duplicate(true)
            trial.random_cards[slot]=cid
            trial.cards=trial.fixed_cards+trial.random_cards
            if str(item.slot)=="main_weapon" and (str(roller.cards[cid].weapon)!=str(item.affinity_weapon) or str(roller.cards[cid].attr)==str(item.rolled_attribute)): continue
            if roller.validate_item(trial): options.append(cid)
        if options.size()<2: return false
        var rng=RandomNumberGenerator.new()
        rng.seed=hash("%s|%d|%d" % [uid,slot,int(item.reroll_counts[slot])])
        var a: int=rng.randi_range(0,options.size()-1)
        var first=options.pop_at(a)
        var second=options[rng.randi_range(0,options.size()-1)]
        item.reroll_counts[slot]=int(item.reroll_counts[slot])+1
        next.forge_pending={"uid":uid,"slot":slot,"choices":[first,second]}
    else: return false
    if int(next.base_gold)<cost or int(next.materials)<material_cost: return false
    next.base_gold=int(next.base_gold)-cost
    next.materials=int(next.materials)-material_cost
    return _commit(next)

func dismantle_many(uids: Array[String]) -> bool:
    # Single validated transaction: no partial dismantle and only one save.
    if str(state.phase)!="hub" or save_blocked or not state.forge_pending.is_empty() or uids.is_empty():
        return false
    var seen: Dictionary={}
    var next: Dictionary=state.duplicate(true)
    var recovered_materials: int=0
    for uid in uids:
        if seen.has(uid) or not next.inventory.has(uid) or next.loadout.values().has(uid):
            return false
        seen[uid]=true
        var item: Dictionary=next.inventory[uid]
        var rarity_index: int=RARITIES.find(str(item.get("rarity","")))
        if rarity_index<0:return false
        recovered_materials+=rarity_index+1
    for uid in uids:
        next.inventory.erase(uid)
    next.materials=int(next.materials)+recovered_materials
    return _commit(next)

func resolve_forge(index: int) -> bool:
    if str(state.phase)!="hub" or state.forge_pending.is_empty() or index< -1 or index>1: return false
    var next: Dictionary=state.duplicate(true)
    var pending: Dictionary=next.forge_pending
    if index>=0:
        var item: Dictionary=next.inventory[str(pending.uid)]
        if str(pending.get("kind", "card"))=="special_effect":
            item.special_effects[int(pending.effect_index)]={"effect_id":str(pending.choices[index])}
        else:
            item.random_cards[int(pending.slot)]=pending.choices[index]
            item.cards=item.fixed_cards+item.random_cards
    next.forge_pending={}
    return _commit(next)
