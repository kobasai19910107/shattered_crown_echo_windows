class_name BattleActionJournal
extends RefCounted

# Records confirmed public inputs. It does not change the game's RNG or replay actions.
const MAX_ACTIONS := 600
var identity: Dictionary = {}
var actions: Array[Dictionary] = []

func begin(battle: BattleController) -> void:
    actions.clear()
    identity = {
        "format": "sce_public_action_journal_v1",
        "seed": battle.get_active_seed(),
        "enemy_preset": battle.get_active_enemy_preset(),
        "deck_ids": battle.battle_deck_ids.duplicate(),
        "warning": "Input/action history only. Not a deterministic full-state replay."
    }

func record_action(battle: BattleController, kind: String, card_id: String = "", target: int = -1) -> void:
    if actions.size() >= MAX_ACTIONS: return
    actions.append({
        "step": actions.size(),
        "turn": battle.turn_number,
        "kind": kind,
        "card_id": card_id,
        "target_index": target,
    })

func export_local() -> String:
    if identity.is_empty(): return ""
    var path: String = "user://battle_actions_%d_%d.json" % [int(identity.get("seed", 0)), int(Time.get_unix_time_from_system())]
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_warning("Cannot write action journal: %s" % error_string(FileAccess.get_open_error()))
        return ""
    var payload := identity.duplicate(true)
    payload["actions"] = actions.duplicate(true)
    file.store_string(JSON.stringify(payload, "  "))
    file.close()
    return path
