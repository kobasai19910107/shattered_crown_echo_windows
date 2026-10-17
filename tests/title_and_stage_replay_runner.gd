extends SceneTree

# Safe unit test: uses only test save paths, never the live campaign save.
# godot --headless --path . -s res://tests/title_and_stage_replay_runner.gd
var checks: int = 0
var errors: Array[String] = []

func check(label: String, good: bool) -> void:
    if good:
        checks += 1
    else:
        errors.append(label)
        push_error("FAIL: " + label)

func _initialize() -> void:
    call_deferred("test")

func test() -> void:
    var title := GameTitleScreen.new()
    root.add_child(title)
    title.build(false, "")
    check("first-time Continue disabled", title.resume_button.disabled)
    check("New Game confirmation exists", is_instance_valid(title.new_confirmation))
    title.queue_free()
    await process_frame

    var c := CampaignController.new()
    c.save_path = "user://sce_title_replay_fixture.json"
    var fresh: Dictionary = c.state.duplicate(true)
    check("new campaign is valid", c.valid_state(fresh))
    check("new campaign has no clears", fresh.region_progress == [0,0,0,0,0,0])
    check("fresh state saves", c._commit(fresh))
    check("fresh checkpoint reloads", c.load_saved())

    var fixture=load("res://tests/hub_inventory_analysis_test.gd").new()
    check("initial six equipment", c.adopt_initial(fixture.make_items(c.roller,517901)))
    fixture.free()
    var progressed: Dictionary=c.state.duplicate(true)
    progressed.region_progress=[4,2,0,0,0,0]
    progressed.bosses=4
    progressed.region2_unlocked=true
    progressed.active_region=1
    check("cleared region fixture is valid", c.valid_state(progressed))
    check("clear fixture commit", c._commit(progressed))
    check("select cleared Region1", c.select_region(0))
    check("replay Region1 B01", c.begin(2021891360,1))
    check("replay label stored", bool(c.state.run.get("replay_boss",false)) and int(c.state.run.get("target_boss_number",0))==1)
    check("replay does not rewind clears", c.state.region_progress[0]==4)
    var simulated: Dictionary=c.state.duplicate(true)
    c._record_boss_win(simulated)
    check("replay victory keeps progress", simulated.region_progress==[4,2,0,0,0,0] and int(simulated.bosses)==4)
    check("replay run serializes", c.valid_state(c.state))
    var restored:=CampaignController.new()
    restored.save_path=c.save_path
    check("replay load from save", restored.load_saved() and int(restored.state.run.get("target_boss_number",0))==1)
    var retreat: Dictionary=restored.state.duplicate(true)
    restored._return(retreat,[],false)
    check("test retreat", restored._commit(retreat))
    check("select cleared Region2", restored.select_region(1))
    check("locked B04 rejected", not restored.begin(12345,4))
    check("next B03 allowed", restored.begin(12345,3))
    check("next B03 isn't replay", not bool(restored.state.run.get("replay_boss",true)))
    var future: Dictionary=restored.state.duplicate(true)
    restored._record_boss_win(future)
    check("first-time B03 win increments only Region2", future.region_progress == [4,3,0,0,0,0])

    DirAccess.remove_absolute(ProjectSettings.globalize_path(c.save_path))
    print("TITLE / STAGE REPLAY TEST: %d PASS, %d FAIL"%[checks,errors.size()])
    if not errors.is_empty():print(errors)
    quit(0 if errors.is_empty() else 1)
