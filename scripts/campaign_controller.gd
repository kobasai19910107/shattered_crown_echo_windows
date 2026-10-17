class_name CampaignController
extends Region1RunController

const CAMPAIGN_SAVE = "user://campaign_run_v2.json"
var legacy_save_path: String = Region1RunController.SAVE_PATH

func _init() -> void:
    super()
    state.schema_version=2
    state["region_progress"]=[0,0,0,0,0,0]
    state["active_region"]=0
    state["campaign_complete"]=false
    save_path=CAMPAIGN_SAVE

func load_saved() -> bool:
    if FileAccess.file_exists(save_path): return super.load_saved()
    if not FileAccess.file_exists(legacy_save_path): return false
    var legacy=Region1RunController.new()
    legacy.save_path=legacy_save_path
    if not legacy.load_saved():
        save_blocked=true
        notice="旧Region 1保存を検証できません。原本を保持しました。"
        return false
    var migrated: Dictionary=legacy.state.duplicate(true)
    migrated.schema_version=2
    migrated["region_progress"]=[int(migrated.bosses),0,0,0,0,0]
    migrated["active_region"]=0
    migrated["campaign_complete"]=false
    if not migrated.run.is_empty():
        migrated.run["region_id"]="R1"
        if legacy.battle!=null: migrated.run.battle=legacy.battle.export_region1_state()
    return _commit(migrated,legacy.battle)

func valid_state(candidate: Dictionary) -> bool:
    if int(candidate.get("schema_version",0))!=2: return false
    if not candidate.get("region_progress") is Array or candidate.region_progress.size()!=6: return false
    if not candidate.get("run") is Dictionary: return false
    var raw_region = candidate.get("active_region",-1)
    if not (raw_region is int or raw_region is float): return false
    var region: int=int(candidate.get("active_region",-1))
    if region<0 or region>5 or float(raw_region)!=region: return false
    for i in range(6):
        if not (candidate.region_progress[i] is int or candidate.region_progress[i] is float): return false
        var count: int=int(candidate.region_progress[i])
        if count<0 or count>4 or float(candidate.region_progress[i])!=count: return false
        if i>0 and count>0 and int(candidate.region_progress[i-1])!=4: return false
    if region>0 and int(candidate.region_progress[region-1])!=4: return false
    if not candidate.get("campaign_complete") is bool: return false
    if bool(candidate.campaign_complete)!=(int(candidate.region_progress[5])==4): return false
    if int(candidate.get("bosses",-1))!=int(candidate.region_progress[0]): return false
    if not candidate.run.is_empty() and str(candidate.run.get("region_id","R1"))!="R%d"%(region+1): return false
    var compatible: Dictionary=candidate.duplicate(true)
    compatible.schema_version=1
    return super.valid_state(compatible)

func _region_id(candidate: Dictionary) -> String:
    return "R%d" % (int(candidate.active_region)+1)

func _boss_count(candidate: Dictionary) -> int:
    return int(candidate.region_progress[int(candidate.active_region)])

func _record_boss_win(next: Dictionary) -> void:
    # Replaying a cleared Boss awards normal run loot but does NOT advance or
    # rewind the campaign's canonical highest-clear counts.
    if bool(next.run.get("replay_boss",false)): return
    var index: int=int(next.active_region)
    next.region_progress[index]=mini(4,int(next.region_progress[index])+1)
    next.bosses=int(next.region_progress[0])
    next.region2_unlocked=int(next.bosses)==4
    next.campaign_complete=int(next.region_progress[5])==4

func select_region(index: int) -> bool:
    if str(state.phase)!="hub" or not state.forge_pending.is_empty() or index<0 or index>5: return false
    if index>0 and int(state.region_progress[index-1])!=4: return false
    var next: Dictionary=state.duplicate(true)
    next.active_region=index
    return _commit(next)
