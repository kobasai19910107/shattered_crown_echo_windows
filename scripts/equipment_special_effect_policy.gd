class_name EquipmentSpecialEffectPolicy
extends RefCounted

# Phase 4: U01-U10, W01-W18 and A01-A20 are equipment-local.
# Gem/passive global changes are deliberately not implemented here.
const CARD_MASTER_PATH := "res://data/cards_master.json"
const U_EFFECT_IDS := ["U01","U02","U03","U04","U05","U06","U07","U08","U09","U10"]
const W_EFFECT_IDS := ["W01","W02","W03","W04","W05","W06","W07","W08","W09","W10","W11","W12","W13","W14","W15","W16","W17","W18"]
const A_EFFECT_IDS := ["A01","A02","A03","A04","A05","A06","A07","A08","A09","A10","A11","A12","A13","A14","A15","A16","A17","A18","A19","A20"]
const EFFECT_IDS := U_EFFECT_IDS + W_EFFECT_IDS + A_EFFECT_IDS
const ATTRIBUTE_EFFECTS := {
    "物理":["A01","A02"], "炎":["A03","A04"],
    "水":["A05","A06"], "雷":["A07","A08"],
    "地":["A09","A10"], "光":["A11","A12"],
    "闇":["A13","A14"], "毒":["A15","A16"],
    "秘術":["A17","A18"], "風":["A19","A20"]
}
const ATTRIBUTE_GENERATORS := {"剛力":"A01","爆発":"A03","鈍化":"A05","帯電":"A07","堅牢":"A09","恩寵":"A11","呪印":"A13","猛毒":"A15","魔珠":"A17","疾風":"A19"}
const RARITY_SLOTS := {"Common":0,"Rare":1,"Epic":2,"Legendary":3}
const NAMES := {
    "U01":"初陣の刃", "U02":"刃の研磨", "U03":"重刃の心得",
    "U04":"初陣の盾", "U05":"守護の刻印", "U06":"攻勢連携",
    "U07":"守勢連携", "U08":"思考加速", "U09":"魔力還元", "U10":"機関起動",
    "W01":"流転の護刃", "W02":"攻守転律", "W03":"流転の備え",
    "W04":"精密穿孔", "W05":"点穴の護り", "W06":"集中歩法",
    "W07":"双刃追撃", "W08":"影の構え", "W09":"連刻の技",
    "W10":"重撃の極意", "W11":"蓄撃防壁", "W12":"破軍の余勢",
    "W13":"魔導障壁", "W14":"魔導増幅", "W15":"魔力再生",
    "W16":"納刀の守り", "W17":"居合の極意", "W18":"抜刀残心",
    "A01":"剛力の刻印",
    "A02":"金剛の一撃",
    "A03":"火種の刻印",
    "A04":"爆炎共鳴",
    "A05":"凍気の刻印",
    "A06":"鈍化追撃",
    "A07":"帯電の刻印",
    "A08":"雷護障壁",
    "A09":"地脈の刻印",
    "A10":"堅牢護壁",
    "A11":"恩寵の刻印",
    "A12":"聖光の祈り",
    "A13":"呪刻の刻印",
    "A14":"吸命の印",
    "A15":"毒腺の刻印",
    "A16":"毒葬の刃",
    "A17":"魔珠の刻印",
    "A18":"魔珠障壁",
    "A19":"疾風の刻印",
    "A20":"追風の守り"
}
const DETAILS := {
    "U01":"この装備の最初のAttackのダメージ+3（戦闘1回）",
    "U02":"この装備のAttackのダメージ+2（ターン1回）",
    "U03":"この装備のPrinted Cost2以上のAttackのダメージ+3（ターン1回）",
    "U04":"この装備のBlockを得るSkillのBlock+4（戦闘1回）",
    "U05":"この装備のBlockを得るSkillのBlock+2（ターン1回）",
    "U06":"Skill直後、この装備のAttackのダメージ+2（ターン1回）",
    "U07":"Attack直後、この装備のBlockを得るSkillのBlock+2（ターン1回）",
    "U08":"この装備のDrawカードで追加Draw1（戦闘1回）",
    "U09":"この装備のカードにMana2以上支払った後、Mana1回復（戦闘1回）",
    "U10":"この装備由来のPowerを使用した後、Block4（戦闘1回）",
    "W01":"流転を消費する片手剣Attackの解決後Block2（ターン1回）",
    "W02":"Attack直後の片手剣Block SkillのBlock+3（ターン1回）",
    "W03":"片手剣カードで流転を新規ONにした後Block2（ターン1回）",
    "W04":"精密を消費するレイピアAttackのダメージ+2（ターン1回）",
    "W05":"精密消費で実際に脆弱を付与した時Block2（ターン1回）",
    "W06":"精密を新規ONにした時Draw1（戦闘1回）",
    "W07":"連刃2Hit目のダメージだけ+2（ターン1回）",
    "W08":"短剣カードで連刃を新規ONにした後Block2（ターン1回）",
    "W09":"このターン別の短剣Attackを使用済みならダメージ+2（ターン1回）",
    "W10":"重撃1.5倍計算後のダメージ+3（ターン1回、直接加算合計+5まで）",
    "W11":"大剣カードで重撃を新規ONにした後Block3（ターン1回）",
    "W12":"Printed Cost2以上の大剣Attack使用後Block2（ターン1回）",
    "W13":"魔法剣カードで魔導を新規ONにした後Block2（ターン1回）",
    "W14":"魔導消費による属性特性獲得量+1（ターン1回）",
    "W15":"魔導消費後Mana1回復（戦闘1回）",
    "W16":"刀カードで納刀を新規ONにした後Block2（ターン1回）",
    "W17":"納刀からの居合対応Attackのダメージ+3（ターン1回）",
    "W18":"納刀からの居合対応Attack解決後Block3（ターン1回）",
    "A01":"この装備由来の剛力付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A02":"使用前に剛力3以上なら、この装備由来の物理Attackダメージ+2（ターン1回）",
    "A03":"この装備由来の爆発付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A04":"この装備由来の爆発閾値ダメージ+2（カード1枚につき最初の爆発のみ／ターン1回）",
    "A05":"この装備由来の鈍化付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A06":"使用前に対象の鈍化3以上なら、この装備由来の水Attackダメージ+2（ターン1回）",
    "A07":"この装備由来の帯電付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A08":"使用前に帯電3以上なら、この装備由来の雷Block SkillのBlock+3（ターン1回）",
    "A09":"この装備由来の堅牢付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A10":"使用前に堅牢3以上なら、この装備由来の地Block SkillのBlock+3（ターン1回）",
    "A11":"この装備由来の恩寵付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A12":"使用前に恩寵3以上なら、この装備由来の光カード使用後HP1回復（ターン1回）",
    "A13":"この装備由来の呪印付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A14":"使用前に対象の呪印3以上なら、この装備由来の闇Attack命中後HP1回復（ターン1回）",
    "A15":"この装備由来の猛毒付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A16":"使用前に対象の猛毒3以上なら、この装備由来の毒Attackダメージ+2（ターン1回）",
    "A17":"この装備由来の魔珠付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A18":"この装備由来の魔珠が新しい3/6/9閾値に到達したときBlock3（ターン1回）",
    "A19":"この装備由来の疾風付与量+1（同属性の装備追加付与は全装備合計ターン1回）",
    "A20":"この装備由来の風カードで疾風によるCost軽減を実際に消費したときBlock3（ターン1回）"
}

static var _cached_cards: Dictionary = {}

static func _card_master() -> Dictionary:
    if not _cached_cards.is_empty():
        return _cached_cards
    if not FileAccess.file_exists(CARD_MASTER_PATH):
        return {}
    var data = JSON.parse_string(FileAccess.get_file_as_string(CARD_MASTER_PATH))
    if not data is Dictionary or not data.get("cards", {}) is Dictionary:
        return {}
    _cached_cards = data["cards"]
    return _cached_cards

static func eligible_ids(item: Dictionary) -> Array[String]:
    var result: Array[String] = []
    var db: Dictionary = _card_master()
    var raw_cards = item.get("cards", [])
    if not raw_cards is Array or raw_cards.size()!=4 or db.is_empty():
        return result
    var attacks: int = 0
    var heavy_attacks: int = 0
    var block_skills: int = 0
    var draws: int = 0
    var heavy: int = 0
    var powers: int = 0
    var has_set: Dictionary = {}
    var has_attack_consume: Dictionary = {}
    var has_attack: Dictionary = {}
    var has_block_skill: Dictionary = {}
    var has_heavy_attack: Dictionary = {}
    var has_iai_attack: Dictionary = {}
    var has_magic_gain_consume: bool = false
    var attribute_actions: Dictionary = {}
    var attribute_attacks: Dictionary = {}
    var attribute_block_skills: Dictionary = {}
    var attribute_gainers: Dictionary = {}
    var wind_positive_cost: bool = false
    for raw_id in raw_cards:
        var id: String = str(raw_id)
        if not db.has(id): return []
        var c: Dictionary = db[id]
        var typ: String = str(c.get("card_type", ""))
        var cost: int = int(c.get("cost", 0))
        var weapon: String = str(c.get("weapon", ""))
        var action: String = str(c.get("weapon_trait_action", "NEUTRAL"))
        var attribute: String = str(c.get("attribute", ""))
        attribute_actions[attribute] = true
        if int(c.get("attribute_trait_gain", 0))>0:
            attribute_gainers[attribute] = true
        if attribute=="風" and cost>0: wind_positive_cost=true
        if action == "SET": has_set[weapon] = true
        if typ=="attack":
            attribute_attacks[attribute] = true
            has_attack[weapon] = true
            if action == "CONSUME": has_attack_consume[weapon] = true
            if cost>=2: has_heavy_attack[weapon] = true
            if weapon=="刀" and action=="CONSUME" and bool(c.get("iai_compatible",false)):
                has_iai_attack[weapon] = true
            attacks+=1
            if cost>=2: heavy_attacks+=1
        if typ=="skill" and (int(c.get("base_block",0))>0 or int(c.get("condition_block_bonus",0))>0):
            has_block_skill[weapon] = true
            attribute_block_skills[attribute] = true
            block_skills+=1
        if weapon == "魔法剣" and action == "CONSUME" and int(c.get("attribute_trait_gain",0)) > 0:
            has_magic_gain_consume = true
        if int(c.get("draw_count",0))>0 or int(c.get("conditional_draw_count",0))>0 or int(c.get("condition_draw_bonus",0))>0:
            draws+=1
        if cost>=2: heavy+=1
        if typ=="power": powers+=1
    if attacks>0: result.append_array(["U01","U02","U06"])
    if heavy_attacks>0: result.append("U03")
    if block_skills>0: result.append_array(["U04","U05","U07"])
    if draws>0: result.append("U08")
    if heavy>0: result.append("U09")
    if powers>0: result.append("U10")
    # A matching card in this equipment's four-card set must exist.
    # Other cards/weapon traits may set up a condition, but never create a
    # matching card on this equipment by themselves.
    if has_attack_consume.has("片手剣"): result.append("W01")
    if has_block_skill.has("片手剣"): result.append("W02")
    if has_set.has("片手剣"): result.append("W03")
    if has_attack_consume.has("レイピア"):
        result.append_array(["W04","W05"])
    if has_set.has("レイピア"): result.append("W06")
    if has_attack_consume.has("短剣"): result.append("W07")
    if has_set.has("短剣"): result.append("W08")
    if has_attack.has("短剣"): result.append("W09")
    if has_attack_consume.has("大剣"): result.append("W10")
    if has_set.has("大剣"): result.append("W11")
    if has_heavy_attack.has("大剣"): result.append("W12")
    if has_set.has("魔法剣"): result.append("W13")
    if has_magic_gain_consume: result.append_array(["W14","W15"])
    if has_set.has("刀"): result.append("W16")
    if has_iai_attack.has("刀"): result.append_array(["W17","W18"])
    # An affix must have at least one effective card in this item's four cards.
    # A conditional Exploit can depend on trait stacks gained by other cards.
    for attr_id in ["物理","炎","水","雷","地","光","闇","毒","秘術","風"]:
        var pair: Array = ATTRIBUTE_EFFECTS[attr_id]
        if attribute_gainers.has(attr_id): result.append(pair[0])
        var exploitable: bool = false
        match attr_id:
            "物理","水","闇","毒": exploitable=attribute_attacks.has(attr_id)
            "炎","秘術": exploitable=attribute_gainers.has(attr_id)
            "雷","地": exploitable=attribute_block_skills.has(attr_id)
            "光": exploitable=attribute_actions.has(attr_id)
            "風": exploitable=wind_positive_cost
        if exploitable: result.append(pair[1])
    return result

static func validate_effects(item: Dictionary, strict: bool = true) -> bool:
    var raw = item.get("special_effects", [])
    if not raw is Array: return false
    var rarity: String = str(item.get("rarity", ""))
    if not RARITY_SLOTS.has(rarity): return false
    var max_count: int = mini(int(RARITY_SLOTS[rarity]), int(item.get("special_effect_slots",RARITY_SLOTS[rarity])))
    if raw.size()>max_count: return false
    # Card rerolls at the forge can remove the last usable target without
    # removing the equipment affix. Such an affix stays equipped but dormant;
    # rejecting the item here would break saves and ordinary forge operations.
    var seen: Dictionary = {}
    for entry in raw:
        if not entry is Dictionary: return false
        var id: String = str(entry.get("effect_id", ""))
        if not EFFECT_IDS.has(id) or seen.has(id):
            # Old saves with legacy effects must not be fabricated or wiped by
            # a migration. The coop peer admission uses strict=true.
            if not strict and id=="" and str(entry.get("type", "")) in ["battle_start_weapon_trait","battle_start_attribute_trait"]:
                continue
            return false
        if entry.size()!=1: return false
        seen[id]=true
    return true

static func roll_on_drop(item: Dictionary) -> Array:
    var count: int = int(RARITY_SLOTS.get(str(item.get("rarity", "")),0))
    count=mini(count,int(item.get("special_effect_slots",count)))
    if count<=0: return []
    var pool: Array[String] = eligible_ids(item)
    var rng = RandomNumberGenerator.new()
    # Isolated from route, shop, battle, initial-deck, and forge RNG streams.
    rng.seed=hash("local-affix-v1|%s|%s|%s|%s" % [str(item.get("instance_id","")),str(item.get("equipment_id","")),str(item.get("seed",0)),str(item.get("random_cards",[]))])
    var result: Array = []
    for _i in range(mini(count,pool.size())):
        var chosen: int = rng.randi_range(0,pool.size()-1)
        result.append({"effect_id":pool[chosen]})
        pool.remove_at(chosen)
    return result

static func summary(item: Dictionary, multiline: bool = true) -> String:
    var effects = item.get("special_effects", [])
    if not effects is Array or effects.is_empty(): return "特殊効果なし"
    var lines: Array[String] = []
    var currently_eligible: Array[String] = eligible_ids(item)
    for e in effects:
        if not e is Dictionary: continue
        var id: String = str(e.get("effect_id", ""))
        if NAMES.has(id):
            var dormant: String = "（現在の4カードでは休眠）" if not currently_eligible.has(id) else ""
            lines.append("%s %s：%s%s" % [id,str(NAMES[id]),str(DETAILS[id]),dormant])
        else:
            lines.append("従来効果（互換）")
    return ("\n" if multiline else " / ").join(lines)

static func brief(item: Dictionary) -> String:
    var effects = item.get("special_effects", [])
    if not effects is Array or effects.is_empty(): return "効果なし"
    var names: Array[String] = []
    for e in effects:
        if e is Dictionary:
            var id: String = str(e.get("effect_id", ""))
            names.append(str(NAMES.get(id,"従来効果")))
    return "効果：" + "・".join(names)
