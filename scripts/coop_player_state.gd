class_name CoopPlayerState
extends BattleController

# Only cooperative instances defer finalization to the team coordinator.
# The base controller's saved-state property count remains unchanged.
var party = null
var seat: int = 0

func _finalize_battle(code: String, reason: String) -> void:
    var owner = party.get_ref() if party != null else null
    if owner == null:
        super._finalize_battle(code,reason)
    elif code == "ERROR":
        owner.finish(false,reason)

func finalize_team(won: bool, reason: String) -> void:
    super._finalize_battle("VICTORY" if won else "DEFEAT",reason)

func end_player_turn() -> void:
    var owner = party.get_ref() if party != null else null
    if owner == null: super.end_player_turn()
    else: owner.end_turn(seat)
