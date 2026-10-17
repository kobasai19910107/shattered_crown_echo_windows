class_name CoopCampaignController
extends RefCounted

const SAVE="user://coop_campaign_v1.json"
var save_path: String=SAVE
var members: Array[CoopMemberRun]=[CoopMemberRun.new(),CoopMemberRun.new()]
var initialized: Array=[false,false]
var combat: CoopBattleController=null
var proposal: Dictionary={}
var retreat_requested: bool=false
var notice: String=""
var identity: Dictionary={}

static func valid_items(items: Dictionary) -> bool:
    var roller=Step8EquipmentRoller.new()
    if not roller.load_data() or items.size()!=6: return false
    var ids: Array=[]
    for slot in Region1RunController.SLOTS:
        if not items.get(slot) is Dictionary: return false
        var item: Dictionary=items[slot]
        for field in ["cards","fixed_cards","random_cards","reroll_counts"]:
            if not item.get(field) is Array: return false
        for field in ["base_hp","effective_hp","enhance_level","socket_count"]:
            if item.has(field) and not (item[field] is int or item[field] is float): return false
        if item.reroll_counts.size()!=2: return false
        if int(item.get("special_reroll_count",0))<0 or int(item.get("special_reroll_count",0))>3:return false
        for count in item.reroll_counts:
            if not (count is int or count is float) or int(count)<0 or int(count)>3: return false
        if not roller.validate_item(item) or str(item.get("slot",""))!=slot: return false
        var uid: String=str(item.get("instance_id",""))
        if uid=="" or ids.has(uid): return false
        ids.append(uid)
        if not roller.templates.has(str(item.get("equipment_id",""))): return false
        var template: Dictionary=roller.templates[str(item.equipment_id)]
        if int(item.get("base_hp",-1))!=maxi(1,int(template.Drop_HP)): return false
        if str(item.get("rarity",""))!=str(template.Rarity) or Step8EquipmentRoller.SLOT_CODES.get(str(template.Slot),"")!=slot: return false
        var level: int=int(item.get("enhance_level",0))
        if level<0 or level>int(template.EnhanceCap): return false
        if int(item.get("effective_hp",item.base_hp))!=int(item.base_hp)+level*int(template.HP_Per_Enhance): return false
        # v1.9.1 U/W effects are local to the originating four cards.
        # Reject forged/unknown remote effects; accept old empty arrays.
        if not EquipmentSpecialEffectPolicy.validate_effects(item, true): return false
        var sockets: int=int(item.get("socket_count",template.InitialSocketMin))
        if sockets<int(template.InitialSocketMin) or sockets>int(template.SocketCap): return false
    return roller.inspect_deck(items).deck.size()==24

func initialize_member(seat: int,items: Dictionary) -> bool:
    if seat not in [0,1] or initialized[seat] or not valid_items(items): return false
    var before=export_state()
    if not members[seat].adopt_initial(items): return false
    initialized[seat]=true
    return commit_or_restore(before)

func phase() -> String:
    if not initialized.all(func(v):return bool(v)): return "lobby"
    if combat!=null and not combat.finished: return "battle"
    for kind in ["reward","defeat","service","route"]:
        if members.any(func(m):return str(m.state.phase)==kind): return kind
    return "hub"

func apply(seat: int,cmd: Dictionary) -> bool:
    if seat not in [0,1] or not initialized.all(func(v):return bool(v)): return false
    var before=export_state()
    var op: String=str(cmd.get("op",""))
    var ok: bool=false
    var member: CoopMemberRun=members[seat]
    if op=="propose" and seat==0 and proposal.is_empty():
        var kind: String=str(cmd.get("kind",""))
        var value: int=int(cmd.get("value",-1))
        if kind=="begin" and phase()=="hub" and value>0: ok=true
        elif kind=="region" and phase()=="hub" and value>=0 and value<6 and (value==0 or int(member.state.region_progress[value-1])==4): ok=true
        elif kind=="route" and phase()=="route" and members.all(func(m):return str(m.state.phase)=="route") and value>=0 and value<member.state.run.routes.size(): ok=true
        if ok: proposal={"kind":kind,"value":value}
    elif op=="cancel_proposal" and seat==0:
        proposal={}; ok=true
    elif op=="confirm" and seat==1 and not proposal.is_empty():
        ok=confirm_proposal()
    elif op=="combat" and combat!=null and phase()=="battle" and cmd.get("action") is Dictionary:
        ok=combat.apply(seat,cmd.action)
        if ok: ok=checkpoint_combat()
    elif op=="reward" and str(member.state.phase)=="reward": ok=member.take_reward(int(cmd.get("index",-1)))
    elif op=="defeat" and str(member.state.phase)=="defeat" and cmd.get("indices") is Array: ok=member.resolve_defeat(cmd.indices)
    elif op=="service" and str(member.state.phase)=="service": ok=member.service(str(cmd.get("action","")),int(cmd.get("index",-1)))
    elif op=="equip" and phase()=="hub" and proposal.is_empty(): ok=member.equip(str(cmd.get("uid","")))
    elif op=="forge" and phase()=="hub" and proposal.is_empty(): ok=member.forge(str(cmd.get("uid","")),str(cmd.get("action","")),int(cmd.get("slot",-1)))
    elif op=="forge_select" and phase()=="hub": ok=member.resolve_forge(int(cmd.get("index",-1)))
    elif op=="retreat" and phase()!="hub": retreat_requested=true; ok=true
    if not ok:
        import_state(before)
        return false
    sync_routes()
    retreat_if_ready()
    return commit_or_restore(before)

func confirm_proposal() -> bool:
    var kind: String=str(proposal.kind)
    var value: int=int(proposal.value)
    var purchased: Array=[]
    if kind=="route":
        purchased=members.map(func(p):return p.state.run.support.duplicate(true))
    var shared_shop_npc: String=""
    for member in members:
        if kind=="begin" and not member.begin(value+members.find(member)*104729): return false
        if kind=="region" and not member.select_region(value): return false
        if kind=="route":
            # The host rolls the NPC once; both members visit the SAME facility.
            if not member.choose_route(value,shared_shop_npc): return false
            if str(member.state.run.kind)=="shop" and shared_shop_npc=="":
                shared_shop_npc=str(member.state.run.get("shop_npc","merchant"))
    proposal={}
    if kind=="route" and str(members[0].state.phase)=="battle":
        var m: CoopMemberRun=members[0]
        var ids: Array=m.battle.enemies.map(func(e):return str(e.id))
        var loadouts: Array=members.map(func(p):return p.state.run.items)
        var hp: Array=members.map(func(p):return p.state.run.hp)
        combat=CoopBattleController.new()
        if not combat.start(m.battle.active_seed,loadouts,hp,ids,purchased): return false
        for i in range(2):
            members[i].battle=combat.players[i]
            members[i].state.run.battle=combat.players[i].export_region1_state()
            members[i].state.run.battle_start=members[i].state.run.battle.duplicate(true)
    sync_routes()
    return true

func sync_routes() -> void:
    if members.all(func(m):return str(m.state.phase)=="route"):
        members[1].state.run.routes=members[0].state.run.routes.duplicate()
    if members.all(func(m):return str(m.state.phase)=="hub"):
        if combat!=null: combat.dispose()
        combat=null

func checkpoint_combat() -> bool:
    for i in range(2):
        members[i].battle=combat.players[i]
        if not members[i].checkpoint(): return false
    return true

func retreat_if_ready() -> void:
    if not retreat_requested: return
    if members.any(func(m):return str(m.state.phase) in ["reward","defeat"]): return
    if combat!=null and combat.players.any(func(b):return b.is_hand_selection_active() or not b.resolving_card.is_empty()): return
    for m in members:
        if not m.state.run.is_empty():
            m._return(m.state,m.state.run.bag,true)
            m.battle=null
    if combat!=null: combat.dispose()
    combat=null; proposal={}; retreat_requested=false

func export_state() -> Dictionary:
    return {"schema":1,"members":members.map(func(m):return m.state.duplicate(true)),"initialized":initialized.duplicate(),
        "combat":{} if combat==null else combat.export_state(),"proposal":proposal.duplicate(true),"retreat_requested":retreat_requested,"identity":identity.duplicate(true)}

func import_state(data: Dictionary) -> bool:
    if int(data.get("schema",0))!=1 or not data.get("members") is Array or data.members.size()!=2: return false
    if not data.get("initialized") is Array or data.initialized.size()!=2 or not data.get("proposal") is Dictionary: return false
    if not data.get("combat") is Dictionary or not data.get("retreat_requested") is bool or not data.get("identity",{}) is Dictionary: return false
    var restored: Array[CoopMemberRun]=[]
    for i in range(2):
        var m=CoopMemberRun.new()
        if not data.members[i] is Dictionary:return false
        var incoming: Dictionary=data.members[i].duplicate(true)
        Region1RunController.normalize_legacy_common_sockets(incoming)
        if not m.valid_state(incoming):return false
        if not data.initialized[i] is bool: return false
        if bool(data.initialized[i]) and not bool(incoming.get("initial_claimed",false)): return false
        m.state=incoming
        if not m.state.has("recent_drop_pairs"):
            m.state.recent_drop_pairs=[]
        restored.append(m)
    var encounter: CoopBattleController=null
    if not data.combat.is_empty():
        encounter=CoopBattleController.new()
        if not encounter.import_state(data.combat): return false
        for i in range(2):
            if str(restored[i].state.phase)=="battle":
                # Old checkpoints can contain the retired Bleed enemy definitions.
                # Compare canonicalized battle snapshots, not raw legacy JSON.
                var legacy_member: CoopPlayerState=CoopPlayerState.new()
                if not legacy_member.import_region1_state(restored[i].state.run.battle): return false
                if JSON.stringify(legacy_member.export_region1_state())!=JSON.stringify(encounter.players[i].export_region1_state()): return false
                restored[i].battle=encounter.players[i]
                # Keep the member checkpoint aligned with the normalized live Core after JSON load.
                restored[i].state.run.battle=encounter.players[i].export_region1_state()
    elif restored.any(func(m):return str(m.state.phase)=="battle"): return false
    if restored[0].state.region_progress!=restored[1].state.region_progress:
        if encounter==null or not encounter.finished or not encounter.victory: return false
        if not restored.any(func(m):return str(m.state.phase)=="reward"): return false
    if combat!=null: combat.dispose()
    members=restored; combat=encounter; initialized=data.initialized.duplicate()
    proposal=data.proposal.duplicate(true); retreat_requested=bool(data.retreat_requested)
    identity=data.get("identity",{}).duplicate(true)
    return true

func commit_or_restore(before: Dictionary) -> bool:
    var after=export_state()
    # Validate a separate model before committing; disk failure restores both players.
    var validator=CoopCampaignController.new()
    var ok: bool=validator.import_state(after)
    if validator.combat!=null: validator.combat.dispose()
    if ok and Region1Save.write(save_path,after): return true
    import_state(before)
    notice="協力用保存に失敗しました。直前の確定状態を保持します。"
    return false

func load_saved() -> bool:
    return import_state(Region1Save.read(save_path))

func public_view(seat: int) -> Dictionary:
    var view: Dictionary={"phase":phase(),"proposal":proposal.duplicate(true),"retreat_requested":retreat_requested,"members":[]}
    for m in members:
        var state: Dictionary=m.state.duplicate(true)
        if not state.run.is_empty():
            state.run.erase("rng_state"); state.run.erase("battle"); state.run.erase("battle_start")
        view.members.append(state)
    if combat!=null:
        view["combat"]={"active":combat.active,"round":combat.round_number,"finished":combat.finished,"victory":combat.victory,
            "intents":combat.intent_targets(),"players":[],"enemies":combat.players[0].enemies.duplicate(true)}
        for b in combat.players:
            var info: Array=[]
            for i in range(b.hand.size()):
                info.append({"cost":b.get_effective_cost(i),"target":b.get_effective_target_type(i),"usable":b.can_use_card(i)})
            view.combat.players.append({"hp":b.player_hp,"max_hp":b.player_max_hp,"mana":b.current_mana,"block":b.player_block,
                "hand":b.hand.duplicate(true),"discard":b.discard_pile.duplicate(true),"power":b.power_zone.duplicate(true),
                "draw_count":b.draw_pile.size(),"weapon_traits":b.weapon_traits.duplicate(true),"attribute_traits":b.attribute_traits.duplicate(true),
                "status":b.campaign_status.duplicate(true),"bleed":{"Bleed":0,"BleedTurns":0}, # Legacy wire compatibility only
                "pending":b.pending_hand_selection.duplicate(true),"cards_info":info,"logs":b.logs.slice(maxi(0,b.logs.size()-80)),"notice":b.last_notice})
    view["seat"]=seat
    return view
