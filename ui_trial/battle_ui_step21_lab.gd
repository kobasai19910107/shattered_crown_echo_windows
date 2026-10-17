extends "res://ui_trial/battle_ui_step21.gd"
## A separate, non-saving Battle Core encounter. No campaign rewards.
## The encounter is constructed by the real Region1 enemy catalog,
## not by manually inventing boss HP/damage/intent values.

func _ready() -> void:
    super._ready()
    var trial := BattleController.new()
    # Max out test HP using the real Battle Core clamp; never invent an HP stat.
    # Passing an empty deck invokes the existing prototype deck. The solo
    # campaign continues to use its exact fixed 24-card equipment deck.
    var started: bool = trial.start_region1(20261016, [], ["R1-B01"], {}, 999999, {})
    if not started:
        status.text = "R1-B01の初期化に失敗しました。Battle Coreと敵データを確認してください。"
        return
    if battle != null and battle.presentation_event.is_connected(_capture_event):
        battle.presentation_event.disconnect(_capture_event)
    battle = trial
    battle.presentation_event.connect(_capture_event)
    event_log.clear()
    selected_index = -1
    card_page = 0
    tier = "boss"
    campaign_mode = false
    for mode_button in mode_buttons.values():
        (mode_button as Button).visible = false
    _rebuild_enemy_visuals()
    _refresh_hud()
    status.text = "STEP21テスト：R1-B01 / 公式Battle Core・仮デッキ / 本編セーブなし"
    selection_label.text = "カード→対象選択で使用。敵Intentに応じてR1-B01が突進します。"
