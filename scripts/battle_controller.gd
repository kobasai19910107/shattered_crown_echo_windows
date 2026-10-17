class_name BattleController
extends RefCounted

# Read-only presentation notifications; no state, RNG or serialized properties.
signal presentation_event(event: Dictionary)

const HAND_LIMIT := 10
const BASE_MANA := 3
const DEFAULT_PLAYER_MAX_HP := 48
# Compatibility alias for older validation helpers; runtime combat uses player_max_hp.
const PLAYER_MAX_HP := DEFAULT_PLAYER_MAX_HP
const VULNERABLE_MULTIPLIER := 1.25

var database: CardDatabase
var battle_rng = RandomNumberGenerator.new()
var active_seed: int = 1001
var active_enemy_preset: String = "standard_trio"
var active_equipment_loadout: Dictionary = {}
var equipment_special_effects: Array[Dictionary] = []

var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var power_zone: Array[Dictionary] = [] # Deployed Power cards are permanent for this battle; never recycle.
var resolving_card: Dictionary = {}

var player_max_hp: int = DEFAULT_PLAYER_MAX_HP
var player_hp: int = DEFAULT_PLAYER_MAX_HP
var player_block: int = 0
var current_mana: int = BASE_MANA

var weapon_traits = {
    "流転": false,
    "精密": false,
    "連刃": false,
    "重撃": false,
    "魔導": false,
    "納刀": false
}
var attribute_traits = {
    "剛力": 0,
    "帯電": 0,
    "堅牢": 0,
    "恩寵": 0,
    "魔珠": 0,
    "疾風": 0
}
var swift_cost_reduction_charges: int = 0
var curse_lifesteal_used: bool = false

# Registered by 継続効果 cards. Values stack additively if multiple copies are played.
var power_trait_engines: Array[Dictionary] = [] # STEP9: individual Power instances, each triggers once per player turn.

var continuous_effects = {
    "physical_first_attack_damage": 0,
    "fire_first_explosion_bonus": 0,
    "water_first_slow_attack_reduction": 0,
    "lightning_first_retaliation_bonus": 0,
    "earth_turn_start_block_bonus": 0,
    "light_turn_start_heal_bonus": 0,
    "dark_lifesteal_bonus": 0,
    "poison_damage_bonus": 0,
    "arcane_first_magic_mana_block": 0,
    "wind_first_swift_card_draw": 0
}
var first_attack_engine_used: bool = false
var first_magic_orb_engine_used: bool = false
var first_swift_engine_used: bool = false
var first_slow_engine_used: bool = false
var first_retaliation_engine_used: bool = false

var turn_number: int = 1
var combat_over: bool = false
var victory: bool = false
# v1.6 immutable result snapshot created exactly once when combat ends.
var battle_result: Dictionary = {}
var battle_end_reason: String = ""
var logs: Array[String] = []
var last_notice: String = ""

# v1.6 playtest telemetry. This is battle-local and contains no account/user data.
var battle_deck_ids: Array[String] = []
var playtest_stats: Dictionary = {}

# During a mandatory Bottom/Discard choice the confirmed card remains in resolving_card.
var pending_hand_selection = {
    "mode": "",
    "remaining": 0
}

# EnemyOrderIndex is represented directly by array order in this prototype.
var enemies: Array = []
var region1_player_status: Dictionary = {"Bleed":0,"BleedTurns":0} # Legacy save/wire only; always zero.
var region1_support: Dictionary = {}
var campaign_status: Dictionary = {}

func _init() -> void:
    database = CardDatabase.new()

func start_battle(seed_value: int = 1001, deck_card_ids: Array = [], enemy_preset_id: String = "standard_trio", equipment_loadout: Dictionary = {}) -> void:
    active_seed = seed_value
    active_enemy_preset = enemy_preset_id
    active_equipment_loadout = equipment_loadout.duplicate(true)
    battle_rng.seed = active_seed
    logs.clear()
    last_notice = ""
    combat_over = false
    victory = false
    battle_result = {}
    battle_end_reason = ""
    turn_number = 1
    region1_player_status = {"Bleed":0,"BleedTurns":0}
    region1_support = {}
    campaign_status = {}

    player_max_hp = _resolve_player_max_hp(active_equipment_loadout)
    equipment_special_effects = _collect_equipment_special_effects(active_equipment_loadout)
    player_hp = player_max_hp
    player_block = 0
    current_mana = BASE_MANA

    for trait_name in weapon_traits.keys():
        weapon_traits[trait_name] = false
    attribute_traits.clear()
    for trait_name in TraitSystem.PLAYER_TRAITS:
        attribute_traits[trait_name] = 0
    swift_cost_reduction_charges = 0
    curse_lifesteal_used = false
    power_trait_engines.clear()
    for effect_name in continuous_effects.keys():
        continuous_effects[effect_name] = 0
    first_attack_engine_used = false
    first_magic_orb_engine_used = false
    first_swift_engine_used = false
    first_slow_engine_used = false
    first_retaliation_engine_used = false

    hand.clear()
    discard_pile.clear()
    power_zone.clear()
    resolving_card = {}
    pending_hand_selection = {"mode": "", "remaining": 0}

    if not database.load_data():
        _log("ERROR: card database could not be loaded.")
        _finalize_battle("ERROR", "card_database_load_failed")
        return

    if deck_card_ids.is_empty():
        draw_pile = database.create_prototype_deck()
    else:
        draw_pile = database.create_deck_from_ids(deck_card_ids)
        # Equipment-local effects require card instance provenance. The card ID
        # list and shuffle order are unchanged; incomplete/debug loadouts
        # deliberately retain the legacy untagged behavior.
        EquipmentCardOrigin.attach(draw_pile, deck_card_ids, active_equipment_loadout)
    battle_deck_ids.clear()
    for card in draw_pile:
        battle_deck_ids.append(str(card.get("id", "?")))
    _shuffle_with_battle_rng(draw_pile)
    _create_enemies_from_preset(active_enemy_preset)
    _reset_playtest_stats()

    playtest_stats["combat_start_hp"] = player_hp
    _log("DIAG BATTLE_START mode=solo seed=%d preset=%s hp=%d/%d deck=%s loadout=%s effects=%s enemies=%s" % [active_seed,active_enemy_preset,player_hp,player_max_hp,str(battle_deck_ids),str(active_equipment_loadout),str(equipment_special_effects),str(_diag_enemies())])
    _log("Battle Start: STEP9 / v1.9.0 / Seed %d / deck %d cards / preset %s / MaxHP %d / equipment effects %d." % [active_seed, draw_pile.size(), active_enemy_preset, player_max_hp, equipment_special_effects.size()])
    _player_turn_start(true)

func _resolve_player_max_hp(equipment_loadout: Dictionary) -> int:
    if equipment_loadout.is_empty():
        return DEFAULT_PLAYER_MAX_HP
    var total = 0
    var counted = 0
    for raw_slot in equipment_loadout.keys():
        var slot_data = equipment_loadout[raw_slot]
        if typeof(slot_data) != TYPE_DICTIONARY:
            continue
        var effective_hp = int(slot_data.get("effective_hp", slot_data.get("base_hp", 0)))
        if effective_hp > 0:
            total += effective_hp
            counted += 1
    if counted != 6 or total <= 0:
        return DEFAULT_PLAYER_MAX_HP
    return total

func start_region1(seed_value: int, deck: Array, enemy_ids: Array, loadout: Dictionary, carried_hp: int, support: Dictionary = {}) -> bool:
    var catalog = RegionEnemyCatalog.new()
    if enemy_ids.is_empty(): return false
    for enemy_id in enemy_ids:
        if not catalog.entries.has(str(enemy_id)): return false
    start_battle(seed_value,deck,"region1_stage1",loadout)
    active_enemy_preset="region%s_stage1"%str(enemy_ids[0]).substr(1,1)
    enemies.clear()
    for i in range(enemy_ids.size()): enemies.append(catalog.create(str(enemy_ids[i]),i+1,battle_rng))
    player_hp = clampi(carried_hp,1,player_max_hp)
    region1_support = support.duplicate(true)
    player_block += int(support.get("block",0))*4
    if int(support.get("draw",0))>0: draw_cards(1)
    region1_support.erase("block")
    region1_support.erase("draw")
    playtest_stats["combat_start_hp"] = player_hp
    _log("DIAG ENCOUNTER_START mode=solo seed=%d region=%s stage=I ids=%s hp=%d/%d deck=%s equipment=%s effects=%s enemies=%s hand=%s" % [active_seed,active_enemy_preset,str(enemy_ids),player_hp,player_max_hp,str(battle_deck_ids),str(active_equipment_loadout),str(equipment_special_effects),str(_diag_enemies()),str(_diag_hand())])
    _log("Region 1 Stage I: %s" % str(enemy_ids))
    return true

func _legacy_enemy_data_matches(enemy_id: String, saved: Dictionary, canonical: Dictionary) -> bool:
    var adjustable: Dictionary = {
        "R1-B04":["signature_player_status","signature_player_status_value","role_description","signature_action_description"],
        "R1-E02":["ai_pattern","signature_action_key","signature_condition_status","signature_bonus_damage","role_description","signature_action_description"],
        "R1-N05":["enemy_name","role_name","signature_player_status","signature_player_status_value","signature_damage","signature_hits","signature_action_name","role_description","signature_action_description"],
        "R2-B02":["enemy_name","role_name","role_description","signature_action_name","signature_action_description","signature_action_key","signature_player_status","signature_player_status_value","signature_condition_status","signature_bonus_damage","ai_pattern","ai_pattern_stage_2","ai_pattern_stage_3"],
        "R2-N02":["enemy_name","role_name","role_description","signature_action_name","signature_action_description","signature_damage","signature_hits","signature_player_status","signature_player_status_value","ai_pattern"],
        "R2-N06":["role_description","signature_action_description"]
    }
    if not adjustable.has(enemy_id) or saved.size()!=canonical.size(): return false
    for key in canonical:
        if not saved.has(key): return false
        if not key in adjustable[enemy_id] and saved[key]!=canonical[key]: return false
    # Ensure legacy entries really used the deprecated condition, not arbitrary modified data.
    return true

func export_region1_state() -> Dictionary:
    var data: Dictionary = {}
    for prop in get_script().get_script_property_list():
        var key: String = str(prop.name)
        if key in ["database","battle_rng"]: continue
        var value = get(key)
        if value is Array or value is Dictionary: data[key] = value.duplicate(true)
        elif value is int or value is float or value is bool or value is String: data[key] = value
    data["rng_state"] = str(battle_rng.state)
    return data

func import_region1_state(data: Dictionary) -> bool:
    data=data.duplicate(true)
    if not data.has("campaign_status"): data["campaign_status"]={}
    if not database.load_data(): return false
    for prop in get_script().get_script_property_list():
        var key: String=str(prop.name)
        if key in ["database","battle_rng"]: continue
        var current=get(key)
        if current==null: continue
        if not data.has(key): return false
        if current is Array and not data[key] is Array: return false
        if current is Dictionary and not data[key] is Dictionary: return false
        if current is bool and not data[key] is bool: return false
        if current is String and not data[key] is String: return false
        if current is int and not (data[key] is int or data[key] is float): return false
    if not str(data.get("rng_state","")).is_valid_int(): return false
    if int(data.get("player_max_hp",0))<=0 or int(data.get("player_hp",-1))<0: return false
    if data.get("enemies",[]).is_empty(): return false
    for key in ["hand","draw_pile","discard_pile","power_zone"]:
        if not data.get(key) is Array: return false
        for card in data[key]:
            if not card is Dictionary or not database.cards.has(str(card.get("id",""))): return false
            var definition: Dictionary=database.cards[str(card.id)]
            for field in definition:
                if not card.has(field) or card[field]!=definition[field]: return false
    var catalog=RegionEnemyCatalog.new()
    for enemy in data.enemies:
        if not enemy is Dictionary or not catalog.entries.has(str(enemy.get("id",""))): return false
        if not enemy.get("r1_status") is Dictionary or not enemy.get("attribute_traits") is Dictionary: return false
        if not enemy.get("r1_data") is Dictionary: return false
        # Legacy Bleed save migration: permit only known enemy-definition fields to differ.
        var canonical: Dictionary = catalog.entries[str(enemy.id)]
        if enemy.r1_data != canonical:
            if not _legacy_enemy_data_matches(str(enemy.id),enemy.r1_data,canonical): return false
            enemy.r1_data = canonical.duplicate(true)
            if str(enemy.get("r1_action","")) == "bleed":
                enemy.r1_action = "charge" if str(enemy.id) in ["R1-E02","R2-B02"] else "attackx2"
        if int(enemy.get("hp",-1))<0 or int(enemy.get("max_hp",0))<=0 or int(enemy.get("block",-1))<0: return false
        if not enemy.has("r1_action") or not enemy.has("r1_roll") or not enemy.has("intent_index"): return false
        if RegionEnemyCatalog.PHASES.has(str(enemy.id)):
            if enemy.get("phase_hp",[])!=RegionEnemyCatalog.PHASES[str(enemy.id)]: return false
            var phase: int=int(enemy.get("phase_index",-1))
            if phase<0 or phase>=enemy.phase_hp.size() or int(enemy.max_hp)!=int(enemy.phase_hp[phase]): return false
    # Old fields are accepted but never applied. Snapshot/wire schema is unchanged.
    if not data.get("region1_player_status",{}) is Dictionary: return false
    data["region1_player_status"] = {"Bleed":0,"BleedTurns":0}
    if not data.campaign_status is Dictionary: return false
    data.campaign_status.erase("Bleed")
    # Legacy saves may not have an Expires dictionary yet.
    # Normalize it before touching its contents, keeping other timers intact.
    var saved_expires = data.campaign_status.get("Expires", {})
    if not saved_expires is Dictionary: return false
    saved_expires.erase("Bleed")
    data.campaign_status["Expires"] = saved_expires
    for status in ["Poison","Burn","Weak","Vulnerable","Shock","Frost","Frozen","Marked","ManaTax","BurnTicks"]:
        var amount = data.campaign_status.get(status,0)
        if not (amount is int or amount is float) or int(amount)<0: return false
    if not data.campaign_status.get("Expires",{}) is Dictionary: return false
    for prop in get_script().get_script_property_list():
        var key: String = str(prop.name)
        if key in ["database","battle_rng"] or not data.has(key): continue
        var value = get(key)
        if value is Array:
            value.assign(data[key])
        elif value is int: set(key,int(data[key]))
        else: set(key,data[key])
    region1_player_status = {"Bleed":0,"BleedTurns":0}
    battle_rng.seed = active_seed
    battle_rng.state = int(str(data.rng_state))
    return true


func _collect_equipment_special_effects(equipment_loadout: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for raw_slot in equipment_loadout.keys():
        var slot_data = equipment_loadout[raw_slot]
        if typeof(slot_data) != TYPE_DICTIONARY:
            continue
        for raw_effect in slot_data.get("special_effects", []):
            if typeof(raw_effect) != TYPE_DICTIONARY:
                continue
            var effect: Dictionary = raw_effect
            var copy = effect.duplicate(true)
            copy["source_slot"] = str(raw_slot)
            copy["source_equipment_uid"] = str(slot_data.get("instance_id", ""))
            copy["source_item"] = str(slot_data.get("item_name", slot_data.get("item_id", "Equipment")))
            result.append(copy)
    return result

# Local effects are tied to an equipment instance and its four card instances.
# This guard is shared by U (generic) and W (weapon) effects.
func _local_effect_ids(card: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var slot: String = str(card.get("source_slot", ""))
    if not active_equipment_loadout.has(slot):
        return result
    var item = active_equipment_loadout[slot]
    if not item is Dictionary or not EquipmentCardOrigin.matching_equipment(card, item):
        return result
    if not item.get("cards", []).has(str(card.get("id", ""))):
        return result
    var effects = item.get("special_effects", [])
    if not effects is Array:
        return result
    for raw in effects:
        if not raw is Dictionary:
            continue
        var effect_id: String = str(raw.get("effect_id", ""))
        if EquipmentSpecialEffectPolicy.EFFECT_IDS.has(effect_id) and not result.has(effect_id):
            result.append(effect_id)
    return result

func _local_generic_effect_ids(card: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for id in _local_effect_ids(card):
        if EquipmentSpecialEffectPolicy.U_EFFECT_IDS.has(id): result.append(id)
    return result

func _local_attribute_effect_ids(card: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for id in _local_effect_ids(card):
        if EquipmentSpecialEffectPolicy.A_EFFECT_IDS.has(id): result.append(id)
    return result

func _local_weapon_effect_ids(card: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for id in _local_effect_ids(card):
        if EquipmentSpecialEffectPolicy.W_EFFECT_IDS.has(id): result.append(id)
    return result

func _local_effect_claim(card: Dictionary, effect_id: String) -> bool:
    var key: String = "%s|%s" % [str(card.get("source_equipment_uid", "")), effect_id]
    if str(card.get("source_equipment_uid", "")) == "":
        return false
    var counters: Dictionary = playtest_stats.get("local_effect_claims", {})
    var limited_to_battle: bool = effect_id in ["U01", "U04", "U08", "U09", "U10", "W06", "W15"]
    var marker: String = "battle" if limited_to_battle else str(turn_number)
    if str(counters.get(key, "")) == marker or (limited_to_battle and counters.has(key)):
        return false
    counters[key] = marker
    playtest_stats["local_effect_claims"] = counters
    _log("DIAG LOCAL_EFFECT %s source=%s card=%s turn=%d" % [effect_id,str(card.get("source_equipment_uid","")),str(card.get("card_instance_uid","")),turn_number])
    return true

# Each attribute's equipment-local gain acceleration (including W14) has a
# global per-turn +1 cap. Store only in existing serialized battle-local stats.
func _local_attribute_gain_extra(source_card: Dictionary, trait_name: String, effect_id: String) -> int:
    if source_card.is_empty() or resolving_card.is_empty(): return 0
    if str(source_card.get("attribute_trait", "")) != trait_name: return 0
    if not _local_effect_ids(source_card).has(effect_id): return 0
    var counts: Dictionary = playtest_stats.get("local_attr_bonus_turn", {})
    if int(counts.get(trait_name, -1)) == turn_number: return 0
    if not _local_effect_claim(source_card,effect_id): return 0
    counts[trait_name] = turn_number
    playtest_stats["local_attr_bonus_turn"] = counts
    _log("Equipment %s: %s gain +1 (global per-trait turn cap)." % [effect_id, trait_name])
    return 1

# Snapshot before paying Cost/consuming resources. Other cards can establish
# the thresholds, but only this equipment's effective cards receive the bonus.
func _local_attribute_pre_use(card: Dictionary, target_enemy_index: int) -> Dictionary:
    var before: Dictionary = {}
    var attr: String = str(card.get("attribute", ""))
    var ids: Array[String] = _local_attribute_effect_ids(card)
    if ids.is_empty(): return before
    var player_name: String = ""
    var enemy_name: String = ""
    match attr:
        "物理": player_name = "剛力"
        "雷": player_name = "帯電"
        "地": player_name = "堅牢"
        "光": player_name = "恩寵"
        "水": enemy_name = "鈍化"
        "闇": enemy_name = "呪印"
        "毒": enemy_name = "猛毒"
    if player_name != "": before["player3"] = get_attribute_trait(player_name) >= 3
    if enemy_name != "":
        if is_enemy_target_valid(target_enemy_index):
            before["enemy3"] = get_enemy_attribute_trait(target_enemy_index,enemy_name) >= 3
        elif str(card.get("target_type", "")) == "all_enemies":
            for i in range(enemies.size()):
                if is_enemy_target_valid(i) and get_enemy_attribute_trait(i,enemy_name)>=3:
                    before["enemy3"] = true
                    break
    return before

func _local_attribute_after_card(card: Dictionary) -> void:
    var ids: Array[String] = _local_attribute_effect_ids(card)
    if ids.is_empty(): return
    var attr: String = str(card.get("attribute", ""))
    var pre: Dictionary = card.get("_local_attribute_before", {})
    var used_attack: bool = str(card.get("card_type", "")) == "attack" and bool(card.get("_local_attribute_attack_executed",false))
    var heal_id: String = ""
    if attr=="光" and ids.has("A12") and bool(pre.get("player3",false)): heal_id="A12"
    if attr=="闇" and ids.has("A14") and used_attack and bool(pre.get("enemy3",false)): heal_id="A14"
    if heal_id!="" and player_hp>0 and player_hp<player_max_hp:
        if int(playtest_stats.get("local_extra_heal_turn",-1))!=turn_number and _local_effect_claim(card,heal_id):
            playtest_stats["local_extra_heal_turn"]=turn_number
            _heal_player(1,"Equipment %s" % heal_id)

func _local_attack_bonus(card: Dictionary, trait_use: Dictionary = {}) -> int:
    var added: int = 0
    for effect_id in _local_effect_ids(card):
        var valid: bool = false
        var bonus: int = 0
        match effect_id:
            "U01":
                valid = true
                bonus = 3
            "U02":
                valid = true
                bonus = 2
            "U03":
                valid = int(card.get("cost", 0)) >= 2
                bonus = 3
            "U06":
                valid = str(campaign_status.get("LastType", "")) == "skill"
                bonus = 2
            "W04":
                valid = str(card.get("weapon", "")) == "レイピア" and bool(trait_use.get("precision", false))
                bonus = 2
            "W09":
                valid = str(card.get("weapon", "")) == "短剣" and int(playtest_stats.get("dagger_attacks_turn", 0)) > 0
                bonus = 2
            "W17":
                valid = str(card.get("weapon", "")) == "刀" and bool(card.get("iai_compatible",false)) and bool(trait_use.get("sheathed", false))
                bonus = 3
            "A02":
                valid = str(card.get("attribute",""))=="物理" and bool(card.get("_local_attribute_before",{}).get("player3",false))
                bonus = 2
            "A06":
                valid = str(card.get("attribute",""))=="水" and bool(card.get("_local_attribute_before",{}).get("enemy3",false))
                bonus = 2
            "A16":
                valid = str(card.get("attribute",""))=="毒" and bool(card.get("_local_attribute_before",{}).get("enemy3",false))
                bonus = 2
        if valid and added < 5 and _local_effect_claim(card, effect_id):
            added = mini(5, added + bonus)
    return added

func _local_skill_block_bonus(card: Dictionary, current_block: int) -> int:
    if current_block <= 0:
        return 0
    var added: int = 0
    for effect_id in _local_effect_ids(card):
        var valid: bool = false
        var bonus: int = 0
        match effect_id:
            "U04":
                valid = true
                bonus = 4
            "U05":
                valid = true
                bonus = 2
            "U07":
                valid = str(campaign_status.get("LastType", "")) == "attack"
                bonus = 2
            "W02":
                valid = str(card.get("weapon", "")) == "片手剣" and str(campaign_status.get("LastType", "")) == "attack"
                bonus = 3
            "A08":
                valid = str(card.get("attribute",""))=="雷" and bool(card.get("_local_attribute_before",{}).get("player3",false))
                bonus = 3
            "A10":
                valid = str(card.get("attribute",""))=="地" and bool(card.get("_local_attribute_before",{}).get("player3",false))
                bonus = 3
        if valid and added < 5 and _local_effect_claim(card, effect_id):
            added = mini(5, added + bonus)
    return added

func _local_extra_draw(card: Dictionary, natural_draw: int) -> int:
    if natural_draw <= 0 or hand.size() + natural_draw >= HAND_LIMIT:
        return 0
    if draw_pile.size() + discard_pile.size() <= natural_draw:
        return 0
    if not _local_generic_effect_ids(card).has("U08"):
        return 0
    # Shared turn cap; a one-battle claim is consumed only on a usable Draw.
    if int(playtest_stats.get("local_extra_draw_turn", -1)) == turn_number:
        return 0
    if _local_effect_claim(card, "U08"):
        playtest_stats["local_extra_draw_turn"] = turn_number
        return 1
    return 0

func _local_after_card(card: Dictionary) -> void:
    var ids: Array[String] = _local_generic_effect_ids(card)
    if ids.has("U09") and int(card.get("_equipment_paid_cost", 0)) >= 2:
        if int(playtest_stats.get("local_extra_mana_turn", -1)) != turn_number and _local_effect_claim(card, "U09"):
            playtest_stats["local_extra_mana_turn"] = turn_number
            current_mana += 1
            _metric_add("mana_gained", 1)
            _log("Equipment U09: Mana +1 (after card use).")
    if ids.has("U10") and str(card.get("card_type", "")) == "power":
        if _local_effect_claim(card, "U10"):
            player_block += 4
            _metric_add("block_gained", 4)
            _log("Equipment U10: Block +4 (Power installation).")

# Post-consumption hooks run once after the actual Attack/weapon effect.
func _local_weapon_post_heavy_bonus(card: Dictionary, trait_use: Dictionary, preceding_local_bonus: int) -> int:
    if not bool(trait_use.get("charge", false)) or str(card.get("weapon", "")) != "大剣":
        return 0
    if not _local_weapon_effect_ids(card).has("W10"):
        return 0
    var allowed: int = maxi(0, 5-preceding_local_bonus)
    if allowed > 0 and _local_effect_claim(card, "W10"):
        return mini(3, allowed)
    return 0

func _local_weapon_set(card: Dictionary, trait_name: String, newly_on: bool) -> void:
    # SET cards which find the trait already ON do not fire a new-ON effect.
    if not newly_on: return
    var id: String = ""
    var bonus_block: int = 0
    match trait_name:
        "流転":
            id="W03"; bonus_block=2
        "精密":
            id="W06"
        "連刃":
            id="W08"; bonus_block=2
        "重撃":
            id="W11"; bonus_block=3
        "魔導":
            id="W13"; bonus_block=2
        "納刀":
            id="W16"; bonus_block=2
    if id=="" or not _local_weapon_effect_ids(card).has(id): return
    if id=="W06":
        # Shared local Draw cap with U08; do not claim when no free hand slot.
        if int(playtest_stats.get("local_extra_draw_turn", -1))==turn_number or hand.size()>=HAND_LIMIT:
            return
        if draw_pile.is_empty() and discard_pile.is_empty(): return
        if _local_effect_claim(card, id):
            playtest_stats["local_extra_draw_turn"] = turn_number
            draw_cards(1)
            _log("Equipment W06: 精密 new ON -> Draw1.")
    elif _local_effect_claim(card, id):
        player_block += bonus_block
        _metric_add("block_gained", bonus_block)
        _log("Equipment %s: %s new ON -> Block +%d." % [id, trait_name, bonus_block])

func _local_weapon_after_card(card: Dictionary) -> void:
    var ids: Array[String] = _local_weapon_effect_ids(card)
    var used: Dictionary = card.get("_local_weapon_trait_use", {})
    var weapon: String = str(card.get("weapon", ""))
    var typ: String = str(card.get("card_type", ""))
    var bonus_block: int = 0
    if weapon=="片手剣" and typ=="attack" and bool(used.get("sword",false)) and ids.has("W01") and _local_effect_claim(card,"W01"):
        bonus_block+=2
    if weapon=="大剣" and typ=="attack" and int(card.get("cost",0))>=2 and ids.has("W12") and _local_effect_claim(card,"W12"):
        bonus_block+=2
    if weapon=="刀" and typ=="attack" and bool(card.get("iai_compatible",false)) and bool(used.get("sheathed",false)) and ids.has("W18") and _local_effect_claim(card,"W18"):
        bonus_block+=3
    if bonus_block>0:
        player_block+=bonus_block
        _metric_add("block_gained",bonus_block)
        _log("Equipment weapon post-card: Block +%d." % bonus_block)
    if weapon=="魔法剣" and bool(used.get("magic",false)) and ids.has("W15"):
        if int(playtest_stats.get("local_extra_mana_turn",-1))!=turn_number and _local_effect_claim(card,"W15"):
            playtest_stats["local_extra_mana_turn"]=turn_number
            current_mana+=1
            _metric_add("mana_gained",1)
            _log("Equipment W15: 魔導 consumed -> Mana +1.")
    # Used-count is updated after local effects; current card is not its own predecessor.
    if typ=="attack" and weapon=="短剣":
        playtest_stats["dagger_attacks_turn"]=int(playtest_stats.get("dagger_attacks_turn",0))+1

func _sum_equipment_effect(effect_type: String) -> int:
    var total = 0
    for effect in equipment_special_effects:
        if str(effect.get("type", "")) == effect_type:
            total += max(0, int(effect.get("amount", 0)))
    return total

func _apply_equipment_battle_start_effects() -> void:
    for effect in equipment_special_effects:
        var effect_type = str(effect.get("type", ""))
        var amount = max(0, int(effect.get("amount", 0)))
        if amount <= 0:
            continue
        if effect_type == "battle_start_weapon_trait":
            var trait_name = str(effect.get("trait", ""))
            if weapon_traits.has(trait_name):
                weapon_traits[trait_name] = true
                _log("Equipment [%s]: %s ON at battle start." % [effect.get("source_item", "Equipment"), trait_name])
        elif effect_type == "battle_start_attribute_trait":
            var trait_name = str(effect.get("trait", ""))
            _log("Equipment [%s]: %s +%d at battle start." % [effect.get("source_item", "Equipment"), trait_name, amount])
            _gain_player_attribute_trait(trait_name, amount)

func get_equipment_special_effect_summary() -> String:
    if equipment_special_effects.is_empty():
        return "none"
    var parts: Array[String] = []
    for effect in equipment_special_effects:
        var effect_type = str(effect.get("type", ""))
        var amount = int(effect.get("amount", 0))
        var trait_name = str(effect.get("trait", ""))
        if trait_name != "":
            if effect_type == "battle_start_weapon_trait":
                parts.append("%s %s ON" % [effect_type, trait_name])
            else:
                parts.append("%s %s +%d" % [effect_type, trait_name, amount])
        else:
            parts.append("%s +%d" % [effect_type, amount])
    return "; ".join(parts)

func _reset_playtest_stats() -> void:
    playtest_stats = {
        "prototype_version": "v1.9.1-bleed-retired",
        "diagnostic_events": [],
        "seed": active_seed,
        "enemy_preset": active_enemy_preset,
        "deck_ids": battle_deck_ids.duplicate(),
        "equipment_loadout": active_equipment_loadout.duplicate(true),
        "equipment_special_effects": equipment_special_effects.duplicate(true),
        "cards_used": 0,
        "card_use_counts": {},
        "mana_spent": 0,
        "mana_gained": 0,
        "cards_drawn": 0,
        "cards_bottomed": 0,
        "cards_discarded_by_effect": 0,
        "cards_salvaged": 0,
        "power_accelerations": 0,
        "damage_dealt": 0,
        "damage_taken": 0,
        "self_hp_paid": 0,
        "block_absorbed": 0,
        "weapon_trait_activations": 0,
        "weapon_trait_sets": 0,
        "attribute_threshold_activations": 0,
        "power_placements": 0,
        "power_trigger_count": 0,
        "block_gained": 0,
        "healing_done": 0,
        "enemy_attack_actions_received": 0,
        "executions": 0,
        "result": "IN_PROGRESS"
    }

func get_playtest_report() -> Dictionary:
    var report: Dictionary = playtest_stats.duplicate(true)
    report["turns"] = turn_number
    report["hp_ledger_expected"] = int(report.get("combat_start_hp", player_max_hp)) + int(report.get("healing_done", 0)) - int(report.get("damage_taken", 0)) - int(report.get("self_hp_paid", 0))
    report["hp_ledger_actual_delta"] = int(report.get("hp_ledger_expected",0)) - player_hp
    report["hp_ledger_balanced"] = int(report["hp_ledger_actual_delta"])==0
    report["player_hp_end"] = player_hp
    report["player_max_hp"] = player_max_hp
    report["combat_over"] = combat_over
    report["victory"] = victory
    report["weapon_traits_end"] = weapon_traits.duplicate(true)
    report["attribute_traits_end"] = attribute_traits.duplicate(true)
    report["continuous_effects_end"] = continuous_effects.duplicate(true)
    report["power_trait_engines_end"] = power_trait_engines.duplicate(true)
    report["power_cards_end"] = power_zone.duplicate(true)
    report["battle_end_reason"] = battle_end_reason
    report["battle_result"] = battle_result.duplicate(true)
    report["block_absorbed_total"] = int(report.get("block_absorbed",0))
    report["power_placements_total"] = int(report.get("power_placements",0))
    report["power_trigger_count_total"] = int(report.get("power_trigger_count",0))
    report["enemy_states_end"] = []
    for enemy in enemies:
        report["enemy_states_end"].append({
            "id": enemy.get("id", "?"),
            "name": enemy.get("name", "Enemy"),
            "order_index": enemy.get("order_index", 0),
            "hp": enemy.get("hp", 0),
            "max_hp": enemy.get("max_hp", 0),
            "block": enemy.get("block", 0),
            "vulnerable": enemy.get("vulnerable", 0),
            "attribute_traits": enemy.get("attribute_traits", {}).duplicate(true)
        })
    return report

func has_battle_result() -> bool:
    return not battle_result.is_empty()

func get_battle_result() -> Dictionary:
    return battle_result.duplicate(true)

func get_next_encounter_payload() -> Dictionary:
    # v1.6 only prepares the handoff. It does not automatically heal, spend Gold,
    # change equipment, or start another encounter.
    if battle_result.is_empty() or str(battle_result.get("result", "")) != "VICTORY":
        return {}
    return {
        "source_battle_result": battle_result.duplicate(true),
        "player_hp_remaining": int(battle_result.get("player_hp_end", 0)),
        "player_max_hp": int(battle_result.get("player_max_hp", player_max_hp)),
        "deck_ids": battle_result.get("deck_ids", []).duplicate(),
        "equipment_loadout": battle_result.get("equipment_loadout", {}).duplicate(true),
        "previous_seed": int(battle_result.get("seed", active_seed)),
        "previous_enemy_preset": str(battle_result.get("enemy_preset", active_enemy_preset))
    }

func _snapshot_enemy_states() -> Array[Dictionary]:
    var states: Array[Dictionary] = []
    for enemy in enemies:
        states.append({
            "id": enemy.get("id", "?"),
            "name": enemy.get("name", "Enemy"),
            "order_index": int(enemy.get("order_index", 0)),
            "hp": int(enemy.get("hp", 0)),
            "max_hp": int(enemy.get("max_hp", 0)),
            "block": int(enemy.get("block", 0)),
            "vulnerable": int(enemy.get("vulnerable", 0)),
            "is_boss": bool(enemy.get("is_boss", false)),
            "attribute_traits": enemy.get("attribute_traits", {}).duplicate(true)
        })
    return states

func _build_battle_result(result_code: String, reason: String) -> Dictionary:
    return {
        "schema_version": 1,
        "prototype_version": "v1.7.0",
        "result": result_code,
        "reason": reason,
        "victory": result_code == "VICTORY",
        "eligible_for_next_encounter": result_code == "VICTORY",
        "turn": turn_number,
        "seed": active_seed,
        "enemy_preset": active_enemy_preset,
        "player_hp_end": max(0, player_hp),
        "player_max_hp": player_max_hp,
        "player_block_end": max(0, player_block),
        "current_mana_end": max(0, current_mana),
        "deck_ids": battle_deck_ids.duplicate(),
        "equipment_loadout": active_equipment_loadout.duplicate(true),
        "equipment_special_effects": equipment_special_effects.duplicate(true),
        "weapon_traits_end": weapon_traits.duplicate(true),
        "attribute_traits_end": attribute_traits.duplicate(true),
        "continuous_effects_end": continuous_effects.duplicate(true),
        "power_trait_engines_end": power_trait_engines.duplicate(true),
        "power_cards_end": power_zone.duplicate(true),
        "enemy_states_end": _snapshot_enemy_states(),
        "telemetry": playtest_stats.duplicate(true)
    }

func _finalize_battle(result_code: String, reason: String) -> void:
    # Centralized, idempotent battle termination. No caller should directly create
    # BattleResult or separately mutate the final result after this point.
    if not battle_result.is_empty():
        return

    combat_over = true
    victory = result_code == "VICTORY"
    battle_end_reason = reason
    if result_code == "DEFEAT":
        player_hp = 0

    # Close any transient interaction state. The actual deck/hand/discard and
    # traits remain intact for diagnostics and are captured in the result.
    resolving_card = {}
    pending_hand_selection = {"mode": "", "remaining": 0}

    if playtest_stats.is_empty():
        _reset_playtest_stats()
    playtest_stats["result"] = result_code
    playtest_stats["end_reason"] = reason
    playtest_stats["turns"] = turn_number
    playtest_stats["player_hp_end"] = max(0, player_hp)
    playtest_stats["player_max_hp"] = player_max_hp

    _log("DIAG BATTLE_END result=%s reason=%s turn=%d hp=%d/%d enemies=%s stats=%s" % [result_code,reason,turn_number,player_hp,player_max_hp,str(_diag_enemies()),str(playtest_stats)])
    var ledger: Dictionary=get_playtest_report()
    _log("DIAG HP_LEDGER start=%d healing=%d incoming=%d self_paid=%d final=%d expected=%d delta=%d" % [int(ledger.get("combat_start_hp",player_max_hp)),int(ledger.get("healing_done",0)),int(ledger.get("damage_taken",0)),int(ledger.get("self_hp_paid",0)),player_hp,int(ledger.get("hp_ledger_expected",0)),int(ledger.get("hp_ledger_actual_delta",0))])
    battle_result = _build_battle_result(result_code, reason)
    campaign_status.clear()
    _log("BATTLE END: %s (%s)" % [result_code, reason])

func get_playtest_summary_text() -> String:
    var report = get_playtest_report()
    var result_text = str(report.get("result", "IN_PROGRESS"))
    var counts: Dictionary = report.get("card_use_counts", {})
    var used_ids: Array = counts.keys()
    used_ids.sort()
    var card_lines: Array[String] = []
    for card_id in used_ids:
        card_lines.append("%s×%d" % [card_id, int(counts.get(card_id, 0))])
    var card_summary = "none" if card_lines.is_empty() else ", ".join(card_lines)
    return "Result %s | Turn %d | Seed %d | Preset %s\nCards used %d | Mana spent %d | Mana gained %d | Drawn %d | Bottom %d | Discard(effect) %d\nDamage dealt %d | Damage taken %d | Block gained %d | Healing %d | Enemy attacks %d | Executions %d\nUsed: %s" % [
        result_text, turn_number, active_seed, active_enemy_preset,
        int(report.get("cards_used", 0)), int(report.get("mana_spent", 0)), int(report.get("mana_gained", 0)), int(report.get("cards_drawn", 0)),
        int(report.get("cards_bottomed", 0)), int(report.get("cards_discarded_by_effect", 0)),
        int(report.get("damage_dealt", 0)), int(report.get("damage_taken", 0)), int(report.get("block_gained", 0)),
        int(report.get("healing_done", 0)), int(report.get("enemy_attack_actions_received", 0)), int(report.get("executions", 0)),
        card_summary
    ]

func _metric_add(key: String, amount: int) -> void:
    if amount>0 and key in ["healing_done","mana_gained","block_gained"]:
        presentation_event.emit({"kind":"resource","resource":key,"amount":amount})
    if playtest_stats.is_empty():
        return
    playtest_stats[key] = int(playtest_stats.get(key, 0)) + amount

func _metric_card_used(card_id: String) -> void:
    _metric_add("cards_used", 1)
    var counts: Dictionary = playtest_stats.get("card_use_counts", {})
    counts[card_id] = int(counts.get(card_id, 0)) + 1
    playtest_stats["card_use_counts"] = counts

func get_enemy_preset_catalog() -> Array[Dictionary]:
    return [
        {"id": "standard_trio", "label": "Standard Trio — Slime / Goblin / Golem"},
        {"id": "slime_duo", "label": "Slime Duo — basic multi-enemy"},
        {"id": "armored_pair", "label": "Armored Pair — Goblin / Golem"},
        {"id": "boss_solo", "label": "Boss Solo — Golem only"}
    ]

func get_active_enemy_preset() -> String:
    return active_enemy_preset

func _create_enemies_from_preset(preset_id: String) -> void:
    match preset_id:
        "slime_duo":
            enemies = [
                _make_slime("E01", "Slime A", 1),
                _make_slime("E02", "Slime B", 2)
            ]
        "armored_pair":
            enemies = [
                _make_goblin("E01", "Goblin", 1),
                _make_golem("E02", "Golem [Boss Dummy]", 2)
            ]
        "boss_solo":
            enemies = [_make_golem("E01", "Golem [Boss Dummy]", 1)]
        _:
            active_enemy_preset = "standard_trio"
            enemies = [
                _make_slime("E01", "Slime", 1),
                _make_goblin("E02", "Goblin", 2),
                _make_golem("E03", "Golem [Boss Dummy]", 3)
            ]

func _base_enemy(enemy_id: String, enemy_name: String, order_index: int, max_hp: int, initial_block: int, is_boss: bool) -> Dictionary:
    return {
        "id": enemy_id,
        "name": enemy_name,
        "order_index": order_index,
        "max_hp": max_hp,
        "hp": max_hp,
        "block": initial_block,
        "vulnerable": 0,
        "attribute_traits": {"爆発": 0, "鈍化": 0, "呪印": 0, "猛毒": 0},
        "is_boss": is_boss,
        "intent_index": 0,
        "intents": []
    }

func _make_slime(enemy_id: String, enemy_name: String, order_index: int) -> Dictionary:
    var enemy = _base_enemy(enemy_id, enemy_name, order_index, 24, 0, false)
    enemy["intents"] = [
        {"label": "Attack 4", "actions": [{"type": "attack", "damage": 4, "hits": 1}]},
        {"label": "Attack 2 × 2", "actions": [{"type": "attack", "damage": 2, "hits": 2}]}
    ]
    return enemy

func _make_goblin(enemy_id: String, enemy_name: String, order_index: int) -> Dictionary:
    var enemy = _base_enemy(enemy_id, enemy_name, order_index, 30, 0, false)
    enemy["intents"] = [
        {"label": "Attack 3 × 2", "actions": [{"type": "attack", "damage": 3, "hits": 2}]},
        {"label": "Attack 7", "actions": [{"type": "attack", "damage": 7, "hits": 1}]}
    ]
    return enemy

func _make_golem(enemy_id: String, enemy_name: String, order_index: int) -> Dictionary:
    var enemy = _base_enemy(enemy_id, enemy_name, order_index, 42, 6, true)
    enemy["intents"] = [
        {
            "label": "Guard 6 → Attack 5",
            "actions": [
                {"type": "block", "amount": 6},
                {"type": "attack", "damage": 5, "hits": 1}
            ]
        },
        {"label": "Attack 8", "actions": [{"type": "attack", "damage": 8, "hits": 1}]}
    ]
    return enemy

func _shuffle_with_battle_rng(cards_to_shuffle: Array) -> void:
    # Fisher-Yates using the battle-local RNG. This keeps battle reproduction independent
    # from unrelated global random calls in the UI or future systems.
    for i in range(cards_to_shuffle.size() - 1, 0, -1):
        var j = battle_rng.randi_range(0, i)
        var tmp = cards_to_shuffle[i]
        cards_to_shuffle[i] = cards_to_shuffle[j]
        cards_to_shuffle[j] = tmp

func get_active_seed() -> int:
    return active_seed

func get_enemy_count() -> int:
    return enemies.size()

func get_official_card_count() -> int:
    return database.get_official_card_count()

func get_power_engine_summary() -> String:
    var ids: Array[String] = []
    for engine in power_trait_engines:
        ids.append(str(engine.get("id", "?")))
    return "属性Power %d / %s" % [power_trait_engines.size(), ", ".join(ids)]

func get_continuous_effect_summary() -> String:
    var active: Array[String] = []
    for effect_name in continuous_effects.keys():
        var value: int = int(continuous_effects[effect_name])
        if value > 0:
            active.append("%s=%d" % [effect_name, value])
    if not power_trait_engines.is_empty():
        active.append(get_power_engine_summary())
    return "none" if active.is_empty() else ", ".join(active)

func get_enemy(enemy_index: int) -> Dictionary:
    if enemy_index < 0 or enemy_index >= enemies.size():
        return {}
    return enemies[enemy_index]

func get_enemy_intent(enemy_index: int) -> Dictionary:
    var enemy = get_enemy(enemy_index)
    if enemy.is_empty() or int(enemy.get("hp", 0)) <= 0:
        return {}
    if enemy.has("r1_data"):
        var visible_status: Dictionary=region1_player_status.duplicate(true)
        visible_status.merge(campaign_status,true)
        return RegionEnemyCatalog.new().intent(enemy,visible_status)
    var intents: Array = enemy.get("intents", [])
    if intents.is_empty():
        return {}
    var idx: int = int(enemy.get("intent_index", 0)) % intents.size()
    return intents[idx]

func is_enemy_target_valid(enemy_index: int) -> bool:
    if combat_over:
        return false
    var enemy = get_enemy(enemy_index)
    return not enemy.is_empty() and int(enemy.get("hp", 0)) > 0

func get_effective_target_type(hand_index: int) -> String:
    if hand_index < 0 or hand_index >= hand.size():
        return "none"
    var card: Dictionary = hand[hand_index]
    var base_target: String = str(card.get("target_type", "none"))
    if base_target == "enemy":
        return "enemy"

    # Dynamic target requirement: a CONSUME Sword defense uses 流転ON to deal bonus damage.
    if (
        card.get("weapon", "") == "片手剣"
        and str(card.get("weapon_trait_action", "NEUTRAL")) == "CONSUME"
        and int(card.get("base_block", 0)) > 0
        and bool(weapon_traits.get("流転", false))
    ):
        return "enemy"
    return base_target

func get_effective_cost(hand_index: int) -> int:
    if hand_index < 0 or hand_index >= hand.size():
        return 999
    var context = _build_cost_context(hand[hand_index])
    return int(context.get("effective_cost", 999))

func get_cost_preview_text(hand_index: int) -> String:
    if hand_index < 0 or hand_index >= hand.size():
        return "Cost ?"
    var card: Dictionary = hand[hand_index]
    var printed_cost: int = int(card.get("cost", 0))
    var effective_cost: int = get_effective_cost(hand_index)
    if effective_cost != printed_cost:
        return "Cost %d → %d" % [printed_cost, effective_cost]
    return "Cost %d" % printed_cost

func _build_cost_context(card: Dictionary) -> Dictionary:
    var printed_cost: int = int(card.get("cost", 0))
    var cost: int = printed_cost
    var use_sheathed = false

    # Official order: Cost0 conversion -> Cost reduction -> minimum 0.
    # 納刀 is only reserved here. It is consumed after use confirmation / payment.
    if (
        card.get("weapon", "") == "刀"
        and str(card.get("weapon_trait_action", "NEUTRAL")) == "CONSUME"
        and bool(card.get("iai_compatible", false))
        and bool(weapon_traits.get("納刀", false))
    ):
        cost = 0
        use_sheathed = true

    # 疾風 is applied only if the card is still above Cost0. One charge maximum per card.
    var use_swift = false
    if cost > 0 and swift_cost_reduction_charges > 0:
        cost -= 1
        use_swift = true

    if cost > 0:
        var generic_reduction: int = int(card.get("temporary_cost_reduction", 0))
        cost -= generic_reduction

    cost = max(0, cost)
    return {
        "printed_cost": printed_cost,
        "effective_cost": cost,
        "use_sheathed": use_sheathed,
        "use_swift": use_swift
    }

func is_hand_selection_active() -> bool:
    return str(pending_hand_selection.get("mode", "")) != ""

func get_hand_selection_prompt() -> String:
    var mode: String = str(pending_hand_selection.get("mode", ""))
    var remaining: int = int(pending_hand_selection.get("remaining", 0))
    if mode == "bottom":
        return "Select %d hand card(s) to put on the bottom of the draw pile." % remaining
    if mode == "discard":
        return "Select %d hand card(s) to discard." % remaining
    if mode == "salvage":
        return "捨て札から回収するカードを1枚選んでください。"
    return ""

func can_use_card(hand_index: int) -> bool:
    if combat_over or is_hand_selection_active() or not resolving_card.is_empty():
        return false
    if hand_index < 0 or hand_index >= hand.size():
        return false

    var card: Dictionary = hand[hand_index]
    if current_mana < get_effective_cost(hand_index):
        return false

    var condition_met = _is_card_condition_met(card, -1)
    var select_count: int = int(card.get("select_count", 0))
    var draw_count: int = int(card.get("draw_count", 0))
    if condition_met and card.has("conditional_select_count"):
        select_count = int(card.get("conditional_select_count", select_count))
        draw_count = int(card.get("conditional_draw_count", draw_count))
    if select_count > 0:
        var other_hand_count: int = hand.size() - 1
        var slots_after_use: int = HAND_LIMIT - other_hand_count
        var drawable_cards: int = draw_pile.size() + discard_pile.size()
        var projected_draw: int = min(draw_count, min(slots_after_use, drawable_cards))
        if other_hand_count + projected_draw < select_count:
            return false

    return true

func use_card(hand_index: int, target_enemy_index: int = -1) -> bool:
    if not can_use_card(hand_index):
        _log("Card cannot be used: invalid state, insufficient Mana, or selection requirement cannot be met.")
        return false

    var card: Dictionary = hand[hand_index]
    var target_type: String = get_effective_target_type(hand_index)
    if target_type == "enemy" and not is_enemy_target_valid(target_enemy_index):
        _log("Card cannot be used: invalid enemy target.")
        return false

    # Step 2: lock thresholds before this card can generate stacks.
    var local_attr_before: Dictionary = _local_attribute_pre_use(card,target_enemy_index)
    var condition_met = _is_card_condition_met(card, target_enemy_index)
    var strength_stage_before: int = int(floor(float(attribute_traits.get("剛力", 0)) / 3.0))

    # Step 3: calculate effective Cost without consuming resources.
    var cost_context = _build_cost_context(card)
    var effective_cost: int = int(cost_context.get("effective_cost", int(card.get("cost", 0))))

    _log("DIAG CARD_BEFORE id=%s target=%d cost=%d mana=%d hp=%d/%d block=%d target_before=%s weapon=%s attribute=%s" % [str(card.get("id","?")),target_enemy_index,effective_cost,current_mana,player_hp,player_max_hp,player_block,str(enemies[target_enemy_index]) if target_enemy_index>=0 and target_enemy_index<enemies.size() else "none",str(weapon_traits),str(attribute_traits)])
    _log("DIAG CARD_ORIGIN id=%s instance=%s equipment=%s slot=%s" % [str(card.get("id", "?")),str(card.get("card_instance_uid", "legacy")),str(card.get("source_equipment_uid", "none")),str(card.get("source_slot", "none"))])
    hand.remove_at(hand_index)
    resolving_card = card
    resolving_card["_equipment_paid_cost"] = effective_cost
    resolving_card["_local_attribute_before"] = local_attr_before

    # Step 4: pay Cost.
    current_mana -= effective_cost
    _metric_card_used(str(card.get("id", "?")))
    _metric_add("mana_spent", effective_cost)
    if effective_cost != int(card.get("cost", 0)):
        _log("Use %s (Cost %d → %d)." % [card.get("id", "?"), int(card.get("cost", 0)), effective_cost])
    else:
        _log("Use %s (Cost %d)." % [card.get("id", "?"), effective_cost])

    if bool(cost_context.get("use_swift", false)):
        swift_cost_reduction_charges = max(0, swift_cost_reduction_charges - 1)
        # A20 only triggers for an actually-consumed 疾風 discount on Wind.
        if str(resolving_card.get("attribute",""))=="風" and _local_attribute_effect_ids(resolving_card).has("A20") and _local_effect_claim(resolving_card,"A20"):
            player_block+=3
            _metric_add("block_gained",3)
            _log("Equipment A20: 疾風 reduction spent -> Block +3.")
        _log("疾風: Cost -1 charge consumed (remaining %d)." % swift_cost_reduction_charges)
        var swift_draw: int = int(continuous_effects.get("wind_first_swift_card_draw", 0))
        if swift_draw > 0 and not first_swift_engine_used:
            first_swift_engine_used = true
            _log("Wind engine: first 疾風-reduced card this turn → Draw %d." % swift_draw)
            draw_cards(swift_draw)

    # Store locked pre-use state so later steps never re-evaluate against gains from this same card.
    resolving_card["_resolved_target_enemy_index"] = target_enemy_index
    resolving_card["_condition_met"] = condition_met

    # Step 5: weapon-trait activation and consumption.
    var trait_use = _consume_weapon_trait_for_card(card, cost_context)
    for used_trait in trait_use:
        if bool(trait_use[used_trait]):
            _metric_add("weapon_trait_activations",1)
            break
    resolving_card["_local_weapon_trait_use"] = trait_use.duplicate(true)
    if bool(trait_use.get("magic", false)):
        resolving_card["_weapon_trait_magic_used"] = true

    # Step 6: player-side card values.
    var damage: int = int(card.get("base_damage", 0))
    var block: int = int(card.get("base_block", 0))
    if condition_met:
        damage += int(card.get("condition_damage_bonus", 0))
        block += int(card.get("condition_block_bonus", 0))

    var stage_block_trait: String = str(card.get("stage_block_trait", ""))
    var stage_block_bonus: int = int(card.get("stage_block_bonus", 0))
    if stage_block_trait != "" and stage_block_bonus > 0:
        var stage_count = get_attribute_stage(stage_block_trait)
        if stage_count > 0:
            block += stage_count * stage_block_bonus
            _log("%s individuality: Block +%d." % [stage_block_trait, stage_count * stage_block_bonus])

    # Physical finisher individuality: +3 damage per pre-use 剛力 stage.
    var strength_stage_bonus: int = int(card.get("strength_stage_damage_bonus", 0))
    if strength_stage_bonus > 0:
        damage += strength_stage_before * strength_stage_bonus
        if strength_stage_before > 0:
            _log("Physical finisher: 剛力 stage bonus +%d." % (strength_stage_before * strength_stage_bonus))

    # 剛力's global attribute effect applies once per Attack card.
    if card.get("card_type", "") == "attack":
        damage += strength_stage_before
        if int(region1_support.get("attack",0)) > 0:
            damage += int(region1_support.attack)
            region1_support.erase("attack")
        var first_attack_bonus: int = int(continuous_effects.get("physical_first_attack_damage", 0))
        if first_attack_bonus > 0 and not first_attack_engine_used:
            first_attack_engine_used = true
            damage += first_attack_bonus
            _log("Physical engine: first Attack this turn +%d damage." % first_attack_bonus)

    # Local equipment bonuses affect only this equipment's card instance.
    # Clamp direct damage and Block additions separately to +5 per card.
    var direct_local_damage_bonus: int = 0
    if str(card.get("card_type", "")) == "attack":
        direct_local_damage_bonus = _local_attack_bonus(card, trait_use)
        damage += direct_local_damage_bonus
    elif str(card.get("card_type", "")) == "skill":
        block += _local_skill_block_bonus(card, block)

    # 大剣・重撃: after fixed additions, before enemy-side multipliers.
    if bool(trait_use.get("charge", false)) and damage > 0:
        damage = int(floor(float(damage) * 1.5))
        _log("重撃: attack value becomes %d." % damage)
        var post_bonus: int = _local_weapon_post_heavy_bonus(card,trait_use,direct_local_damage_bonus)
        if post_bonus>0:
            damage += post_bonus
            _log("Equipment W10: 重撃 multiplier applied, damage +%d." % post_bonus)

    # 片手剣・流転 conversion uses the card-side calculated value before enemy multipliers.
    var sword_bonus_block = 0
    var sword_bonus_damage = 0
    if bool(trait_use.get("sword", false)):
        if card.get("card_type", "") == "attack":
            sword_bonus_block = int(floor(float(damage) * 0.5))
        elif block > 0:
            sword_bonus_damage = int(floor(float(block) * 0.5))

    # Step 7-8: main effect and Attack-after processing.
    if damage > 0:
        if is_enemy_target_valid(target_enemy_index) or str(card.get("target_type",""))=="all_enemies":
            resolving_card["_local_attribute_attack_executed"] = true
        _resolve_attack(card, target_enemy_index, damage, trait_use)
        if int(card.get("step9_after_attack_enemy_trait_gain", 0)) > 0 and is_enemy_target_valid(target_enemy_index):
            _gain_enemy_attribute_trait(target_enemy_index, str(card.get("attribute_trait", "")), int(card.get("step9_after_attack_enemy_trait_gain", 0)), resolving_card)
        if condition_met and int(card.get("condition_heal_after_attack", 0)) > 0:
            _heal_player(int(card.get("condition_heal_after_attack", 0)), "Attribute individuality")
    if block > 0:
        player_block += block
        _metric_add("block_gained", block)
        _log("Gain Block %d." % block)

    if sword_bonus_block > 0:
        player_block += sword_bonus_block
        _metric_add("block_gained", sword_bonus_block)
        _log("流転: gain bonus Block %d." % sword_bonus_block)
    if sword_bonus_damage > 0:
        _deal_damage_to_enemy(target_enemy_index, sword_bonus_damage, false)
        _log("流転: deal bonus damage %d." % sword_bonus_damage)

    # Step 9 card text: conditional Heal / Draw / hand action.
    if condition_met and int(card.get("condition_heal_bonus", 0)) > 0:
        _heal_player(int(card.get("condition_heal_bonus", 0)), "Attribute support")

    var draw_count: int = int(card.get("draw_count", 0))
    var hand_action: String = str(card.get("hand_action", ""))
    var select_count: int = int(card.get("select_count", 0))
    if condition_met and card.has("conditional_draw_count"):
        draw_count = int(card.get("conditional_draw_count", draw_count))
        hand_action = str(card.get("conditional_hand_action", hand_action))
        select_count = int(card.get("conditional_select_count", select_count))
    if condition_met:
        draw_count += int(card.get("condition_draw_bonus", 0))

    var salvage_code: String = str(card.get("step9_salvage", ""))
    if salvage_code == "physical_attack_if_strength_3" and condition_met:
        if _begin_salvage(true, "finish"):
            return true
        draw_count += 1 # fallback when no eligible target or hand space
    elif salvage_code == "any_before_draw_bottom":
        if _begin_salvage(false, "C074_draw_bottom"):
            return true
        draw_count = 2 # no eligible discarded card: original Draw2 -> Bottom1

    if draw_count > 0:
        draw_count += _local_extra_draw(card, draw_count)
        draw_cards(draw_count)

    if hand_action != "" and select_count > 0:
        pending_hand_selection = {"mode": hand_action, "remaining": select_count}
        _log("Hand selection required: %s × %d." % [hand_action, select_count])
        return true

    _finish_resolving_card()
    return true

func _is_card_condition_met(card: Dictionary, target_enemy_index: int = -1) -> bool:
    var trait_name: String = str(card.get("condition_trait", ""))
    var threshold: int = int(card.get("condition_threshold", 0))
    if trait_name == "" or threshold <= 0:
        return false
    if attribute_traits.has(trait_name):
        return int(attribute_traits.get(trait_name, 0)) >= threshold
    if weapon_traits.has(trait_name):
        return bool(weapon_traits.get(trait_name, false))
    if target_enemy_index >= 0 and target_enemy_index < enemies.size():
        var enemy: Dictionary = enemies[target_enemy_index]
        if enemy.has(trait_name):
            return int(enemy.get(trait_name, 0)) >= threshold
        var enemy_traits: Dictionary = enemy.get("attribute_traits", {})
        if enemy_traits.has(trait_name):
            return int(enemy_traits.get(trait_name, 0)) >= threshold
    return false

func _consume_weapon_trait_for_card(card: Dictionary, cost_context: Dictionary) -> Dictionary:
    var result = {
        "sword": false,
        "precision": false,
        "flurry": false,
        "charge": false,
        "magic": false,
        "sheathed": false
    }
    if str(card.get("weapon_trait_action", "NEUTRAL")) != "CONSUME":
        return result

    var weapon: String = str(card.get("weapon", ""))
    var is_attack: bool = str(card.get("card_type", "")) == "attack"

    if bool(cost_context.get("use_sheathed", false)):
        weapon_traits["納刀"] = false
        result["sheathed"] = true
        _log("納刀ON consumed: Iai Cost0 confirmed.")
    elif weapon == "片手剣" and bool(weapon_traits.get("流転", false)):
        weapon_traits["流転"] = false
        result["sword"] = true
        _log("流転ON consumed.")
    elif weapon == "レイピア" and is_attack and bool(weapon_traits.get("精密", false)):
        weapon_traits["精密"] = false
        result["precision"] = true
        _log("精密ON consumed.")
    elif weapon == "短剣" and is_attack and bool(weapon_traits.get("連刃", false)):
        weapon_traits["連刃"] = false
        result["flurry"] = true
        _log("連刃ON consumed.")
    elif weapon == "大剣" and is_attack and bool(weapon_traits.get("重撃", false)):
        weapon_traits["重撃"] = false
        result["charge"] = true
        _log("重撃ON consumed.")
    elif (
        weapon == "魔法剣"
        and bool(weapon_traits.get("魔導", false))
        and int(card.get("attribute_trait_gain", 0)) > 0
    ):
        weapon_traits["魔導"] = false
        result["magic"] = true
        _log("魔導ON consumed: this card's attribute gain +2.")

    return result

func _resolve_attack(card: Dictionary, target_enemy_index: int, player_side_damage: int, trait_use: Dictionary) -> void:
    if not is_enemy_target_valid(target_enemy_index):
        return

    var enemy: Dictionary = enemies[target_enemy_index]
    var curse_stage_before = get_enemy_attribute_stage(target_enemy_index, "呪印")
    var had_vulnerable = int(enemy.get("vulnerable", 0)) > 0
    var precision_used = bool(trait_use.get("precision", false))
    var precision_ignores_block = precision_used and int(enemy.get("block", 0)) > 0
    var apply_vulnerable_after = false

    if precision_used:
        if precision_ignores_block:
            _log("精密: target has Block → this Rapier Attack ignores Block.")
        else:
            apply_vulnerable_after = true
            _log("精密: target has no Block → 脆弱1 will be applied after the Attack.")

    # Enemy-side multiplier applies to the whole Attack. It is removed only after all hits.
    var first_hit_damage = player_side_damage
    if str(card.get("card_type",""))=="attack":
        if int(campaign_status.get("Weak",0))+int(campaign_status.get("Frozen",0))>0:
            first_hit_damage=int(floor(float(first_hit_damage)*0.75))
        if int(campaign_status.get("Frozen",0))>0: campaign_status.Frozen=0
    if had_vulnerable:
        first_hit_damage = int(floor(float(first_hit_damage) * VULNERABLE_MULTIPLIER))
        _log("脆弱: Attack damage ×1.25 → %d." % first_hit_damage)

    var hit_values: Array[int] = [first_hit_damage]
    if bool(trait_use.get("flurry", false)):
        var second_hit: int = first_hit_damage
        if _local_weapon_effect_ids(card).has("W07") and _local_effect_claim(card,"W07"):
            second_hit += 2
            _log("Equipment W07: only the second 連刃 hit +2.")
        hit_values.append(second_hit)
        _log("連刃: second hit = %d (100%% of first-hit pre-Block final value)." % second_hit)

    for hit_index in range(hit_values.size()):
        if not is_enemy_target_valid(target_enemy_index):
            break
        _log("  Player Hit %d/%d" % [hit_index + 1, hit_values.size()])
        _deal_damage_to_enemy(target_enemy_index, hit_values[hit_index], precision_ignores_block)

    # Old vulnerability is consumed by the whole Attack, not by the first hit.
    if had_vulnerable:
        enemy["vulnerable"] = 0
        _log("Existing 脆弱 consumed after all Attack hits.")

    # Precision / Rapier individuality applies new vulnerability after the Attack.
    if apply_vulnerable_after and is_enemy_target_valid(target_enemy_index):
        enemy["vulnerable"] = 1
        _log("Apply 脆弱1 after the Rapier Attack.")
        if _local_weapon_effect_ids(card).has("W05") and _local_effect_claim(card,"W05"):
            player_block += 2
            _metric_add("block_gained",2)
            _log("Equipment W05: newly applied 脆弱 -> Block +2.")

    # 呪印: once per player turn, the first Attack against a cursed enemy drains HP.
    # The pre-Attack stage is locked, so the heal still occurs if the target was defeated.
    if curse_stage_before > 0 and not curse_lifesteal_used:
        curse_lifesteal_used = true
        var heal_amount = curse_stage_before * 2 + int(continuous_effects.get("dark_lifesteal_bonus", 0))
        _heal_player(heal_amount, "呪印")

    # 納刀 Iai finisher execution check occurs after all Attack hits.
    if bool(trait_use.get("sheathed", false)) and bool(card.get("execution_on_sheathed", false)):
        _try_execution(target_enemy_index)

func _try_execution(enemy_index: int) -> void:
    if not is_enemy_target_valid(enemy_index):
        return
    var enemy: Dictionary = enemies[enemy_index]
    var hp: int = int(enemy.get("hp", 0))
    var max_hp: int = max(1, int(enemy.get("max_hp", 1)))
    if float(hp) <= float(max_hp) * 0.10:
        enemy["hp"] = 0
        CampaignCombat.phase_if_needed(self,enemy)
        _metric_add("executions", 1)
        presentation_event.emit({"kind":"execution","enemy":enemy_index,"hp_loss":hp})
        var boss_prefix = "Boss " if bool(enemy.get("is_boss", false)) else ""
        _log("処刑: %s#%d %s defeated at %d/%d HP." % [boss_prefix, enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy"), hp, max_hp])

func _heal_player(amount: int, source_name: String) -> void:
    if amount <= 0:
        return
    var old_hp = player_hp
    player_hp = min(player_max_hp, player_hp + amount)
    var actual_heal = player_hp - old_hp
    _metric_add("healing_done", actual_heal)
    _log("%s: Heal %d (actual %d)." % [source_name, amount, actual_heal])

func _register_continuous_effect(card: Dictionary) -> void:
    # STEP9: common attribute accelerator (+1 once/turn for each installed instance).
    # Installation happens after this card's own trait, so it cannot boost itself.
    if bool(card.get("step9_power_trait_engine", false)):
        power_trait_engines.append({
            "id": str(card.get("id", "")),
            "trait": str(card.get("attribute_trait", "")),
            "last_used_turn": -1
        })
        _log("Power engine installed: %s (%s +1 on first gain each turn)." % [card.get("id", "?"), card.get("attribute_trait", "?")])
        return
    var effect_name: String = str(card.get("continuous_effect", ""))
    var value: int = int(card.get("continuous_value", 0))
    if effect_name == "" or value <= 0:
        return
    if not continuous_effects.has(effect_name):
        continuous_effects[effect_name] = 0
    continuous_effects[effect_name] = int(continuous_effects[effect_name]) + value
    _log("Continuous registered: %s +%d (total %d)." % [effect_name, value, continuous_effects[effect_name]])

func select_hand_for_pending(hand_index: int) -> bool:
    if not is_hand_selection_active():
        return false
    if hand_index < 0 or hand_index >= hand.size():
        return false

    var selected: Dictionary = hand[hand_index]
    hand.remove_at(hand_index)

    var mode: String = str(pending_hand_selection.get("mode", ""))
    if mode == "discard":
        discard_pile.append(selected)
        _metric_add("cards_discarded_by_effect", 1)
        presentation_event.emit({"kind":"discard","id":str(selected.get("id",""))})
        _log("Discard %s." % selected.get("id", "?"))
    elif mode == "bottom":
        draw_pile.push_front(selected)
        _metric_add("cards_bottomed", 1)
        presentation_event.emit({"kind":"bottom","id":str(selected.get("id",""))})
        _log("Bottom %s." % selected.get("id", "?"))
    else:
        return false

    pending_hand_selection["remaining"] = int(pending_hand_selection.get("remaining", 1)) - 1
    if int(pending_hand_selection["remaining"]) <= 0:
        pending_hand_selection = {"mode": "", "remaining": 0}
        _finish_resolving_card()
    return true

func _finish_resolving_card() -> void:
    if resolving_card.is_empty():
        return

    # Step 10: SET cards turn their weapon trait ON. SET never consumes an existing ON state.
    var weapon_trait_name: String = str(resolving_card.get("weapon_trait", ""))
    var weapon_action: String = str(resolving_card.get("weapon_trait_action", "NEUTRAL"))
    if weapon_action == "SET" and weapon_trait_name != "":
        var was_on: bool = bool(weapon_traits.get(weapon_trait_name, false))
        weapon_traits[weapon_trait_name] = true
        _metric_add("weapon_trait_sets",0 if was_on else 1)
        _log("%s remains ON." % weapon_trait_name if was_on else "%s set ON." % weapon_trait_name)
        _local_weapon_set(resolving_card,weapon_trait_name,not was_on)

    # Step 11-12: attribute-trait gain + threshold processing.
    # 魔導 only boosts a CONSUME card that actually consumed an already-ON 魔導 at Step 5.
    # A SET Magic Sword card never consumes the 魔導 it just established on the same card.
    var attr_trait_name: String = str(resolving_card.get("attribute_trait", ""))
    var base_attr_gain: int = int(resolving_card.get("attribute_trait_gain", 0))
    if bool(resolving_card.get("_condition_met", false)):
        base_attr_gain += int(resolving_card.get("extra_attribute_gain_on_condition", 0))
    if base_attr_gain > 0 and attr_trait_name != "" and int(resolving_card.get("step9_after_attack_enemy_trait_gain", 0)) <= 0:
        var magic_bonus: int = 2 if bool(resolving_card.get("_weapon_trait_magic_used", false)) else 0
        if magic_bonus > 0:
            _log("魔導ON: %s gain +%d." % [attr_trait_name, magic_bonus])

        var total_attr_gain: int = base_attr_gain + magic_bonus
        if magic_bonus>0 and str(resolving_card.get("weapon",""))=="魔法剣" and _local_weapon_effect_ids(resolving_card).has("W14"):
            total_attr_gain += _local_attribute_gain_extra(resolving_card,attr_trait_name,"W14")
        var target_enemy_index: int = int(resolving_card.get("_resolved_target_enemy_index", -1))
        _gain_attribute_trait(attr_trait_name, total_attr_gain, target_enemy_index, resolving_card)

    # C108: after 魔珠 threshold: optional discard-pile choice (no double Draw1).
    if bool(resolving_card.get("_step9_magic_threshold_salvage", false)):
        resolving_card.erase("_step9_magic_threshold_salvage")
        if _begin_salvage(false, "post_attribute"):
            return
        draw_cards(1) # fallback if no target or hand full
    _complete_resolving_card()

func _complete_resolving_card() -> void:
    campaign_status["LastType"]=str(resolving_card.get("card_type",""))
    if str(resolving_card.get("card_type", "")) == "attack":
        var target: int = int(resolving_card.get("_resolved_target_enemy_index",-1))
        var targets: Array = range(enemies.size()) if str(resolving_card.get("target_type", "")) == "all_enemies" else [target]
        for enemy_index in targets:
            if is_enemy_target_valid(int(enemy_index)):
                var thorns: int = int(enemies[int(enemy_index)].get("r1_status",{}).get("Thorns",0))
                if thorns > 0: _take_player_damage(thorns)
    # Once per card, and after its actual attacks/trait gains.
    _local_attribute_after_card(resolving_card)
    # Generic local effects resolve once per card use, not on later Power ticks.
    _local_after_card(resolving_card)
    _local_weapon_after_card(resolving_card)
    # Step 13: register persistent effect only after its own trait gain/thresholds.
    _register_continuous_effect(resolving_card)
    if str(resolving_card.get("card_type", "")) == "power":
        _metric_add("power_placements",1)
        power_zone.append(resolving_card)
        _log("Power設置完了：%s は山札・捨て札に戻らない。" % resolving_card.get("id", "?"))
    else:
        discard_pile.append(resolving_card)
    _log("DIAG CARD_AFTER id=%s hp=%d/%d mana=%d block=%d weapon=%s attribute=%s enemies=%s hand=%s" % [str(resolving_card.get("id","?")),player_hp,player_max_hp,current_mana,player_block,str(weapon_traits),str(attribute_traits),str(_diag_enemies()),str(_diag_hand())])
    resolving_card = {}
    if player_hp <= 0:
        _finalize_battle("DEFEAT", "player_hp_zero")
        return
    _check_victory()

func get_attribute_trait(trait_name: String) -> int:
    return int(attribute_traits.get(trait_name, 0))

func get_attribute_stage(trait_name: String) -> int:
    return TraitSystem.stage(get_attribute_trait(trait_name))

func get_enemy_attribute_trait(enemy_index: int, trait_name: String) -> int:
    var enemy = get_enemy(enemy_index)
    if enemy.is_empty():
        return 0
    var enemy_traits: Dictionary = enemy.get("attribute_traits", {})
    return int(enemy_traits.get(trait_name, 0))

func get_enemy_attribute_stage(enemy_index: int, trait_name: String) -> int:
    return TraitSystem.stage(get_enemy_attribute_trait(enemy_index, trait_name))

func _power_gain_modifiers(trait_name: String, amount: int, source_card: Dictionary) -> Dictionary:
    var fired: Array[String] = []
    var total: int = amount
    # These are PLAYER card gains, not monster moves or global idle effects.
    if amount <= 0 or source_card.is_empty() or resolving_card.is_empty():
        return {"total": total, "triggered": fired}
    for i in range(power_trait_engines.size()):
        var engine: Dictionary = power_trait_engines[i]
        if str(engine.get("trait", "")) != trait_name or int(engine.get("last_used_turn", -1)) == turn_number:
            continue
        power_trait_engines[i]["last_used_turn"] = turn_number
        total += 1
        fired.append(str(engine.get("id", "")))
    if total > amount:
        _metric_add("power_trigger_count", fired.size())
        _metric_add("power_accelerations", total - amount)
        _log("Power accelerator: %s +%d (base %d -> %d)." % [trait_name, total - amount, amount, total])
    return {"total": total, "triggered": fired}

func _rearm_weapon_after_power(triggers: Array) -> void:
    # Never retroactively affects the card that was already confirmed and resolved.
    for item in triggers:
        var card_id: String = str(item)
        if card_id == "C028" and not bool(weapon_traits.get("精密", false)):
            weapon_traits["精密"] = true
            _log("C028 engine: 精密 set ON again.")
        elif card_id == "C106" and not bool(weapon_traits.get("魔導", false)):
            weapon_traits["魔導"] = true
            _log("C106 engine: 魔導 set ON again.")

func _valid_salvage_indices(physical_attack_only: bool = false) -> Array[int]:
    var result: Array[int] = []
    for i in range(discard_pile.size()):
        var c: Dictionary = discard_pile[i]
        if physical_attack_only and not (str(c.get("attribute", "")) == "物理" and str(c.get("card_type", "")) == "attack"):
            continue
        result.append(i)
    return result

func is_salvage_selection_active() -> bool:
    return str(pending_hand_selection.get("mode", "")) == "salvage"

func get_salvage_selectable_indices() -> Array[int]:
    if not is_salvage_selection_active():
        return []
    return _valid_salvage_indices(bool(pending_hand_selection.get("physical_only", false)))

func _begin_salvage(physical_attack_only: bool, continuation: String) -> bool:
    if hand.size() >= HAND_LIMIT:
        _notice("手札上限：サルベージ不可")
        return false
    if _valid_salvage_indices(physical_attack_only).is_empty():
        return false
    pending_hand_selection = {"mode": "salvage", "remaining": 1,
                              "physical_only": physical_attack_only, "continue": continuation}
    _log("サルベージ：捨て札の対象カード1枚を選択してください。")
    return true

func select_discard_for_pending(discard_index: int) -> bool:
    if not is_salvage_selection_active() or hand.size() >= HAND_LIMIT:
        return false
    if not get_salvage_selectable_indices().has(discard_index):
        return false
    var rescued: Dictionary = discard_pile[discard_index]
    discard_pile.remove_at(discard_index)
    hand.append(rescued)
    _metric_add("cards_salvaged", 1)
    _log("サルベージ：%s を捨て札から手札へ戻した。" % rescued.get("id", "?"))
    var continuation: String = str(pending_hand_selection.get("continue", "finish"))
    pending_hand_selection = {"mode": "", "remaining": 0}
    if continuation == "C074_draw_bottom":
        draw_cards(1)
        pending_hand_selection = {"mode": "bottom", "remaining": 1}
    elif continuation == "post_attribute":
        _complete_resolving_card()
    else:
        _finish_resolving_card()
    return true

func _gain_attribute_trait(trait_name: String, amount: int, target_enemy_index: int = -1, source_card: Dictionary = {}) -> void:
    if amount <= 0 or trait_name == "":
        return
    if TraitSystem.is_enemy_trait(trait_name):
        _gain_enemy_attribute_trait(target_enemy_index, trait_name, amount, source_card)
    else:
        _gain_player_attribute_trait(trait_name, amount, source_card)

func _gain_player_attribute_trait(trait_name: String, amount: int, source_card: Dictionary = {}) -> void:
    if amount <= 0:
        return
    if not attribute_traits.has(trait_name):
        attribute_traits[trait_name] = 0
    var power_gain = _power_gain_modifiers(trait_name, amount, source_card)
    amount = int(power_gain.get("total", amount))
    if not source_card.is_empty():
        var affix_id: String = str(EquipmentSpecialEffectPolicy.ATTRIBUTE_GENERATORS.get(trait_name,""))
        if affix_id!="": amount += _local_attribute_gain_extra(source_card,trait_name,affix_id)
    var old_stack: int = int(attribute_traits[trait_name])
    var new_stack: int = old_stack + amount
    attribute_traits[trait_name] = new_stack
    _log("%s +%d (total %d)." % [trait_name, amount, new_stack])

    var crossed = TraitSystem.crossed_stages(old_stack, new_stack)
    _metric_add("attribute_threshold_activations",crossed.size())
    for stage_index in crossed:
        if trait_name == "魔珠":
            if source_card.get("attribute","")=="秘術" and _local_attribute_effect_ids(source_card).has("A18") and _local_effect_claim(source_card,"A18"):
                player_block+=3
                _metric_add("block_gained",3)
                _log("Equipment A18: 魔珠 crossed new threshold -> Block +3.")
            current_mana += 1
            _metric_add("mana_gained", 1)
            _log("魔珠 threshold %d: Mana +1 (current %d)." % [stage_index * 3, current_mana])
            var arcane_block: int = int(continuous_effects.get("arcane_first_magic_mana_block", 0))
            if arcane_block > 0 and not first_magic_orb_engine_used:
                first_magic_orb_engine_used = true
                player_block += arcane_block
                _metric_add("block_gained", arcane_block)
                _log("Arcane engine: first 魔珠 Mana recovery this turn → Block %d." % arcane_block)
        elif trait_name == "疾風":
            swift_cost_reduction_charges += 1
            _log("疾風 threshold %d: next-card Cost -1 charge +1 (stored %d)." % [stage_index * 3, swift_cost_reduction_charges])

    if trait_name == "魔珠" and not crossed.is_empty() and bool(source_card.get("step9_salvage", "") == "any_on_magic_orb_threshold"):
        resolving_card["_step9_magic_threshold_salvage"] = true
    _rearm_weapon_after_power(power_gain.get("triggered", []))

    if trait_name == "魔珠" and not crossed.is_empty() and int(source_card.get("magic_orb_threshold_draw_bonus", 0)) > 0:
        var bonus_draw: int = int(source_card.get("magic_orb_threshold_draw_bonus", 0))
        _log("Arcane cycle individuality: 魔珠 threshold crossed → Draw %d." % bonus_draw)
        draw_cards(bonus_draw)

func _gain_enemy_attribute_trait(enemy_index: int, trait_name: String, amount: int, source_card: Dictionary = {}) -> void:
    if amount <= 0 or not is_enemy_target_valid(enemy_index):
        return
    var enemy: Dictionary = enemies[enemy_index]
    var enemy_traits: Dictionary = enemy.get("attribute_traits", {})
    if int(enemy.get("r1_status",{}).get("StatusResist",0)) > 0:
        enemy.r1_status.StatusResist = int(enemy.r1_status.StatusResist)-1
        _log("%s StatusResist: attribute gain blocked." % str(enemy.id))
        return
    if not enemy_traits.has(trait_name):
        enemy_traits[trait_name] = 0
    var power_gain = _power_gain_modifiers(trait_name, amount, source_card)
    amount = int(power_gain.get("total", amount))
    if not source_card.is_empty():
        var affix_id: String = str(EquipmentSpecialEffectPolicy.ATTRIBUTE_GENERATORS.get(trait_name,""))
        if affix_id!="": amount += _local_attribute_gain_extra(source_card,trait_name,affix_id)
    var old_stack: int = int(enemy_traits[trait_name])
    var new_stack: int = old_stack + amount
    enemy_traits[trait_name] = new_stack
    enemy["attribute_traits"] = enemy_traits
    _log("#%d %s: %s +%d (total %d)." % [enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy"), trait_name, amount, new_stack])

    var crossed = TraitSystem.crossed_stages(old_stack, new_stack)
    _metric_add("attribute_threshold_activations",crossed.size())
    var first_explosion = true
    for stage_index in crossed:
        if trait_name == "爆発" and is_enemy_target_valid(enemy_index):
            var explosion_damage = TraitSystem.explosion_damage(stage_index)
            # Both the Fire generation individuality and any previously registered Fire engine
            # modify only the first explosion generated during this card's resolution.
            if first_explosion and not source_card.is_empty():
                if source_card.get("attribute","")=="炎" and _local_attribute_effect_ids(source_card).has("A04") and _local_effect_claim(source_card,"A04"):
                    explosion_damage += 2
                explosion_damage += int(source_card.get("first_explosion_bonus", 0))
                explosion_damage += int(continuous_effects.get("fire_first_explosion_bonus", 0))
            first_explosion = false
            _log("爆発 threshold %d: %d damage." % [stage_index * 3, explosion_damage])
            _deal_effect_damage_to_enemy(enemy_index, explosion_damage, "爆発")
    _rearm_weapon_after_power(power_gain.get("triggered", []))

func _deal_effect_damage_to_enemy(enemy_index: int, amount: int, source_name: String) -> void:
    if not is_enemy_target_valid(enemy_index):
        return
    var enemy: Dictionary = enemies[enemy_index]
    var visual_hp_before: int=maxi(0,int(enemy.hp))
    var remaining = max(0, amount)
    var enemy_block: int = int(enemy.get("block", 0))
    var absorbed = min(enemy_block, remaining)
    if absorbed > 0:
        enemy["block"] = enemy_block - absorbed
        remaining -= absorbed
        _log("%s: enemy Block absorbs %d." % [source_name, absorbed])
    if remaining > 0:
        var hp_before: int = max(0, int(enemy.get("hp", 0)))
        var actual_hp_damage = min(hp_before, remaining)
        enemy["hp"] = int(enemy.get("hp", 0)) - remaining
        _metric_add("damage_dealt", actual_hp_damage)
        _log("%s deals %d HP damage to #%d %s." % [source_name, remaining, enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy")])
    presentation_event.emit({"kind":"enemy_hit","enemy":enemy_index,"hp_loss":maxi(0,visual_hp_before-maxi(0,int(enemy.hp))),"block_loss":absorbed,"attribute":source_name})
    if int(enemy.get("hp", 0)) <= 0:
        enemy["hp"] = 0
        CampaignCombat.phase_if_needed(self,enemy)
        _log("#%d %s defeated by %s." % [enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy"), source_name])
        # Player cards must finish their confirmed resolution before Victory is finalized.
        # Enemy-phase reactions / poison have no resolving card, so they can end combat immediately.
        if resolving_card.is_empty():
            _check_victory()

func _get_enemy_attack_hit_values(enemy_index: int, base_damage: int, hits: int, consume_engine: bool = false) -> Array[int]:
    if enemy_index >= 0 and enemy_index < enemies.size():
        base_damage += int(enemies[enemy_index].get("r1_status",{}).get("Strength",0))
    var safe_hits = max(1, hits)
    var total_damage = max(0, base_damage) * safe_hits
    var slow_stage = get_enemy_attribute_stage(enemy_index, "鈍化")
    if slow_stage > 0:
        total_damage = max(1, total_damage - slow_stage * 2)
        var extra_reduction: int = int(continuous_effects.get("water_first_slow_attack_reduction", 0))
        if extra_reduction > 0 and not first_slow_engine_used:
            total_damage = max(1, total_damage - extra_reduction)
            if consume_engine:
                first_slow_engine_used = true

    var result: Array[int] = []
    var base_each = int(floor(float(total_damage) / float(safe_hits)))
    var remainder = total_damage % safe_hits
    for hit_index in range(safe_hits):
        result.append(base_each + (1 if hit_index < remainder else 0))
    if not result.is_empty() and int(campaign_status.get("Shock",0))>0:
        result[0]+=int(campaign_status.Shock)
        if consume_engine: campaign_status.Shock=0
    if int(campaign_status.get("Vulnerable",0))>0:
        for i in range(result.size()): result[i]=int(floor(float(result[i])*1.25))
    return result

func get_enemy_intent_display_label(enemy_index: int) -> String:
    var intent = get_enemy_intent(enemy_index)
    if intent.is_empty():
        return "-"
    var parts: Array[String] = []
    var planned_strength: int = 0
    var consumed_charge: int = -1
    for action in intent.get("actions", []):
        var action_type = str(action.get("type", ""))
        if action_type == "attack":
            var hits = max(1, int(action.get("hits", 1)))
            var values = _get_enemy_attack_hit_values(enemy_index, int(action.get("damage", 0)), hits)
            if planned_strength>0: values=_get_enemy_attack_hit_values(enemy_index,int(action.get("damage",0))+planned_strength,hits)
            var all_same = true
            for value in values:
                if value != values[0]:
                    all_same = false
                    break
            if hits == 1:
                parts.append("%dダメージの強攻撃" % values[0] if consumed_charge>=0 else "Attack %d" % values[0])
            elif all_same:
                parts.append("%dダメージ × %d回の強攻撃" % [values[0], hits] if consumed_charge>=0 else "Attack %d × %d" % [values[0], hits])
            else:
                var text_values: Array[String] = []
                for value in values:
                    text_values.append(str(value))
                var total_value = 0
                for value in values:
                    total_value += value
                parts.append("強攻撃 合計%dダメージ（%s）" % [total_value, "/".join(text_values)] if consumed_charge>=0 else "Attack %d total (%s)" % [total_value, "/".join(text_values)])
        elif action_type == "block":
            parts.append("Guard %d" % (int(action.get("amount", 0))+int(enemies[enemy_index].get("r1_status",{}).get("BlockStrength",0))))
        elif action_type == "status":
            var status_name: String="蓄力" if str(action.status)=="Charge" else str(action.status)
            parts.append("%s +%d" % [status_name,int(action.amount)])
            if str(action.status)=="Strength":
                var current: int=int(enemies[enemy_index].get("r1_status",{}).get("Strength",0))
                planned_strength=mini(6,current+planned_strength+int(action.amount))-current
        elif action_type == "player_status": parts.append("Player %s +%d" % [str(action.status),int(action.amount)])
        elif action_type == "ally_buff": parts.append("Allies Guard4 / Strength1")
        elif action_type == "summon": parts.append("召喚1（次の敵フェーズから行動）")
        elif action_type == "cleanse": parts.append("負状態を解除")
        elif action_type == "heal_ally": parts.append("味方回復 %d"%int(action.amount))
        elif action_type == "remove_player_block": parts.append("Player Block −%d"%int(action.amount))
        elif action_type == "mana_tax": parts.append("次ターンMana −%d"%int(action.amount))
        elif action_type == "retire": parts.append("攻撃後に退場")
        elif action_type == "heal": parts.append("Heal %d" % int(action.amount))
        elif action_type=="clear_status" and str(action.get("status",""))=="Charge":
            consumed_charge=int(enemies[enemy_index].get("r1_status",{}).get("Charge",0))
            parts.append("蓄力%dを全消費"%consumed_charge)
        elif action_type in ["clear_status","clear_player_status"]: parts.append("%sを解除" % str(action.status))
        else:
            parts.append(str(action.get("label", action_type)))
    # A status reset before a strike means spending accumulated charge, not
    # reducing attack damage to zero. Show the reason in plain Japanese.
    return " → ".join(parts)

func _resolve_charge_retaliation(enemy_index: int) -> void:
    if not is_enemy_target_valid(enemy_index):
        return
    var charged_stage = get_attribute_stage("帯電")
    if charged_stage <= 0:
        return
    var retaliation = charged_stage * 3
    var engine_bonus: int = int(continuous_effects.get("lightning_first_retaliation_bonus", 0))
    if engine_bonus > 0 and not first_retaliation_engine_used:
        retaliation += engine_bonus
        first_retaliation_engine_used = true
        _log("Lightning engine: first retaliation this enemy phase +%d." % engine_bonus)
    _log("帯電: retaliate %d after enemy Attack action." % retaliation)
    _deal_effect_damage_to_enemy(enemy_index, retaliation, "帯電")

func resolve_enemy_poison(enemy_index: int) -> void:
    if not is_enemy_target_valid(enemy_index): return
    var poison_stage = get_enemy_attribute_stage(enemy_index, "猛毒")
    if poison_stage <= 0: return
    var poison_damage = poison_stage * 2 + int(continuous_effects.get("poison_damage_bonus", 0))
    _log("猛毒: #%d takes %d at enemy-turn end." % [enemy_index + 1, poison_damage])
    _deal_effect_damage_to_enemy(enemy_index, poison_damage, "猛毒")

func _resolve_poison_end_of_enemy_phase() -> void:
    for enemy_index in range(enemies.size()):
        resolve_enemy_poison(enemy_index)
        if combat_over: return

func add_debug_card_to_hand(card_id: String) -> bool:
    if combat_over or is_hand_selection_active() or not resolving_card.is_empty():
        return false
    if hand.size() >= HAND_LIMIT:
        _notice("Hand limit reached. Debug card not added.")
        return false
    var card = database.create_card_copy(card_id)
    if card.is_empty():
        _notice("Card ID not found: %s" % card_id)
        return false
    hand.append(card)
    _log("DEBUG: added %s to hand." % card_id)
    return true

func add_debug_weapon_trait(trait_name: String, amount: int = 1) -> bool:
    if combat_over or is_hand_selection_active() or not resolving_card.is_empty():
        return false
    if not weapon_traits.has(trait_name):
        return false
    weapon_traits[trait_name] = amount > 0
    _log("DEBUG: %s %s." % [trait_name, "ON" if bool(weapon_traits[trait_name]) else "OFF"])
    return true

func add_debug_attribute_trait(trait_name: String, amount: int = 3) -> bool:
    if combat_over or is_hand_selection_active() or not resolving_card.is_empty():
        return false
    if not TraitSystem.is_player_trait(trait_name):
        return false
    _log("DEBUG player trait gain: %s +%d." % [trait_name, amount])
    _gain_player_attribute_trait(trait_name, amount)
    return true

func add_debug_enemy_attribute_trait(enemy_index: int, trait_name: String, amount: int = 3) -> bool:
    if combat_over or is_hand_selection_active() or not resolving_card.is_empty():
        return false
    if not TraitSystem.is_enemy_trait(trait_name) or not is_enemy_target_valid(enemy_index):
        return false
    _log("DEBUG enemy trait gain: #%d %s +%d." % [enemy_index + 1, trait_name, amount])
    _gain_enemy_attribute_trait(enemy_index, trait_name, amount, {})
    return true

func debug_damage_player(amount: int = 10) -> bool:
    if combat_over or is_hand_selection_active() or not resolving_card.is_empty():
        return false
    var before_payment: int = player_hp
    player_hp = max(1, player_hp - max(0, amount))
    _metric_add("self_hp_paid",before_payment-player_hp)
    _log("DIAG HP_CHANGE cause=self_payment before=%d after=%d actual_loss=%d" % [before_payment,player_hp,before_payment-player_hp])
    _log("DEBUG: player HP reduced by %d → %d/%d." % [amount, player_hp, player_max_hp])
    return true

func debug_prepare_execution_target(enemy_index: int = 2) -> bool:
    if combat_over or is_hand_selection_active() or not resolving_card.is_empty():
        return false
    if not is_enemy_target_valid(enemy_index):
        enemy_index = -1
        for i in range(enemies.size() - 1, -1, -1):
            if is_enemy_target_valid(i) and bool(enemies[i].get("is_boss", false)):
                enemy_index = i
                break
        if enemy_index < 0:
            for i in range(enemies.size() - 1, -1, -1):
                if is_enemy_target_valid(i):
                    enemy_index = i
                    break
    if enemy_index < 0:
        return false
    var enemy: Dictionary = enemies[enemy_index]
    var threshold_hp = int(floor(float(enemy.get("max_hp", 1)) * 0.10))
    enemy["hp"] = min(int(enemy.get("max_hp", 1)), threshold_hp + 12)
    enemy["block"] = 0
    _log("DEBUG: #%d %s prepared for 12-damage Iai execution test: HP=%d, Block=0." % [enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy"), enemy["hp"]])
    return true

func end_player_turn() -> void:
    if combat_over or is_hand_selection_active() or not resolving_card.is_empty():
        return

    if not finish_player_turn_effects(): return
    _enemy_phase()
    if combat_over:
        return

    turn_number += 1
    _player_turn_start(false)

func finish_player_turn_effects() -> bool:
    while not hand.is_empty():
        discard_pile.append(hand.pop_back())
        presentation_event.emit({"kind":"discard","id":str(discard_pile[-1].get("id",""))})

    _log("End Player Turn.")
    CampaignCombat.player_turn_end(self)
    return true

func draw_cards(count: int) -> int:
    last_notice = ""
    var available_slots: int = HAND_LIMIT - hand.size()
    var requested: int = min(count, available_slots)
    var drawn = 0

    if requested <= 0:
        _notice("Hand limit reached. Draw skipped.")
        return 0

    for _i in range(requested):
        if draw_pile.is_empty():
            if discard_pile.is_empty():
                break
            draw_pile = discard_pile.duplicate(true)
            discard_pile.clear()
            _shuffle_with_battle_rng(draw_pile)
            _log("Discard pile shuffled into a new draw pile (Seed stream %d)." % active_seed)

        if draw_pile.is_empty():
            break

        hand.append(draw_pile.pop_back())
        presentation_event.emit({"kind":"draw","id":str(hand[-1].get("id",""))})
        drawn += 1

    _metric_add("cards_drawn", drawn)
    if drawn < count:
        _notice("Hand limit / deck state: %d of %d card(s) drawn." % [drawn, count])
    return drawn

func get_discard_display_lines() -> Array[String]:
    var lines: Array[String] = []
    if discard_pile.is_empty():
        lines.append("(empty)")
        return lines
    for card in discard_pile:
        lines.append("%s — %s" % [card.get("id", "?"), card.get("display_name", "")])
    return lines

func _player_turn_start(first_turn: bool) -> void:
    # Formal order: reset turn-limited flags -> clear old Block -> set Base Mana
    # -> 堅牢 Block -> 恩寵 Heal -> other start effects -> Draw5.
    curse_lifesteal_used = false
    first_attack_engine_used = false
    first_magic_orb_engine_used = false
    first_swift_engine_used = false
    first_slow_engine_used = false
    first_retaliation_engine_used = false
    player_block = 0
    current_mana = BASE_MANA
    current_mana-=mini(2,int(campaign_status.get("ManaTax",0)))
    campaign_status.erase("ManaTax")
    # C083 Power: each player turn (not merely on initial install), if a cursed enemy exists.
    var dark_iai_engine: bool = false
    for power in power_trait_engines:
        if str(power.get("id", "")) == "C083":
            dark_iai_engine = true
            break
    if dark_iai_engine and not bool(weapon_traits.get("納刀", false)):
        for enemy in enemies:
            if int(enemy.get("hp", 0)) > 0 and int(enemy.get("attribute_traits", {}).get("呪印", 0)) > 0:
                weapon_traits["納刀"] = true
                _log("C083 engine: cursed enemy present -> 納刀 ON.")
                break

    # Battle-start equipment traits resolve after Base Mana is established on turn 1,
    # so threshold effects such as 魔珠/疾風 are not erased by the turn-start reset.
    if first_turn:
        _apply_equipment_battle_start_effects()

    var fortify_stage = get_attribute_stage("堅牢")
    if fortify_stage > 0:
        var fortify_block = fortify_stage * 2 + int(continuous_effects.get("earth_turn_start_block_bonus", 0))
        player_block += fortify_block
        _metric_add("block_gained", fortify_block)
        _log("堅牢: turn-start Block +%d." % fortify_block)

    var grace_stage = get_attribute_stage("恩寵")
    if grace_stage > 0:
        var heal_amount = grace_stage + int(continuous_effects.get("light_turn_start_heal_bonus", 0))
        _heal_player(heal_amount, "恩寵")

    var equipment_block = _sum_equipment_effect("turn_start_block")
    if equipment_block > 0:
        player_block += equipment_block
        _metric_add("block_gained", equipment_block)
        _log("Equipment effects: turn-start Block +%d." % equipment_block)

    var equipment_mana = _sum_equipment_effect("turn_start_mana")
    if equipment_mana > 0:
        current_mana += equipment_mana
        _metric_add("mana_gained", equipment_mana)
        _log("Equipment effects: turn-start Mana +%d (current %d)." % [equipment_mana, current_mana])

    playtest_stats["dagger_attacks_turn"] = 0
    _log("DIAG TURN_START_BEFORE_DRAW turn=%d hp=%d/%d mana=%d block=%d hand=%s draw_pile=%d discard=%d power=%s weapon=%s attribute=%s enemies=%s" % [turn_number,player_hp,player_max_hp,current_mana,player_block,str(_diag_hand()),draw_pile.size(),discard_pile.size(),str(_diag_hand_from(power_zone)),str(weapon_traits),str(attribute_traits),str(_diag_enemies())])
    var draw_amount = 5
    if first_turn:
        draw_amount += _sum_equipment_effect("first_turn_draw")
    var previous_hand: Array = _diag_hand()
    draw_cards(draw_amount)
    _log("DIAG TURN_START_AFTER_DRAW turn=%d drawn=%s hand=%s draw_pile=%d discard=%d intent=%s" % [turn_number,str(_diag_new_hand(previous_hand)),str(_diag_hand()),draw_pile.size(),discard_pile.size(),str(_diag_enemies())])

    if first_turn:
        _log("Player Turn 1: Mana=%d, start effects, Draw%d." % [current_mana, draw_amount])
    else:
        _log("Player Turn %d: Block reset, Mana=%d, start effects, Draw5." % [turn_number, current_mana])

func _enemy_phase() -> void:
    _log("Enemy Phase start.")
    first_slow_engine_used = false
    first_retaliation_engine_used = false

    for enemy_index in range(enemies.size()):
        if player_hp <= 0:
            break
        var enemy: Dictionary = enemies[enemy_index]
        if int(enemy.get("hp", 0)) <= 0:
            continue
        if int(enemy.get("summoned_turn",-1))==turn_number: continue
        var phase_at_start: int=int(enemy.get("phase_index",0))

        var intent: Dictionary = get_enemy_intent(enemy_index)
        _log("#%d %s: %s" % [enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy"), get_enemy_intent_display_label(enemy_index)])

        for action in intent.get("actions", []):
            if player_hp <= 0 or int(enemy.get("hp", 0)) <= 0 or int(enemy.get("phase_index",0))!=phase_at_start:
                break
            perform_enemy_action(enemy_index,action,phase_at_start)

    if player_hp <= 0:
        _finalize_battle("DEFEAT", "player_hp_zero")
        return

    # Enemy-turn end: 猛毒 in EnemyOrderIndex order, then death/victory, then next Intents.
    _resolve_poison_end_of_enemy_phase()
    if combat_over:
        return
    _check_victory()
    if combat_over: return
    CampaignCombat.enemy_turn_end(self)
    if combat_over: return
    for enemy in enemies:
        if int(enemy.hp)>0 and enemy.has("r1_status"):
            enemy.hp=mini(int(enemy.max_hp),int(enemy.hp)+int(enemy.r1_status.get("Regen",0)))
    _log("DIAG ENEMY_PHASE_END hp=%d/%d mana=%d block=%d enemies=%s" % [player_hp,player_max_hp,current_mana,player_block,str(_diag_enemies())])

    # The next Intent preview represents the next enemy phase, so first-action engines are available again.
    first_slow_engine_used = false
    first_retaliation_engine_used = false

    for enemy_index in range(enemies.size()):
        var enemy: Dictionary = enemies[enemy_index]
        if int(enemy.get("hp", 0)) <= 0:
            continue
        if enemy.has("r1_data"):
            if int(enemy.get("summoned_turn",-1))==turn_number: continue
            RegionEnemyCatalog.new().advance(enemy,battle_rng)
            continue
        var intents: Array = enemy.get("intents", [])
        if intents.is_empty():
            continue
        enemy["intent_index"] = (int(enemy.get("intent_index", 0)) + 1) % intents.size()
        _log("Next Intent #%d %s: %s" % [
            enemy.get("order_index", enemy_index + 1),
            enemy.get("name", "Enemy"),
            get_enemy_intent_display_label(enemy_index)
        ])

func perform_enemy_action(enemy_index: int, action: Dictionary, phase_at_start: int) -> void:
    var enemy: Dictionary=enemies[enemy_index]
    presentation_event.emit({"kind":"enemy_action","enemy":enemy_index,"action":str(action.get("type","")),"intent":get_enemy_intent_display_label(enemy_index)})
    if CampaignCombat.action(self,enemy,action): return
    var action_type: String = str(action.get("type", ""))
    if action_type == "attack":
        _log("DIAG ENEMY_ATTACK_BEGIN enemy=%s base=%d hits=%d strength=%d hp=%d/%d block=%d" % [str(enemy.get("id","?")),int(action.get("damage",0)),int(action.get("hits",1)),int(enemy.get("r1_status",{}).get("Strength",0)),player_hp,player_max_hp,player_block])
        _metric_add("enemy_attack_actions_received", 1)
        var hit_values = _get_enemy_attack_hit_values(enemy_index, int(action.get("damage", 0)), int(action.get("hits", 1)), true)
        var slow_stage = get_enemy_attribute_stage(enemy_index, "鈍化")
        if slow_stage > 0:
            var total_adjusted = 0
            for value in hit_values:
                total_adjusted += value
            _log("  鈍化 stage %d: Attack action total becomes %d." % [slow_stage, total_adjusted])
        for hit_index in range(hit_values.size()):
            if player_hp <= 0 or int(enemy.hp)<=0 or int(enemy.get("phase_index",0))!=phase_at_start:
                break
            _log("  Enemy Hit %d/%d (%d)" % [hit_index + 1, hit_values.size(), hit_values[hit_index]])
            _take_player_damage(hit_values[hit_index])
            _log("DIAG ENEMY_HIT enemy=%s hit=%d/%d actual_attack=%d hp_after=%d block_after=%d" % [str(enemy.get("id","?")),hit_index+1,hit_values.size(),hit_values[hit_index],player_hp,player_block])
        if player_hp > 0:
            _resolve_charge_retaliation(enemy_index)
    elif action_type == "block":
        var amount: int = int(action.get("amount", 0))
        amount+=int(enemy.get("r1_status",{}).get("BlockStrength",0))
        enemy["block"] = int(enemy.get("block", 0)) + amount
        _log("  #%d %s gains Block %d (total %d)." % [enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy"), amount, enemy["block"]])
    elif action_type == "status":
        var status_name: String = str(action.get("status",""))
        var cap: int = {"Strength":6,"Thorns":5,"StatusResist":3,"BlockStrength":3}.get(status_name,2147483647)
        if status_name == "Regen":
            enemy.r1_status[status_name] = int(action.amount)
        else:
            enemy.r1_status[status_name] = clampi(int(enemy.r1_status.get(status_name,0))+int(action.amount),0,cap)
        _log("DIAG ENEMY_STATUS enemy=%s status=%s received=%d total=%d" % [str(enemy.get("id","?")),status_name,int(action.get("amount",0)),int(enemy.r1_status.get(status_name,0))])
    elif action_type == "clear_status":
        var status_name: String = str(action.status)
        if enemy.r1_status.has(status_name): enemy.r1_status[status_name]=0
        if enemy.attribute_traits.has(status_name): enemy.attribute_traits[status_name]=0
        _log("DIAG ENEMY_STATUS_CLEAR enemy=%s status=%s" % [str(enemy.get("id","?")),status_name])
    elif action_type == "ally_buff":
        for ally in enemies:
            if int(ally.hp)>0:
                ally.block=int(ally.block)+4
                if ally.has("r1_status"): ally.r1_status.Strength=mini(6,int(ally.r1_status.Strength)+1)
    elif action_type == "heal":
        enemy.hp=mini(int(enemy.max_hp),int(enemy.hp)+int(action.amount))
    elif action_type == "clear_player_status":
        region1_player_status[str(action.status)]=0
        if campaign_status.has(str(action.status)): campaign_status[str(action.status)]=0


func _deal_damage_to_enemy(enemy_index: int, amount: int, ignore_block: bool = false) -> void:
    if not is_enemy_target_valid(enemy_index):
        return

    var enemy: Dictionary = enemies[enemy_index]
    var remaining = amount
    var absorbed = 0

    if not ignore_block:
        var enemy_block: int = int(enemy.get("block", 0))
        if enemy_block > 0:
            absorbed = min(enemy_block, remaining)
            enemy["block"] = enemy_block - absorbed
            remaining -= absorbed

    if ignore_block and int(enemy.get("block", 0)) > 0:
        _log("Block Ignore: enemy Block %d is bypassed." % int(enemy.get("block", 0)))
    elif absorbed > 0:
        _log("Enemy Block absorbs %d." % absorbed)

    var hp_before: int = max(0, int(enemy.get("hp", 0)))
    var actual_hp_damage = min(hp_before, max(0, remaining))
    enemy["hp"] = int(enemy.get("hp", 0)) - remaining
    _metric_add("damage_dealt", actual_hp_damage)
    presentation_event.emit({"kind":"enemy_hit","enemy":enemy_index,"hp_loss":actual_hp_damage,"block_loss":absorbed,"attribute":str(resolving_card.get("attribute","物理"))})
    _log("Deal %d attack value to #%d %s → HP damage %d." % [amount, enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy"), remaining])

    if int(enemy["hp"]) <= 0:
        enemy["hp"] = 0
        CampaignCombat.phase_if_needed(self,enemy)
        _log("#%d %s defeated." % [enemy.get("order_index", enemy_index + 1), enemy.get("name", "Enemy")])

func _take_player_damage(amount: int) -> void:
    var visual_block_before: int=player_block
    var visual_hp_before: int=player_hp
    var remaining = amount
    if player_block > 0:
        var absorbed: int = min(player_block, remaining)
        player_block -= absorbed
        remaining -= absorbed
        _metric_add("block_absorbed", absorbed)
        _log("Block absorbs %d." % absorbed)
    if remaining > 0:
        var actual_hp_damage = min(max(0, player_hp), remaining)
        player_hp -= remaining
        _metric_add("damage_taken", actual_hp_damage)
        _log("Player takes %d damage." % remaining)

    _log("DIAG HP_CHANGE cause=attack before=%d after=%d actual_loss=%d block_absorbed=%d" % [visual_hp_before,player_hp,maxi(0,visual_hp_before-maxi(0,player_hp)),maxi(0,visual_block_before-player_block)])
    presentation_event.emit({"kind":"player_hit","hp_loss":maxi(0,visual_hp_before-maxi(0,player_hp)),"block_loss":maxi(0,visual_block_before-player_block)})

func _check_victory() -> void:
    if combat_over:
        return
    for enemy in enemies:
        if int(enemy.get("hp", 0)) > 0:
            return
    _finalize_battle("VICTORY", "all_enemies_defeated")

func _notice(message: String) -> void:
    last_notice = message
    _log(message)

func _diag_hand() -> Array:
    return _diag_hand_from(hand)

func _diag_hand_from(cards: Array) -> Array:
    var result: Array=[]
    for card in cards:
        result.append(str(card.get("id","?")) if card is Dictionary else str(card))
    return result

func _diag_new_hand(before: Array) -> Array:
    var current: Array = _diag_hand()
    if current.size()<before.size(): return current
    return current.slice(before.size())

func _diag_enemies() -> Array:
    var result: Array=[]
    for idx in range(enemies.size()):
        var enemy: Dictionary=enemies[idx]
        if int(enemy.get("hp",0))<=0: continue
        result.append({"id":str(enemy.get("id","?")),"hp":int(enemy.get("hp",0)),"max_hp":int(enemy.get("max_hp",0)),"block":int(enemy.get("block",0)),"strength":int(enemy.get("r1_status",{}).get("Strength",0)),"charge":int(enemy.get("r1_status",{}).get("Charge",0)),"intent":get_enemy_intent_display_label(idx)})
    return result

func get_diagnostic_log() -> Array[String]:
    var result: Array[String]=[]
    for line in playtest_stats.get("diagnostic_events",[]):
        result.append(str(line))
    return result if not result.is_empty() else logs.duplicate()

func _log(message: String) -> void:
    # Detailed local diagnostics do not enter the ordinary UI/EOS public log stream.
    # playtest_stats already belongs to the local battle save and report schema.
    if not playtest_stats.is_empty():
        var detailed: Array=playtest_stats.get("diagnostic_events",[])
        detailed.append(message)
        if detailed.size()>1600: detailed.pop_front()
        playtest_stats["diagnostic_events"]=detailed
    if message.begins_with("DIAG "): return
    presentation_event.emit({"kind":"log","message":message})
    logs.append(message)
    if logs.size() > 220:
        logs.pop_front()



