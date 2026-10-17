class_name WeaponTraitCardDescription
extends RefCounted

# The master JSON and BattleController remain authoritative. This class only
# describes the existing CONSUME rule; it never changes combat state.
const WEAPON_TRAITS := {
    "片手剣": "流転", "レイピア": "精密", "短剣": "連刃",
    "大剣": "重撃", "魔法剣": "魔導", "刀": "納刀"
}

static func is_applicable(card: Dictionary) -> bool:
    if str(card.get("weapon_trait_action", "NEUTRAL")) != "CONSUME":
        return false
    var weapon: String = str(card.get("weapon", ""))
    var is_attack: bool = str(card.get("card_type", "")) == "attack"
    match weapon:
        "片手剣": return is_attack or int(card.get("base_block", 0)) > 0
        "レイピア", "短剣", "大剣": return is_attack
        "魔法剣": return int(card.get("attribute_trait_gain", 0)) > 0
        "刀": return bool(card.get("iai_compatible", false))
    return false

static func already_in_master(card: Dictionary) -> bool:
    # Three Katana finishers already spell out both Iai Cost0 and execution.
    if str(card.get("weapon", "")) != "刀":
        return false
    var formal: String = str(card.get("text", ""))
    return formal.contains("納刀ON") and formal.contains("Cost0") and formal.contains("OFF")

static func effect_text(card: Dictionary) -> String:
    if not is_applicable(card): return ""
    match str(card.get("weapon", "")):
        "片手剣":
            if str(card.get("card_type", "")) == "attack":
                return "流転ONで使用：確定したカード側ダメージの50%（切り捨て）をBlockとして追加獲得。使用後、流転OFF。"
            return "流転ONで使用：確定したカード側Blockの50%（切り捨て）を対象敵に追加ダメージ。使用後、流転OFF。"
        "レイピア":
            return "精密ONで使用：攻撃前に対象のBlockがあれば全HitでBlock無視。Blockがなければ攻撃解決後に脆弱1を付与。使用後、精密OFF。"
        "短剣":
            return "連刃ONで使用：攻撃を2Hitにする。2Hit目は1Hit目のBlock適用前ダメージと同値で、追加効果は再実行しない。使用後、連刃OFF。"
        "大剣":
            return "重撃ONで使用：カード側の攻撃ダメージを1.5倍（切り捨て）。使用後、重撃OFF。"
        "魔法剣":
            return "魔導ONで使用：このカードによる属性特性の獲得量を+2する。使用後、魔導OFF。"
        "刀":
            if bool(card.get("execution_on_sheathed", false)):
                return "納刀ONで居合対応カードを使用：Cost0になり、使用後に納刀OFF。攻撃後、対象HPが最大HPの10%以下なら処刑。"
            return "納刀ONで居合対応カードを使用：Cost0になり、使用後に納刀OFF。"
    return ""

static func short_text(card: Dictionary) -> String:
    if not is_applicable(card): return ""
    match str(card.get("weapon", "")):
        "片手剣":
            return "流転ON：追加Block" if str(card.get("card_type", "")) == "attack" else "流転ON：Block→追加ダメージ"
        "レイピア": return "精密ON：Block無視 / 脆弱1"
        "短剣": return "連刃ON：追加1Hit"
        "大剣": return "重撃ON：ダメージ×1.5"
        "魔法剣": return "魔導ON：属性特性獲得+2"
        "刀": return "納刀ON：居合Cost0＋処刑" if bool(card.get("execution_on_sheathed", false)) else "納刀ON：居合Cost0"
    return ""

static func conditional_text(card: Dictionary, currently_on: int = -1) -> String:
    # -1 is outside combat; 0 OFF, 1 ON. No additional text on SET / NEUTRAL.
    if not is_applicable(card): return ""
    var trait_name: String = str(card.get("weapon_trait", WEAPON_TRAITS.get(str(card.get("weapon", "")), "")))
    var status: String = "条件：%s ON" % trait_name
    if currently_on == 0: status += "（現在OFF）"
    elif currently_on == 1: status += "（現在ON・発動可能）"
    if already_in_master(card):
        # Don't repeat the formal Katana text verbatim.
        return "【共通武器特性】" + status + "。詳細は正式本文の居合効果を参照。"
    return "【共通武器特性】" + status + "\n" + effect_text(card)

static func combined_text(card: Dictionary, currently_on: int = -1) -> String:
    var formal: String = str(card.get("text", ""))
    var extra: String = conditional_text(card, currently_on)
    return formal if extra == "" else formal + "\n" + extra

static func conditional_bbcode(card: Dictionary, currently_on: int = -1) -> String:
    var value: String = conditional_text(card, currently_on)
    if value == "": return ""
    # Fixed controlled strings only, never interpolate untrusted BBCode from JSON.
    if currently_on == 1:
        return "[b][color=#ffe59b]★ " + value + "[/color][/b]"
    if currently_on == 0:
        return "[color=#9297a5]◇ " + value + "[/color]"
    return "[color=#b5d8e8]◇ " + value + "[/color]"
