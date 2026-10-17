extends RefCounted

func get_player_view_models(battle: BattleController, requested_count: int) -> Array[Dictionary]:
    var count: int = int(clamp(requested_count, 1, 3))
    var result: Array[Dictionary] = []
    result.append(_build_primary_player(battle))
    for slot in range(1, count):
        result.append(_build_preview_player(slot))
    return result

func _build_primary_player(battle: BattleController) -> Dictionary:
    var statuses: Array = []
    if battle.swift_cost_reduction_charges > 0:
        statuses.append({
            "name": "疾風Cost軽減",
            "icon": "cost_down",
            "amount": battle.swift_cost_reduction_charges,
            "tooltip": "疾風による次カードCost-1回数 %d" % battle.swift_cost_reduction_charges
        })
    var engine_summary: String = battle.get_continuous_effect_summary()
    if engine_summary != "none" and engine_summary != "":
        statuses.append({"name": "継続効果", "icon": "engine", "amount": 1, "tooltip": "継続効果\n%s" % engine_summary})
    var equipment_summary: String = battle.get_equipment_special_effect_summary()
    if equipment_summary != "none" and equipment_summary != "":
        statuses.append({"name": "装備効果", "icon": "equipment", "amount": 1, "tooltip": "装備効果\n%s" % equipment_summary})

    return {
        "slot": 0,
        "display_name": "P1",
        "active": true,
        "preview_only": false,
        "hp": battle.player_hp,
        "max_hp": battle.player_max_hp,
        "mana": battle.current_mana,
        "base_mana": BattleController.BASE_MANA,
        "block": battle.player_block,
        "weapon": "",
        "weapon_traits": battle.weapon_traits.duplicate(true),
        "attribute_traits": battle.attribute_traits.duplicate(true),
        "statuses": statuses,
        "draw_count": battle.draw_pile.size(),
        "discard_count": battle.discard_pile.size(),
        "exhaust_count": 0
    }

func _build_preview_player(slot: int) -> Dictionary:
    return {
        "slot": slot,
        "display_name": "P%d" % (slot + 1),
        "active": false,
        "preview_only": true,
        "hp": 48,
        "max_hp": 48,
        "mana": 3,
        "base_mana": 3,
        "block": 0,
        "weapon": "—",
        "weapon_traits": {},
        "attribute_traits": {},
        "statuses": [],
        "draw_count": 24,
        "discard_count": 0,
        "exhaust_count": 0
    }

func _infer_primary_weapon(battle: BattleController) -> String:
    if battle.hand.is_empty():
        return ""
    var counts: Dictionary = {}
    for card in battle.hand:
        var weapon: String = str(card.get("weapon", ""))
        if weapon == "":
            continue
        counts[weapon] = int(counts.get(weapon, 0)) + 1
    var best_weapon: String = ""
    var best_count: int = 0
    for raw_weapon in counts.keys():
        var weapon_name: String = str(raw_weapon)
        var amount: int = int(counts.get(weapon_name, 0))
        if amount > best_count:
            best_weapon = weapon_name
            best_count = amount
    return best_weapon
