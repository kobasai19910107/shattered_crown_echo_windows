extends SceneTree
## STEP27: headless verification of the actual STEP20 Godot tweens
## and STEP26 full-height visual layout. Never edits save/Battle Core.
const POSE_SCENE := "res://ui_trial/boss_lab_step20.tscn"
const BATTLE_SCENE := "res://ui_trial/battle_ui_step21_lab.tscn"
const RESULT_FILE := "res://STEP27_QA_RESULTS.json"
const REST_LIMIT := 2.5
var checks: Array[Dictionary] = []
var runtime_errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(name: String, success: bool, detail: String = "") -> void:
    checks.append({"name": name, "passed": success, "detail": detail})
    print(("[PASS] " if success else "[FAIL] ") + name + (" :: " + detail if not detail.is_empty() else ""))

func _approx(label: String, value: float, expected: float, epsilon: float = 0.1) -> void:
    _check(label, absf(value - expected) <= epsilon, "actual=%.3f expected=%.3f" % [value, expected])

func _finish() -> void:
    var all_passed := true
    var count_ok: int = 0
    for item in checks:
        if bool(item["passed"]):
            count_ok += 1
        else:
            all_passed = false
    var result: Dictionary = {
        "schema": 1,
        "project": "shattered_crown_echo",
        "step": "27",
        "runner": "Godot SceneTree / actual Tweens",
        "godot_version": Engine.get_version_info().get("string", "unknown"),
        "run_completed": true,
        "passed": all_passed,
        "checks_passed": count_ok,
        "checks_total": checks.size(),
        "checks": checks,
        "runtime_errors": runtime_errors,
        "note": "Headless logic/layout checks. Visible clipping, appearance and FPS still require a GUI inspection."
    }
    var file := FileAccess.open(RESULT_FILE, FileAccess.WRITE)
    if file == null:
        printerr("[STEP27] Cannot write report to ", RESULT_FILE, ": ", FileAccess.get_open_error())
        all_passed = false
    else:
        file.store_string(JSON.stringify(result, "  "))
        file.close()
        print("[STEP27] Report saved: ", ProjectSettings.globalize_path(RESULT_FILE))
    print("[STEP27] ", "PASS" if all_passed else "FAIL", " ", result["checks_passed"], "/", result["checks_total"])
    quit(0 if all_passed else 1)

func _run() -> void:
    print("[STEP27] Godot ", Engine.get_version_info().get("string", "unknown"))
    var scene: PackedScene = load(POSE_SCENE) as PackedScene
    if scene == null:
        _check("STEP20 scene loading", false, POSE_SCENE)
        _finish()
        return
    var lab: Variant = scene.instantiate()
    if lab == null:
        _check("STEP20 scene instantiation", false)
        _finish()
        return
    root.add_child(lab)
    await process_frame
    _check("STEP20 actor ready", is_instance_valid(lab.boss) and lab.boss._b01_active)
    if not is_instance_valid(lab.boss) or not lab.boss._b01_active:
        _finish()
        return
    _check("STEP20 joint map 13", is_instance_valid(lab.boss) and lab.boss._b01_joints.size() == 13)
    _check("STEP20 STEP19 artwork active", is_instance_valid(lab.boss) and lab.boss._step19_enabled)
    _check("STEP20 coordinate conversion returns nonempty bounds", lab._visual_bounds().size.length() > 0.1)
    _check("STEP20 initial pose rest", lab.boss.position.distance_to(Vector2(839.0, 506.0)) <= REST_LIMIT)
    # 10 repetitions x 3 different actual Godot animations = 30 tween motions.
    lab.speed = 3.0
    await lab._run_motion("stress")
    await process_frame
    _check("STEP20 completed exactly 30 actions", lab.completed == 30, "completed=%d" % lab.completed)
    _check("STEP20 returned within 2.5 tolerance", lab.max_rest_error <= REST_LIMIT, "max_rest_error=%.4f" % lab.max_rest_error)
    _check("STEP20 has no reset issues", lab.issues.is_empty(), "issues=%s" % str(lab.issues))
    _check("STEP20 ends idle and interactive", not lab.busy and lab.boss._busy and lab.slider.editable)
    # Clip warnings are informational and remain part of the saved pose report;
    # for example a large boss may intentionally overlap the world/HUD boundary.
    print("[STEP27] STEP20 bounds warnings: ", lab.clip_warnings)
    var report: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://step20_r1b01_pose_report.json"))
    _check("STEP20 pose report exists", report is Dictionary)
    if report is Dictionary:
        _check("STEP20 pose report counts 30", int(report.get("completed_actions", -1)) == 30)
        _check("STEP20 pose report rest pass", bool(report.get("pass_rest", false)))
    lab.queue_free()
    await process_frame

    var battle_scene: PackedScene = load(BATTLE_SCENE) as PackedScene
    if battle_scene == null:
        _check("STEP21 battle scene loads", false, BATTLE_SCENE)
        _finish()
        return
    var battle: Variant = battle_scene.instantiate()
    if battle == null:
        _check("STEP21 battle scene instantiates", false)
        _finish()
        return
    root.add_child(battle)
    await process_frame
    _check("STEP21 battle core linked", battle.battle != null)
    _check("STEP21 backdrop exists", is_instance_valid(battle.scene_backdrop))
    _check("STEP21 hand UI exists", is_instance_valid(battle.card_layer))
    # Simulate layout in the original design resolution and in 1280x900.
    # This is layout geometry, NOT a screenshot/real-display test.
    battle.size = Vector2(1280, 900)
    battle._scale_stage()
    _approx("1280x900 expansion", battle._vertical_extra, 180.0)
    _approx("1280x900 stage top", battle.stage.position.y, 0.0)
    _approx("1280x900 stage height", battle.stage.size.y, 900.0)
    _approx("1280x900 background height", battle.scene_backdrop.size.y, 900.0)
    _approx("1280x900 hand moves down", battle.card_layer.position.y, 180.0)
    _approx("1280x900 field moves half distance", battle.field_layer.position.y, 90.0)
    _approx("1280x900 cutin moves half distance", battle.cutin.position.y, 90.0)
    battle.size = Vector2(1280, 720)
    battle._scale_stage()
    _approx("1280x720 unchanged reference layout", battle._vertical_extra, 0.0)
    _approx("1280x720 stage height", battle.stage.size.y, 720.0)
    _approx("1280x720 hand at reference", battle.card_layer.position.y, 0.0)
    _approx("1280x720 background height", battle.scene_backdrop.size.y, 720.0)
    battle.queue_free()
    await process_frame
    _finish()
