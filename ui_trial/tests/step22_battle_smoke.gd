extends SceneTree
## STEP22: headless Battle Core + UI smoke test (does not write campaign saves).
## Run with: godot --headless --path PROJECT --script res://ui_trial/tests/step22_battle_smoke.gd

const LAB_PATH := "res://ui_trial/battle_ui_step21_lab.tscn"
const WAIT_LIMIT_MS := 16000
var failures: int = 0
var passes: int = 0
var notes: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _ok(condition: bool, description: String) -> void:
    if condition:
        passes += 1
        print("[PASS] " + description)
    else:
        failures += 1
        push_error("[FAIL] " + description)

func _note(description: String) -> void:
    notes.append(description)
    print("[INFO] " + description)

func _until_not_busy(view: Variant, context: String) -> void:
    var started_ms: int = Time.get_ticks_msec()
    while bool(view.busy) and Time.get_ticks_msec() - started_ms < WAIT_LIMIT_MS:
        await process_frame
    _ok(not bool(view.busy), context + "：演出が制限時間内に終了")

func _until_actor_idle(actor: Variant) -> void:
    var started_ms: int = Time.get_ticks_msec()
    while is_instance_valid(actor) and bool(actor._busy) and Time.get_ticks_msec() - started_ms < WAIT_LIMIT_MS:
        await process_frame
    _ok(is_instance_valid(actor) and not bool(actor._busy), "ボスアニメーションが待機状態へ戻る")

func _run() -> void:
    var packed: PackedScene = load(LAB_PATH)
    if packed == null:
        _ok(false, "STEP21ボス戦シーンを読み込める")
        _finish()
        return
    var view: Variant = packed.instantiate()
    root.add_child(view)
    await process_frame
    await process_frame
    var core: Variant = view.battle
    if core == null:
        _ok(false, "実Battle Coreインスタンスが存在する")
        _finish()
        return

    _ok(str(core.get_enemy(0).get("id", "")) == "R1-B01", "敵IDがR1-B01")
    _ok(core.get_enemy_count() == 1, "実敵データから敵1体を生成")
    _ok(view.tier == "boss", "ボス専用レイアウト")
    _ok(view.actors.size() == 1, "敵表示の個数がBattle Coreと一致")
    var boss: Variant = view.actors[0] if view.actors.size() == 1 else null
    _ok(boss != null and boss.has_method("play_attack") and boss.has_method("play_roar"), "ボスの突進・咆哮モーションが利用可能")
    _ok(boss != null and boss.get_script().resource_path.ends_with("boss_b01_rig_step19.gd"), "R1-B01専用13パーツリグが接続済み")
    _ok(core.get_enemy_intent_display_label(0) != "-", "実Intentが表示可能")
    _ok(core.hand.size() > 0, "公式デッキから手札を取得")
    if core.hand.is_empty():
        _finish()
        return

    # Selecting a card must be a read-only UI operation (no card/mana/HP cost).
    var candidate: int = -1
    for i in range(core.hand.size()):
        if core.can_use_card(i) and core.get_effective_target_type(i) == "enemy":
            candidate = i
            break
    if candidate < 0:
        for i in range(core.hand.size()):
            if core.can_use_card(i):
                candidate = i
                break
    if candidate >= 0:
        var before_snapshot: String = JSON.stringify(core.export_region1_state())
        var used_before: int = int(core.playtest_stats.get("cards_used", 0))
        var target_type: String = core.get_effective_target_type(candidate)
        view.card_page = candidate / 5
        view._card_pressed(candidate % 5)
        await process_frame
        _ok(view.selected_index == candidate, "カード選択操作が成立")
        _ok(JSON.stringify(core.export_region1_state()) == before_snapshot, "選択だけではHP/Mana/山札などBattle Coreが変化しない")
        if target_type == "enemy":
            view._enemy_pressed(0)
        else:
            view._card_pressed(candidate % 5)
        await _until_not_busy(view, "カード使用")
        # The UI can create a follow-up discard/bottom/salvage selection.
        _ok(int(core.playtest_stats.get("cards_used", 0)) == used_before + 1, "カード使用がBattle Coreでちょうど1回発生")
        _ok(view.actors.size() == core.get_enemy_count(), "カード使用後も敵数と表示数が一致")
        if core.is_salvage_selection_active():
            var choices: Array[int] = core.get_salvage_selectable_indices()
            if not choices.is_empty():
                core.select_discard_for_pending(choices[0])
        var safety: int = 0
        while core.is_hand_selection_active() and not core.is_salvage_selection_active() and safety < 12 and core.hand.size() > 0:
            if not core.select_hand_for_pending(0):
                break
            safety += 1
        _note("カード使用後のMana=%d、HP=%d、敵HP=%d" % [core.current_mana, core.player_hp, int(core.get_enemy(0).get("hp", 0))])
    else:
        _note("初期手札に使用可能カードなし：カード試験はスキップ")

    # Enemy turn is driven by the real BattleController, not by animation.
    if not core.combat_over and not core.is_hand_selection_active():
        view.selected_index = -1
        var turn_before: int = core.turn_number
        var events_before: int = view.event_log.size()
        view._end_turn()
        await _until_not_busy(view, "敵ターン")
        var new_events: Array = view.event_log.slice(events_before)
        var enemy_actions: int = 0
        for event in new_events:
            if str(event.get("kind", "")) == "enemy_action":
                enemy_actions += 1
        _ok(enemy_actions > 0 or core.combat_over, "敵行動イベントをBattle Coreから受信")
        _ok(core.turn_number > turn_before or core.combat_over, "ターン進行または勝敗が確定")
        _note("敵行動イベント=%d、ターン=%d、プレイヤーHP=%d" % [enemy_actions, core.turn_number, core.player_hp])
    else:
        _note("状態により敵ターン試験をスキップ（戦闘終了または手札選択継続）")

    # Direct animation QA after actual battle events. No gameplay method is called.
    if boss != null and is_instance_valid(boss) and boss.has_method("set_rest_position"):
        # A fire-and-forget hit animation may still be active when card UI unlocks.
        await _until_actor_idle(boss)
        # The actor is allowed to use the same rest point as the stage renderer.
        var initial_position: Vector2 = boss.position
        await boss.play_roar(3.0)
        _ok(boss.position.distance_to(initial_position) <= 0.5, "咆哮後の表示位置復帰誤差が0.5px以下")
        await boss.play_attack(3.0)
        _ok(boss.position.distance_to(initial_position) <= 0.5, "突進後の表示位置復帰誤差が0.5px以下")
        await boss.play_hit(3.0)
        _ok(boss.position.distance_to(initial_position) <= 0.5, "被弾後の表示位置復帰誤差が0.5px以下")
    _finish()

func _finish() -> void:
    print("STEP22 RESULT: PASS=%d FAIL=%d" % [passes, failures])
    for note in notes:
        print("STEP22 NOTE: " + note)
    print("STEP22 LIMITATION: --headless cannot visually certify sprites, hit positions, or iPhone layout")
    quit(1 if failures > 0 else 0)
