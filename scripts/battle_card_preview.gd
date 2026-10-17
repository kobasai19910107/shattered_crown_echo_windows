class_name BattleCardPreview
extends RefCounted

# Isolated Core simulation. No hidden draw order, speculative choices, or shared RNG.
static func inspect(source: BattleController,index: int,target: int=-1) -> Dictionary:
    if index<0 or index>=source.hand.size():return {}
    var card: Dictionary=source.hand[index]
    var enemy_required: bool=source.get_effective_target_type(index)=="enemy"
    var valid_target: bool=source.is_enemy_target_valid(target)
    var enemy_condition: bool=str(card.get("condition_trait","")) in ["爆発","鈍化","呪印","猛毒"]
    var result: Dictionary={"cost":source.get_effective_cost(index),"target":target if enemy_required else -1,"waiting":enemy_required and not valid_target,"condition_waiting":enemy_condition and not valid_target,"condition":source._is_card_condition_met(card,target if valid_target else -1),"partial":false,"available":false}
    if enemy_required and not valid_target:return result
    if not source.can_use_card(index):result["reason"]="Mana不足" if source.current_mana<int(result.cost) else "現在使用できません";return result
    var sim=BattleController.new();sim.database=source.database
    for property in source.get_script().get_script_property_list():
        var key: String=str(property.name)
        if key in ["database","battle_rng","draw_pile","discard_pile"]:continue
        var value=source.get(key)
        if value is Array or value is Dictionary:sim.set(key,value.duplicate(true))
        elif value is int or value is float or value is bool or value is String:sim.set(key,value)
    sim.battle_rng.seed=source.battle_rng.seed;sim.battle_rng.state=source.battle_rng.state
    # Draw and Salvage identities remain unknown until the actual action.
    sim.draw_pile=[];sim.discard_pile=[]
    result.partial=int(card.get("draw_count",0))>0 or str(card.get("text","")).contains("Draw") or str(card.get("text","")).contains("Salvage")
    var hits: Array=[]
    sim.presentation_event.connect(func(event: Dictionary):
        if str(event.get("kind","")) in ["enemy_hit","execution"]:hits.append(event.duplicate(true)))
    if not sim.use_card(index,target if enemy_required else -1):result.partial=true;return result
    result.available=true;result.partial=bool(result.partial) or sim.is_hand_selection_active() or (sim.last_notice!=source.last_notice and sim.last_notice.contains("drawn"))
    result["hp_delta"]=sim.player_hp-source.player_hp
    result["block_delta"]=sim.player_block-source.player_block
    result["mana_after"]=sim.current_mana
    result["weapon_changes"]=[]
    for trait_name in sim.weapon_traits:
        if bool(sim.weapon_traits[trait_name])!=bool(source.weapon_traits.get(trait_name,false)):result.weapon_changes.append(str(trait_name)+(" OFF→ON" if bool(sim.weapon_traits[trait_name]) else " ON→OFF"))
    result["weapon_traits"]=sim.weapon_traits.duplicate(true)
    result["attribute_traits"]=sim.attribute_traits.duplicate(true)
    result["draw"]=int(sim.playtest_stats.get("cards_drawn",0))-int(source.playtest_stats.get("cards_drawn",0))
    if enemy_required:
        result["before"]=source.enemies[target].duplicate(true);result["after"]=sim.enemies[target].duplicate(true)
        result["damage"]=0;result["absorbed"]=0
        for hit in hits:
            if int(hit.enemy)==target:
                result.damage+=int(hit.hp_loss);result.absorbed+=int(hit.get("block_loss",0))
        if int(source.enemies[target].get("phase_index",0))!=int(sim.enemies[target].get("phase_index",0)):result.partial=true
    else:result["damage"]=0;result["absorbed"]=0
    return result

static func describe(value: Dictionary) -> String:
    if value.is_empty():return "予測なし"
    if bool(value.waiting):return "対象選択後に判定：敵をホバー、またはカード選択前に敵をクリック。"
    if not bool(value.available):return str(value.get("reason","Draw・選択後の結果は未確定です。"))
    var text: String="%sHP減少 %d / 敵Block消費 %d / 自分Block %+d / Mana → %d"%[("#%d："%(int(value.target)+1)) if int(value.target)>=0 else "",int(value.damage),int(value.absorbed),int(value.block_delta),int(value.mana_after)]
    if not value.get("weapon_changes",[]).is_empty():text+=" / "+"・".join(value.weapon_changes)
    if bool(value.partial):text+="\n解決済み部分の予測。Draw・手札選択・Phase移行後は未確定。"
    else:text+=" / Draw %d"%int(value.draw)
    return text

static func public_condition(card: Dictionary,player: Dictionary,enemy: Dictionary) -> bool:
    var trait_name: String=str(card.get("condition_trait",""));var threshold: int=int(card.get("condition_threshold",0))
    if trait_name=="" or threshold<=0:return false
    if player.get("attribute_traits",{}).has(trait_name):return int(player.attribute_traits[trait_name])>=threshold
    if player.get("weapon_traits",{}).has(trait_name):return bool(player.weapon_traits[trait_name])
    return int(enemy.get(trait_name,enemy.get("attribute_traits",{}).get(trait_name,0)))>=threshold
