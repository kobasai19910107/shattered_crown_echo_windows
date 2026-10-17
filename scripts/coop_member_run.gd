class_name CoopMemberRun
extends CampaignController

# Member operations are transactions in memory. The party writes one atomic file
# only after both members and the shared encounter have been validated.
func _commit(next: Dictionary, next_battle: BattleController=null) -> bool:
    if save_blocked or not valid_state(next): return false
    state=next
    if next_battle!=null: battle=next_battle
    elif str(state.phase)!="battle": battle=null
    notice=""
    return true
