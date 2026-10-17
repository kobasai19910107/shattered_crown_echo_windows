extends SceneTree

# Stage 4 integration harness; requires Godot 4.7.2 (not a Python simulation).
# godot --headless --path . -s res://tests/equipment_attribute_affix_test.gd
var passes: int = 0
var failures: Array[String] = []
const ATTRS := ["物理","炎","水","雷","地","光","闇","毒","秘術","風"]
const TRAITS := ["剛力","爆発","鈍化","帯電","堅牢","恩寵","呪印","猛毒","魔珠","疾風"]

func check(label: String, ok: bool) -> void:
    if ok:
        passes+=1
    else:
        failures.append(label)
        push_error("FAIL: "+label)

func _initialize() -> void:
    call_deferred("run")

func create_fixture(effect_id: String, card_id: String, also: Array = []) -> Dictionary:
    var battle = BattleController.new()
    battle.start_battle(873211, [], "standard_trio")
    var card: Dictionary = battle.database.cards[card_id].duplicate(true)
    card["source_equipment_uid"] = "ATTRIBUTE_FIXTURE"
    card["source_slot"] = "main_weapon"
    card["card_instance_uid"] = "ATTRIBUTE_FIXTURE:main_weapon:0"
    var e: Array = [{"effect_id":effect_id}]
    for x in also: e.append({"effect_id":str(x)})
    battle.active_equipment_loadout = {"main_weapon":{
        "instance_id":"ATTRIBUTE_FIXTURE","slot":"main_weapon",
        "cards":[card_id,"C001","C002","C003"],
        "special_effects":e
    }}
    return {"battle":battle,"card":card}

func find_sample(master: Dictionary, effect_id: String) -> String:
    for card_id in master.keys():
        var cards: Array = [str(card_id)]
        for extra_id in ["C001","C002","C003","C004","C005"]:
            if cards.size()>=4: break
            if not cards.has(extra_id): cards.append(extra_id)
        if EquipmentSpecialEffectPolicy.eligible_ids({"cards":cards}).has(effect_id):
            return str(card_id)
    return ""

func run() -> void:
    var b = BattleController.new()
    b.start_battle(873211, [], "standard_trio")
    var master: Dictionary=b.database.cards
    check("120 official cards", b.database.official_card_ids.size()==120)
    check("48 enabled affix ids",EquipmentSpecialEffectPolicy.EFFECT_IDS.size()==48)
    check("10 generic + 18 weapon + 20 attribute",EquipmentSpecialEffectPolicy.U_EFFECT_IDS.size()==10 and EquipmentSpecialEffectPolicy.W_EFFECT_IDS.size()==18 and EquipmentSpecialEffectPolicy.A_EFFECT_IDS.size()==20)
    for effect_id in EquipmentSpecialEffectPolicy.A_EFFECT_IDS:
        var sample: String=find_sample(master,effect_id)
        check("eligible card exists "+effect_id,sample!="")
        if sample=="": continue
        var fx: Dictionary=create_fixture(effect_id,sample)
        var battle: BattleController=fx.battle
        var card: Dictionary=fx.card
        check("origin matches "+effect_id,battle._local_attribute_effect_ids(card).has(effect_id))
        card["source_equipment_uid"]="ANOTHER_EQUIPMENT"
        check("foreign equipment ignored "+effect_id,battle._local_attribute_effect_ids(card).is_empty())
        check("registered "+effect_id,EquipmentSpecialEffectPolicy.NAMES.has(effect_id) and EquipmentSpecialEffectPolicy.DETAILS.has(effect_id))
    # Generation: each A odd adds only +1, globally shared by all equipment.
    for i in range(10):
        var effect_id: String="A%02d"%(1+i*2)
        var trait: String=TRAITS[i]
        var attr: String=ATTRS[i]
        var sample: String=""
        for card_id in master:
            var c: Dictionary=master[card_id]
            if str(c.get("attribute",""))==attr and int(c.get("attribute_trait_gain",0))>0:
                sample=str(card_id)
                break
        check("generator candidate "+effect_id,sample!="")
        if sample=="": continue
        var setup: Dictionary=create_fixture(effect_id,sample)
        var ctl: BattleController=setup.battle
        var source: Dictionary=setup.card
        ctl.resolving_card=source
        if TraitSystem.is_player_trait(trait):
            ctl._gain_player_attribute_trait(trait,1,source)
            check("player trait +2 "+effect_id,ctl.get_attribute_trait(trait)==2)
            ctl._gain_player_attribute_trait(trait,1,source)
            check("global turn +1 cap "+effect_id,ctl.get_attribute_trait(trait)==3)
        else:
            ctl._gain_enemy_attribute_trait(0,trait,1,source)
            check("enemy trait +2 "+effect_id,ctl.get_enemy_attribute_trait(0,trait)==2)
            ctl._gain_enemy_attribute_trait(0,trait,1,source)
            check("global turn +1 cap "+effect_id,ctl.get_enemy_attribute_trait(0,trait)==3)
    # Snapshot-based exploit bonuses cannot be activated by the same card's gain.
    for effect_id in ["A02","A06","A16"]:
        var attr: String={"A02":"物理","A06":"水","A16":"毒"}[effect_id]
        var sample: String=""
        for id in master:
            if str(master[id].get("attribute",""))==attr and str(master[id].get("card_type",""))=="attack":
                sample=str(id);break
        var setup: Dictionary=create_fixture(effect_id,sample)
        var ctl: BattleController=setup.battle
        var c: Dictionary=setup.card
        check("no threshold no damage "+effect_id,ctl._local_attack_bonus(c)==0)
        c["_local_attribute_before"]={"player3":true,"enemy3":true}
        check("threshold attack bonus +2 "+effect_id,ctl._local_attack_bonus(c)==2)
    for entry in [["A08","雷"],["A10","地"]]:
        var sample: String=""
        for id in master:
            var c: Dictionary=master[id]
            if str(c.get("attribute",""))==entry[1] and str(c.get("card_type",""))=="skill" and int(c.get("base_block",0))>0:
                sample=str(id);break
        var setup: Dictionary=create_fixture(entry[0],sample)
        var ctl: BattleController=setup.battle
        var c: Dictionary=setup.card
        c["_local_attribute_before"]={"player3":true}
        check("block bonus +3 "+entry[0],ctl._local_skill_block_bonus(c,5)==3)
    for entry in [["A12","光"],["A14","闇"]]:
        var sample: String=""
        for id in master:
            if str(master[id].get("attribute",""))==entry[1] and (entry[0]=="A12" or str(master[id].get("card_type",""))=="attack"):
                sample=str(id);break
        var setup: Dictionary=create_fixture(entry[0],sample)
        var ctl: BattleController=setup.battle
        var c: Dictionary=setup.card
        c["_local_attribute_before"]={"player3":true,"enemy3":true}
        c["_local_attribute_attack_executed"]=true
        ctl.player_hp=40
        ctl._local_attribute_after_card(c)
        check("local heal +1 "+entry[0],ctl.player_hp==41)
        ctl._local_attribute_after_card(c)
        check("heal cap +1 "+entry[0],ctl.player_hp==41)
    # A18 is triggered by actual threshold crossing; crossing two thresholds at
    # once may generate two Mana, but only one local Block3.
    var arcane: Dictionary=create_fixture("A18","C105")
    arcane.battle.resolving_card=arcane.card
    arcane.battle._gain_player_attribute_trait("魔珠",6,arcane.card)
    check("A18 one Block3 despite two thresholds",arcane.battle.player_block==3)
    # A20 consumes a real Wind cost-reduction charge instead of checking a flag.
    var wind: Dictionary=create_fixture("A20","C111")
    wind.battle.hand=[wind.card]
    wind.battle.swift_cost_reduction_charges=1
    var before_block: int=wind.battle.player_block
    check("Wind card can be played",wind.battle.can_use_card(0))
    wind.battle.use_card(0,-1)
    check("A20 real swift discount consumed",wind.battle.swift_cost_reduction_charges==0 and wind.battle.player_block>=before_block+3)
    print("EQUIPMENT_ATTRIBUTE_AFFIX_TEST %d PASS / %d FAIL %s"%[passes,failures.size(),str(failures)])
    quit(0 if failures.is_empty() else 1)
