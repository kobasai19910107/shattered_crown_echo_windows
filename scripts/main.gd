extends Control

const CardValidationRunnerScript = preload("res://scripts/card_validation_runner.gd")
const BattleSimulationRunnerScript = preload("res://scripts/battle_simulation_runner.gd")
const PlaytestTelemetryRunnerScript = preload("res://scripts/playtest_telemetry_runner.gd")
const LoadoutValidationRunnerScript = preload("res://scripts/loadout_validation_runner.gd")
const BattleCoreRegressionRunnerScript = preload("res://scripts/battle_core_regression_runner.gd")
const BattleResultValidationRunnerScript = preload("res://scripts/battle_result_validation_runner.gd")
const PlaytestCardButtonScript = preload("res://scripts/playtest_card_button.gd")
const UXPrefsScript = preload("res://scripts/battle_ux_preferences.gd")
const UIAudioScript = preload("res://scripts/battle_ui_audio.gd")
# STEP2: 3H visual bridge (presentation only)
const Battle3HBridgeScript = preload("res://ui_trial/live_bridge.gd")
const ActionJournalScript = preload("res://scripts/battle_action_journal.gd")
const PlayerHudPanelScript = preload("res://scripts/player_hud_panel.gd")
const BattleHudAdapterScript = preload("res://scripts/battle_hud_adapter.gd")
const Step8RollerScript = preload("res://scripts/step8_equipment_roller.gd")
const InitialDeckGeneratorScript = preload("res://scripts/initial_deck_generator.gd")
const InitialDeckGenerationJobScript = preload("res://scripts/initial_deck_generation_job.gd")
const GameTitleScreenScript = preload("res://scripts/game_title_screen.gd")

const ATTRIBUTES := ["ALL", "物理", "炎", "水", "雷", "地", "光", "闇", "毒", "秘術", "風"]
const WEAPONS := ["ALL", "片手剣", "レイピア", "短剣", "大剣", "魔法剣", "刀"]
const ROLES := ["ALL", "基本攻撃", "基本防御", "特性生成", "特性利用", "手札循環", "補助", "継続効果", "決着技"]

var battle: BattleController
var deck_builder: DeckBuilder
var loadout_builder: LoadoutBuilder
var selected_hand_index: int = -1
var current_battle_deck_ids: Array[String] = []
var current_enemy_preset: String = "slime_duo"
var pending_loadout_snapshot: Dictionary = {}
var current_loadout_snapshot: Dictionary = {}
var tab_container: TabContainer

var player_label: Label
var piles_label: Label
var trait_label: Label
var notice_label: Label
var enemy_box: GridContainer
var enemy_scroll: ScrollContainer
var enemy_buttons: Array[Button] = []
var selection_label: Label
var use_button: Button
var cancel_button: Button
var end_turn_button: Button
var restart_button: Button
var preview_enemy_index: int=-1
var hovered_enemy_index: int=-1
var hand_box: Control
var log_box: RichTextLabel
var result_label: Label
var pile_view: RichTextLabel
var debug_buttons: Array[Button] = []
var card_id_input: LineEdit
var validation_view: RichTextLabel
var seed_input: SpinBox
var developer_panel: VBoxContainer
var developer_toggle: CheckButton
var log_panel: VBoxContainer
var log_toggle: CheckButton

# v1.7.0 variable 1-3 player HUD + stable prediction + weapon-trait ON/OFF
var battle_hud_adapter
var hud_player_count: int = 1
var player_sidebar: VBoxContainer
var player_hud_panels: Array = []
var hud_count_option: OptionButton
var hovered_hand_index: int = -1
var hover_candidate_index: int = -1
var hover_preview_timer: Timer
var hover_clear_timer: Timer
var prediction_panel: PanelContainer
var prediction_label: Label

# v1.6.5 compact game-like HUD
var player_status_box: HBoxContainer
var player_hp_button: Button
var player_mana_button: Button
var player_block_button: Button
var draw_pile_button: Button
var discard_pile_button: Button
var exhaust_pile_button: Button
var enemy_status_boxes: Array[HBoxContainer] = []
var icon_cache: Dictionary = {}
var battle_title_label: Label
var battle_subtitle_label: Label
var battle_dev_button: Button
var battle_log_button: Button

# v1.6.7 Slay-the-Spire-like hand interaction
var drag_hand_index: int = -1
var drag_start_global_position: Vector2 = Vector2.ZERO
var drag_last_global_position: Vector2 = Vector2.ZERO
var drag_active: bool = false

# v1.6.7 dedicated pile/detail screen
var pile_overlay: PanelContainer
var pile_overlay_title: Label
var pile_overlay_subtitle: Label
var pile_overlay_grid: GridContainer
var pile_overlay_empty: Label
var pile_overlay_close: Button

# v1.6 playable vertical-slice HUD
var player_hp_bar: ProgressBar
var mana_bar: ProgressBar
var battle_state_label: Label
var selected_card_view: RichTextLabel
var outcome_panel: PanelContainer
var outcome_label: Label
var return_setup_button: Button

# v1.6 setup / card browser UI
var setup_card_list: ItemList
var setup_deck_list: ItemList
var setup_card_detail: RichTextLabel
var setup_status_label: Label
var setup_search_input: LineEdit
var setup_attribute_filter: OptionButton
var setup_weapon_filter: OptionButton
var setup_role_filter: OptionButton
var setup_enemy_preset: OptionButton
var setup_seed_input: SpinBox
var setup_start_button: Button
var setup_selected_card_id: String = ""
var setup_enemy_preset_ids: Array[String] = []

# v1.6 playtest telemetry UI
var playtest_view: RichTextLabel
var playtest_status_label: Label
var playtest_save_button: Button

# v1.6 equipment loadout + HP + rarity/special-effect UI
var loadout_selectors: Dictionary = {}
var loadout_selector_item_ids: Dictionary = {}
var loadout_status_label: Label
var loadout_preview: RichTextLabel
var loadout_validation_view: RichTextLabel

# STEP8: Equipment 120 roll screen (separate from historical prototype selector).
var step8_roller
var step8_template_selectors: Dictionary = {}
var step8_template_ids: Dictionary = {}
var step8_seed_input: SpinBox
var step8_preview: RichTextLabel
var step8_status: Label
var step8_tab_index: int = 0
var step8_items: Dictionary = {}
const STEP8_SAVE_PATH := "user://step8_minted_items.json"
var step8_save_path: String = STEP8_SAVE_PATH
var generation_job
# Only an explicit click on the hub free-claim button enables auto-adoption.
var initial_claim_after_generation: bool = false
var generation_cancel_button: Button
var generation_locked_controls: Dictionary = {}
var region_run_ui: Region1RunUI
var game_title_screen: GameTitleScreen
var coop_ui: CoopLobbyUI
var auto_battle_button: CheckButton
var auto_battle_enabled: bool = false
var auto_battle_policy: AutoBattlePolicy
var auto_battle_source: BattleController
var auto_battle_executing: bool = false
var auto_battle_next_ms: int = 0
var battle_presentation: BattlePresentation
var battle_3h_bridge: Control
var presentation_source: BattleController
var ux_preferences
var battle_audio
var action_journal
var turn_feedback_label: Label
var _turn_feedback_id: int = -1
var _turn_start_damage: int = 0
var _turn_start_heal: int = 0
var _turn_start_cards: int = 0
var _last_feedback_cards: int = 0

func _watch_presentation() -> void:
    if presentation_source == battle or battle_presentation == null:return
    if is_instance_valid(presentation_source) and presentation_source.presentation_event.is_connected(battle_presentation.capture):
        presentation_source.presentation_event.disconnect(battle_presentation.capture)
    if is_instance_valid(presentation_source) and presentation_source.presentation_event.is_connected(_on_presentation_sound):
        presentation_source.presentation_event.disconnect(_on_presentation_sound)
    battle_presentation.clear_effects()
    presentation_source=battle
    _turn_feedback_id = -1
    if action_journal != null and battle != null: action_journal.begin(battle)
    if battle != null:
        battle.presentation_event.connect(battle_presentation.capture)
        battle.presentation_event.connect(_on_presentation_sound)

func _on_presentation_sound(event: Dictionary) -> void:
    if battle_audio == null: return
    match str(event.get("kind", "")):
        "enemy_hit":
            battle_audio.play_cue("block" if int(event.get("hp_loss", 0)) == 0 else "hit")
        "player_hit":
            battle_audio.play_cue("block" if int(event.get("hp_loss", 0)) == 0 else "hit")
        "execution": battle_audio.play_cue("finisher")
        "resource":
            if str(event.get("resource", "")) == "healing_done": battle_audio.play_cue("heal")
        "log":
            if str(event.get("message", "")).contains("ON consumed"): battle_audio.play_cue("combo")

func _refresh_turn_feedback() -> void:
    if turn_feedback_label == null or battle == null: return
    var stats: Dictionary = battle.playtest_stats
    var used: int = int(stats.get("cards_used", 0))
    if _turn_feedback_id != battle.turn_number or used < _last_feedback_cards:
        _turn_feedback_id = battle.turn_number
        _turn_start_damage = int(stats.get("damage_dealt", 0))
        _turn_start_heal = int(stats.get("healing_done", 0))
        _turn_start_cards = used
    _last_feedback_cards = used
    var cards: int = maxi(0, used - _turn_start_cards)
    var damage: int = maxi(0, int(stats.get("damage_dealt", 0)) - _turn_start_damage)
    var healing: int = maxi(0, int(stats.get("healing_done", 0)) - _turn_start_heal)
    turn_feedback_label.text = "このターン  使用 %d枚  ｜  与ダメ %d  ｜  回復 %d  ｜  連続使用 %d" % [cards, damage, healing, cards]
    turn_feedback_label.tooltip_text = "連続使用は演出用の枚数表示です。戦闘補正はありません。"

func _on_vfx_quality_changed(index: int) -> void:
    BattlePresentation.quality = 2 - index
    ux_preferences.vfx_quality = BattlePresentation.quality
    ux_preferences.save_local()
    battle_presentation.clear_effects()

func _on_vfx_speed_changed(index: int) -> void:
    ux_preferences.speed = index + 1
    ux_preferences.save_local()
    battle_presentation.speed_multiplier = float(ux_preferences.speed)

func _open_audio_settings() -> void:
    if ux_preferences == null: return
    var popup := PopupPanel.new()
    add_child(popup)
    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(300, 0)
    panel.add_theme_constant_override("separation", 9)
    popup.add_child(panel)
    var heading := Label.new()
    heading.text = "戦闘サウンド設定（このPCに保存）"
    panel.add_child(heading)
    for kind in ["ui", "sfx", "bgm"]:
        var row := HBoxContainer.new()
        panel.add_child(row)
        var caption := Label.new()
        caption.text = {"ui": "UI音", "sfx": "戦闘SE", "bgm": "BGM（将来対応）"}[kind]
        caption.custom_minimum_size.x = 130
        row.add_child(caption)
        var slider := HSlider.new()
        slider.min_value = 0.0
        slider.max_value = 1.0
        slider.step = 0.05
        slider.value = float(ux_preferences.get(kind + "_volume"))
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slider.value_changed.connect(_on_audio_level_changed.bind(kind))
        row.add_child(slider)
    popup.popup_centered(Vector2i(340, 190))

func _on_audio_level_changed(value: float, kind: String) -> void:
    if ux_preferences == null: return
    ux_preferences.set(kind + "_volume", value)
    ux_preferences.save_local()
    if battle_audio != null: battle_audio.set_levels(ux_preferences.ui_volume, ux_preferences.sfx_volume, ux_preferences.bgm_volume)

func _visual_snapshot() -> Dictionary:
    _watch_presentation()
    var visible_status: Dictionary=battle.region1_player_status.duplicate(true);visible_status.merge(battle.campaign_status,true)
    return {"enemies":battle.enemies.duplicate(true),"hp":battle.player_hp,"block":battle.player_block,"mana":battle.current_mana,
        "weapon_traits":battle.weapon_traits.duplicate(true),"attribute_traits":battle.attribute_traits.duplicate(true),"status":visible_status}

func _visual_enemy_points() -> Array:
    var points: Array = []
    for enemy in enemy_buttons: points.append(enemy.get_global_rect().get_center()-global_position)
    return points

func _visual_changes(before: Dictionary, points: Array, source: Vector2) -> void:
    if battle_presentation != null:
        var piles: Dictionary={}
        if not player_hud_panels.is_empty():
            piles.draw=player_hud_panels[0]._draw_button.get_global_rect().get_center()-global_position
            piles.discard=player_hud_panels[0]._discard_button.get_global_rect().get_center()-global_position
        battle_presentation.show_changes(before,_visual_snapshot(),points,_visual_player_point(),source,enemy_buttons,piles)
        var activated: Array=[]
        for event in battle_presentation.last_events:
            if str(event.kind)=="log" and str(event.message).contains("ON consumed"):
                activated.append(str(event.message).split("ON consumed")[0])
        _pulse_weapon_icons.call_deferred(activated)

func _pulse_weapon_icons(names: Array) -> void:
    if player_hud_panels.is_empty():return
    var grid=player_hud_panels[0]._traits_grid
    for trait_name in names:
        var index: int=["流転","精密","連刃","重撃","魔導","納刀"].find(trait_name)
        if index>=0 and index<grid.get_child_count():battle_presentation.flash(grid.get_child(index))


func _visual_player_point() -> Vector2:
    return player_hud_panels[0].get_global_rect().get_center()-global_position if not player_hud_panels.is_empty() else Vector2(160,160)

func _on_auto_battle_toggled(enabled: bool) -> void:
    auto_battle_enabled = enabled
    auto_battle_policy = null
    selected_hand_index = -1
    _reset_drag_state(false)
    _refresh_ui()

func _auto_input_locked() -> bool:
    return auto_battle_enabled and not auto_battle_executing

func _auto_battle_tick() -> void:
    if not auto_battle_enabled or battle == null: return
    if battle.combat_over:
        auto_battle_enabled = false
        auto_battle_policy = null
        auto_battle_button.set_pressed_no_signal(false)
        return
    if generation_job != null or Time.get_ticks_msec() < auto_battle_next_ms: return
    if region_run_ui != null and region_run_ui.animation_busy: return
    if auto_battle_policy == null or auto_battle_source != battle:
        auto_battle_source = battle
        auto_battle_policy = AutoBattlePolicy.new()
        auto_battle_policy.begin(battle)
    auto_battle_policy.step(4.0)
    if not auto_battle_policy.done: return
    var action: Dictionary = auto_battle_policy.result
    auto_battle_policy = null
    if action.is_empty():
        auto_battle_button.set_pressed_no_signal(false)
        _on_auto_battle_toggled(false)
        return
    auto_battle_executing = true
    match str(action.kind):
        "card":
            selected_hand_index = int(action.index)
            _confirm_selected_card(int(action.target))
        "select": _on_card_pressed(int(action.index))
        "salvage": _on_salvage_choice(int(action.index))
        "end": _on_end_turn_pressed()
    auto_battle_executing = false
    auto_battle_next_ms = Time.get_ticks_msec()+300

func _process(_delta: float) -> void:
    _auto_battle_tick()
    if generation_job == null:
        return
    var state: Dictionary = generation_job.poll()
    if not state.done:
        step8_status.text = "装備生成中: %s" % state.progress
        # The separate STEP8 tab is hidden during a hub-initiated claim.
        # Show the real asynchronous progress on the hub instead of appearing frozen.
        if initial_claim_after_generation and is_instance_valid(region_run_ui.hub_notice):
            region_run_ui.hub_notice.text = "初期6装備を生成中: %s" % str(state.progress)
            region_run_ui.hub_notice.visible = true
        return
    var claim_after_generation: bool = initial_claim_after_generation
    initial_claim_after_generation = false
    generation_job = null
    _set_generation_busy(false)
    if state.cancelled:
        step8_status.text = "生成を取り消しました。現在の装備は保持されます。"
        if claim_after_generation:
            region_run_ui.run.notice = "初期装備の生成を取り消しました。装備は受け取っていません。"
            region_run_ui.render()
        return
    _step8_commit_generated(state.result)
    if claim_after_generation:
        if bool(state.result.get("ok", false)) and step8_items.size() == 6:
            _finish_hub_initial_claim()
        else:
            region_run_ui.run.notice = "初期6装備の生成・検証に失敗しました。%s　装備生成画面で別のSeedを試してください。" % step8_status.text
        region_run_ui.render()

func _exit_tree() -> void:
    if generation_job != null:
        generation_job.cancel()
        generation_job.join()
        generation_job = null

func _lock_generation_controls(node: Node) -> void:
    if node == generation_cancel_button:
        return
    if node is SpinBox:
        generation_locked_controls[node] = node.editable
        node.editable = false
    elif node is BaseButton:
        generation_locked_controls[node] = node.disabled
        node.disabled = true
    elif node is LineEdit:
        generation_locked_controls[node] = node.editable
        node.editable = false
    for child in node.get_children():
        _lock_generation_controls(child)

func _set_generation_busy(busy: bool) -> void:
    if busy:
        _lock_generation_controls(self)
    else:
        for control in generation_locked_controls:
            if is_instance_valid(control):
                if control is SpinBox:
                    control.editable = generation_locked_controls[control]
                elif control is BaseButton:
                    control.disabled = generation_locked_controls[control]
                elif control is LineEdit:
                    control.editable = generation_locked_controls[control]
        generation_locked_controls.clear()
    if generation_cancel_button != null:
        generation_cancel_button.disabled = not busy

func _cancel_generation() -> void:
    if generation_job != null:
        generation_job.cancel()

func _ready() -> void:
    ux_preferences = UXPrefsScript.new()
    ux_preferences.load_local()
    BattlePresentation.quality = ux_preferences.vfx_quality
    battle_presentation = BattlePresentation.new()
    battle_presentation.speed_multiplier = float(ux_preferences.speed)
    add_child(battle_presentation)
    battle_audio = UIAudioScript.new()
    add_child(battle_audio)
    battle_audio.set_levels(ux_preferences.ui_volume, ux_preferences.sfx_volume, ux_preferences.bgm_volume)
    action_journal = ActionJournalScript.new()
    deck_builder = DeckBuilder.new()
    if not deck_builder.load_data():
        push_error("DeckBuilder could not load card data.")
    deck_builder.load_prototype_deck()
    loadout_builder = LoadoutBuilder.new()
    if not loadout_builder.load_data():
        push_error("LoadoutBuilder could not load equipment data.")
    loadout_builder.load_prototype_loadout()
    step8_roller = Step8RollerScript.new()
    if not step8_roller.load_data():
        push_error("STEP8 108 equipment roll policy failed to load.")
    else:
        if step8_save_path==STEP8_SAVE_PATH and FileAccess.file_exists("user://initial_equipment_v1.json"):
            step8_save_path="user://initial_equipment_v1.json"
        _step8_restore_items()
        if step8_save_path==STEP8_SAVE_PATH: step8_save_path="user://initial_equipment_v1.json"
    battle_hud_adapter = BattleHudAdapterScript.new()

    _build_ui()
    _setup_hover_preview_timers()
    battle = BattleController.new()
    current_battle_deck_ids = deck_builder.get_deck_ids()
    current_enemy_preset = "slime_duo"
    battle.start_battle(1001, current_battle_deck_ids, current_enemy_preset, current_loadout_snapshot)
    _rebuild_enemy_buttons()
    _refresh_setup_ui()
    _refresh_loadout_ui()
    _refresh_ui()

    region_run_ui=CampaignUI.new()
    tab_container.add_child(region_run_ui)
    region_run_ui.build(self)
    coop_ui=CoopLobbyUI.new()
    tab_container.add_child(coop_ui)
    coop_ui.build(self)
    if str(region_run_ui.run.state.phase)!="battle": tab_container.current_tab=region_run_ui.get_index()
    _show_title_screen()

# Title is a non-destructive overlay. The existing campaign controller still
# handles load, migration, combat checkpoints, and the save envelope.
func _show_title_screen() -> void:
    if is_instance_valid(game_title_screen):
        game_title_screen.queue_free()
    # Hide all battle pages before the title is shown. Enemy Sprite2D parts
    # have positive z_index and otherwise can draw above the title backdrop.
    if is_instance_valid(tab_container):
        tab_container.hide()
    if is_instance_valid(battle_presentation):
        battle_presentation.clear_effects()
    game_title_screen=GameTitleScreenScript.new()
    add_child(game_title_screen)
    # Keep title above other standalone overlays, including the pile browser.
    game_title_screen.z_index = 200
    game_title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var campaign: CampaignController=region_run_ui.run as CampaignController
    var saved: bool=FileAccess.file_exists(campaign.save_path) or FileAccess.file_exists(campaign.legacy_save_path)
    var valid_saved: bool=saved and not campaign.save_blocked
    # Check the actual persisted envelope, not just the in-memory default state.
    # Legacy saves are migrated by Region1RunUI.build before title creation.
    if valid_saved:
        # CampaignUI already restored the validated in-memory checkpoint and
        # normalized legacy Common sockets. Raw legacy JSON is not the canonical
        # shape until its migration is complete.
        valid_saved=campaign.valid_state(campaign.state)
    var summary: String=""
    if saved and not valid_saved:
        summary="保存データを読み込めません。原本は保護しています。最初から始める場合もバックアップを作成します。"
    elif valid_saved:
        var progress: Array=campaign.state.get("region_progress",[0,0,0,0,0,0])
        var cleared: int=0
        for value in progress:cleared+=int(value)
        summary="保存済み：Region %d / Boss %d/24　現在：%s"%[int(campaign.state.get("active_region",0))+1,cleared,str(campaign.state.get("phase","hub"))]
    game_title_screen.build(valid_saved,summary,saved)
    game_title_screen.continue_requested.connect(_continue_from_title)
    game_title_screen.new_game_requested.connect(_start_from_title)
    game_title_screen.exit_requested.connect(func():get_tree().quit())

func _hide_title_screen() -> void:
    if is_instance_valid(game_title_screen):
        game_title_screen.queue_free()
        game_title_screen=null
    # Resume the existing pages without re-creating BattleController or saves.
    if is_instance_valid(tab_container):
        tab_container.show()

func _continue_from_title() -> void:
    if region_run_ui==null:return
    var campaign: CampaignController=region_run_ui.run as CampaignController
    if campaign.save_blocked:
        game_title_screen.set_message("保存データが不正です。読み込みを中止しました。")
        return
    # Reload at selection time so that Continue always uses the latest
    # successfully committed state and resumes an unfinished battle or run.
    if not campaign.load_saved():
        game_title_screen.set_message("セーブの再読込に失敗しました。元データは変更していません。")
        return
    _hide_title_screen()
    region_run_ui.hub_page="home"
    region_run_ui.solo_selected_stage=0
    region_run_ui.render()
    if str(campaign.state.phase)=="battle":
        region_run_ui.present_battle()
    else:
        tab_container.current_tab=region_run_ui.get_index()

func _start_from_title() -> void:
    if region_run_ui==null:return
    var existing: CampaignController=region_run_ui.run as CampaignController
    var save_file: String=existing.save_path
    if FileAccess.file_exists(save_file):
        # A new game is destructive. Keep a raw copy of the original envelope
        # (even if it is corrupted) before writing a fresh campaign.
        var stamp: String=str(int(Time.get_unix_time_from_system()*1000.0))
        var backup: String="user://campaign_run_v2_before_new_game_%s.json"%stamp
        var number: int=1
        while FileAccess.file_exists(backup):
            backup="user://campaign_run_v2_before_new_game_%s_%d.json"%[stamp,number]
            number+=1
        if DirAccess.copy_absolute(ProjectSettings.globalize_path(save_file),ProjectSettings.globalize_path(backup))!=OK:
            game_title_screen.set_message("バックアップに失敗しました。セーブは変更していません。")
            return
    # Legacy region1_run_v1.json is never modified. A fresh campaign save
    # takes precedence over legacy migration on all later launches.
    var fresh:=CampaignController.new()
    if not fresh.valid_state(fresh.state) or not fresh._commit(fresh.state.duplicate(true)):
        game_title_screen.set_message("新規セーブの作成に失敗しました。元データはバックアップ済みです。")
        return
    region_run_ui.run=fresh
    # Do not reuse a previous campaign's unclaimed initial equipment preview.
    step8_items.clear()
    initial_claim_after_generation = false
    region_run_ui.hub_page="home"
    region_run_ui.hub_library_tab=0
    region_run_ui.hub_selected_uid=""
    region_run_ui.solo_selected_stage=0
    region_run_ui.render()
    _hide_title_screen()
    tab_container.current_tab=region_run_ui.get_index()

func _on_online_open() -> void:
    if generation_job!=null: return
    _on_auto_battle_toggled(false)
    if coop_ui!=null: tab_container.current_tab=coop_ui.get_index()

func _setup_hover_preview_timers() -> void:
    hover_preview_timer = Timer.new()
    hover_preview_timer.one_shot = true
    hover_preview_timer.wait_time = 0.22
    hover_preview_timer.timeout.connect(_commit_hover_preview)
    add_child(hover_preview_timer)

    hover_clear_timer = Timer.new()
    hover_clear_timer.one_shot = true
    hover_clear_timer.wait_time = 0.12
    hover_clear_timer.timeout.connect(_clear_hover_preview_delayed)
    add_child(hover_clear_timer)

func _build_ui() -> void:
    var margin = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)

    tab_container = TabContainer.new()
    tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tab_container.tabs_visible = false
    tab_container.tab_changed.connect(func(_index):
        battle_presentation.clear_effects()
        if coop_ui!=null and coop_ui.presentation!=null:coop_ui.presentation.clear_effects())
    margin.add_child(tab_container)

    var battle_scroll = VBoxContainer.new()
    battle_scroll.name = "Battle"
    tab_container.add_child(battle_scroll)

    var root = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 10)
    battle_scroll.add_child(root)

    # v1.6.8: compact game-like battle header based on the earlier prototype screens.
    var header = HBoxContainer.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_theme_constant_override("separation", 8)
    root.add_child(header)

    var setup_button = Button.new()
    var region_button=Button.new()
    region_button.text="Region / 拠点"
    region_button.pressed.connect(func():
        if region_run_ui!=null:
            region_run_ui.sync_battle()
            region_run_ui.render()
            tab_container.current_tab=region_run_ui.get_index())
    header.add_child(region_button)
    var online_button=Button.new()
    online_button.text="オンライン協力"
    online_button.pressed.connect(_on_online_open)
    header.add_child(online_button)
    setup_button.text = "設定"
    setup_button.add_to_group("sce_developer_navigation")
    setup_button.pressed.connect(_on_return_to_setup_pressed)
    header.add_child(setup_button)

    var loadout_button = Button.new()
    loadout_button.text = "装備"
    loadout_button.add_to_group("sce_developer_navigation")
    loadout_button.pressed.connect(_on_open_loadout_pressed)
    header.add_child(loadout_button)

    var roll_button = Button.new()
    roll_button.text = "120装備抽選"
    roll_button.add_to_group("sce_developer_navigation")
    roll_button.pressed.connect(_on_step8_open)
    header.add_child(roll_button)

    var playtest_button = Button.new()
    playtest_button.text = "記録"
    playtest_button.pressed.connect(_on_open_playtest_pressed)
    header.add_child(playtest_button)

    var header_spacer_left = Control.new()
    header_spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(header_spacer_left)

    battle_title_label = Label.new()
    battle_title_label.text = "模擬戦闘"
    battle_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    battle_title_label.add_theme_font_size_override("font_size", 25)
    battle_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(battle_title_label)

    var header_spacer_right = Control.new()
    header_spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(header_spacer_right)

    battle_dev_button = Button.new()
    battle_dev_button.text = "開発"
    battle_dev_button.pressed.connect(_on_battle_dev_button_pressed)
    header.add_child(battle_dev_button)

    battle_log_button = Button.new()
    battle_log_button.text = "ログ"
    battle_log_button.pressed.connect(_on_battle_log_button_pressed)
    header.add_child(battle_log_button)

    battle_state_label = Label.new()
    battle_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    battle_state_label.custom_minimum_size = Vector2(90, 0)
    header.add_child(battle_state_label)

    battle_subtitle_label = Label.new()
    battle_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    battle_subtitle_label.add_theme_font_size_override("font_size", 12)
    root.add_child(battle_subtitle_label)
    piles_label = battle_subtitle_label

    # v1.6.9: one battle layout for 1-3 players. Player HUDs stay on the left;
    # enemies / preview / active player hand stay in the right combat column.
    var battle_body = HBoxContainer.new()
    battle_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    battle_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    battle_body.custom_minimum_size = Vector2(0, 0)
    battle_body.add_theme_constant_override("separation", 12)
    root.add_child(battle_body)

    var sidebar_panel = PanelContainer.new()
    sidebar_panel.custom_minimum_size = Vector2(304, 0)
    sidebar_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    battle_body.add_child(sidebar_panel)

    var sidebar_margin = MarginContainer.new()
    sidebar_margin.add_theme_constant_override("margin_left", 4)
    sidebar_margin.add_theme_constant_override("margin_top", 4)
    sidebar_margin.add_theme_constant_override("margin_right", 4)
    sidebar_margin.add_theme_constant_override("margin_bottom", 4)
    sidebar_panel.add_child(sidebar_margin)

    player_sidebar = VBoxContainer.new()
    player_sidebar.add_theme_constant_override("separation", 8)
    sidebar_margin.add_child(player_sidebar)

    for slot in range(3):
        var hud = PlayerHudPanelScript.new()
        hud.visible = slot < hud_player_count
        hud.pile_requested.connect(_on_player_pile_requested)
        player_sidebar.add_child(hud)
        player_hud_panels.append(hud)

    var sidebar_spacer = Control.new()
    sidebar_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    player_sidebar.add_child(sidebar_spacer)

    var combat_column = VBoxContainer.new()
    combat_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    combat_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    combat_column.add_theme_constant_override("separation", 8)
    battle_body.add_child(combat_column)

    # STEP2: visually follows the existing card/enemy events; never intercepts taps.
    battle_3h_bridge = Battle3HBridgeScript.new()
    battle_3h_bridge.name = "Battle3HLiveBridge"
    battle_3h_bridge.custom_minimum_size = Vector2(0, 148 if OS.has_feature("web") else 172)
    combat_column.add_child(battle_3h_bridge)

    enemy_scroll = ScrollContainer.new()
    enemy_scroll.custom_minimum_size = Vector2(0, 210)
    enemy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enemy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    enemy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    combat_column.add_child(enemy_scroll)
    enemy_box = GridContainer.new()
    enemy_box.columns = 3
    enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enemy_box.add_theme_constant_override("h_separation", 12)
    enemy_scroll.add_child(enemy_box)

    result_label = Label.new()
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.add_theme_font_size_override("font_size", 20)
    combat_column.add_child(result_label)

    selection_label = Label.new()
    selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selection_label.add_theme_font_size_override("font_size", 15)
    selection_label.custom_minimum_size = Vector2(0, 30)
    combat_column.add_child(selection_label)

    notice_label = Label.new()
    notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice_label.add_theme_font_size_override("font_size", 11)
    combat_column.add_child(notice_label)

    # v1.6.10: stable dedicated prediction area. Core HUD values never morph on hover.
    prediction_panel = PanelContainer.new()
    prediction_panel.custom_minimum_size = Vector2(0, 72)
    prediction_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    combat_column.add_child(prediction_panel)
    var prediction_margin = MarginContainer.new()
    prediction_margin.add_theme_constant_override("margin_left", 10)
    prediction_margin.add_theme_constant_override("margin_top", 7)
    prediction_margin.add_theme_constant_override("margin_right", 10)
    prediction_margin.add_theme_constant_override("margin_bottom", 7)
    prediction_panel.add_child(prediction_margin)
    var prediction_box = VBoxContainer.new()
    prediction_box.add_theme_constant_override("separation", 3)
    prediction_margin.add_child(prediction_box)
    var prediction_title = Label.new()
    prediction_title.text = "使用後予測"
    prediction_title.add_theme_font_size_override("font_size", 13)
    prediction_box.add_child(prediction_title)
    prediction_label = Label.new()
    prediction_label.text = "カードに少しマウスを置くと、ここに結果を表示します。"
    prediction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    prediction_label.add_theme_font_size_override("font_size", 12)
    prediction_box.add_child(prediction_label)

    # Hidden compatibility nodes retained for telemetry / old debug code.
    player_label = Label.new()
    player_label.visible = false
    combat_column.add_child(player_label)
    player_hp_bar = ProgressBar.new()
    player_hp_bar.visible = false
    combat_column.add_child(player_hp_bar)
    mana_bar = ProgressBar.new()
    mana_bar.visible = false
    combat_column.add_child(mana_bar)

    combat_column.add_child(HSeparator.new())

    var hand_header = HBoxContainer.new()
    combat_column.add_child(hand_header)
    var hand_title = Label.new()
    hand_title.text = "手札"
    hand_title.add_theme_font_size_override("font_size", 17)
    hand_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hand_header.add_child(hand_title)
    var hover_hint = Label.new()
    hover_hint.text = "ホバー：予測 / 右クリック：全文"
    hover_hint.add_theme_font_size_override("font_size", 11)
    hover_hint.clip_text=true
    hover_hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    hand_header.add_child(hover_hint)
    var vfx_setting=OptionButton.new()
    for option in ["VFX 通常","VFX 軽量","VFX OFF"]:vfx_setting.add_item(option)
    vfx_setting.select(2-BattlePresentation.quality)
    vfx_setting.item_selected.connect(_on_vfx_quality_changed)
    hand_header.add_child(vfx_setting)
    var speed_setting := OptionButton.new()
    for option in ["1×", "2×", "3×"]: speed_setting.add_item(option)
    speed_setting.select(ux_preferences.speed - 1)
    speed_setting.tooltip_text = "アニメーションのみ高速化。戦闘処理・AI・通信には影響しません。"
    speed_setting.item_selected.connect(_on_vfx_speed_changed)
    hand_header.add_child(speed_setting)
    var audio_settings := Button.new()
    audio_settings.text = "音量"
    audio_settings.pressed.connect(_open_audio_settings)
    hand_header.add_child(audio_settings)
    var skip_vfx=Button.new();skip_vfx.text="スキップ"
    skip_vfx.pressed.connect(battle_presentation.clear_effects)
    hand_header.add_child(skip_vfx)
    turn_feedback_label = Label.new()
    turn_feedback_label.add_theme_font_size_override("font_size", 12)
    turn_feedback_label.add_theme_color_override("font_color", Color("c1d9e8"))
    turn_feedback_label.clip_text = true
    combat_column.add_child(turn_feedback_label)

    var hand_scroll = ScrollContainer.new()
    hand_scroll.custom_minimum_size = Vector2(0, 236)
    hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    combat_column.add_child(hand_scroll)

    # A straight horizontal row with scrolling avoids occluded card text.
    hand_box = Control.new()
    hand_box.name = "FlatHand"
    hand_box.custom_minimum_size = Vector2(0, 236)
    hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hand_scroll.add_child(hand_box)
    hand_box.resized.connect(_layout_hand_cards)

    selected_card_view = RichTextLabel.new()
    selected_card_view.visible = false
    combat_column.add_child(selected_card_view)

    var quick_controls = HBoxContainer.new()
    quick_controls.add_theme_constant_override("separation", 8)
    combat_column.add_child(quick_controls)

    use_button = Button.new()
    use_button.text = "使用"
    use_button.pressed.connect(_on_use_pressed)
    quick_controls.add_child(use_button)

    cancel_button = Button.new()
    cancel_button.text = "キャンセル"
    cancel_button.pressed.connect(_cancel_selection)
    quick_controls.add_child(cancel_button)

    var quick_spacer = Control.new()
    quick_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quick_controls.add_child(quick_spacer)

    restart_button = Button.new()
    restart_button.text = "同じ戦闘を再試行"
    restart_button.pressed.connect(_on_restart_pressed)
    quick_controls.add_child(restart_button)

    return_setup_button = Button.new()
    return_setup_button.text = "戦闘設定"
    return_setup_button.pressed.connect(_on_return_to_setup_pressed)
    quick_controls.add_child(return_setup_button)

    seed_input = SpinBox.new()
    seed_input.min_value = 1
    seed_input.max_value = 999999999
    seed_input.step = 1
    seed_input.value = 1001
    seed_input.custom_minimum_size = Vector2(100, 0)
    seed_input.visible = false
    quick_controls.add_child(seed_input)

    end_turn_button = Button.new()
    end_turn_button.text = "ターン終了"
    end_turn_button.custom_minimum_size = Vector2(0, 54)
    end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    end_turn_button.add_theme_font_size_override("font_size", 18)
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    var turn_controls=HBoxContainer.new();combat_column.add_child(turn_controls)
    turn_controls.add_child(end_turn_button)

    auto_battle_button = CheckButton.new()
    auto_battle_button.text = "オート戦闘 / OFFで手動"
    auto_battle_button.custom_minimum_size.y = 38
    auto_battle_button.toggled.connect(_on_auto_battle_toggled)
    turn_controls.add_child(auto_battle_button)

    outcome_panel = PanelContainer.new()
    outcome_panel.visible = false
    combat_column.add_child(outcome_panel)
    var outcome_box = HBoxContainer.new()
    outcome_box.add_theme_constant_override("separation", 10)
    outcome_panel.add_child(outcome_box)
    outcome_label = Label.new()
    outcome_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outcome_label.add_theme_font_size_override("font_size", 14)
    outcome_label.clip_text=true
    outcome_box.add_child(outcome_label)
    var defeat_log=Button.new();defeat_log.name="OutcomeBattleLog";defeat_log.text="戦闘ログを表示"
    defeat_log.pressed.connect(func():BattleLogDialog.show_log(self,battle.get_diagnostic_log(),"戦闘結果・詳細ログ"))
    outcome_box.add_child(defeat_log)
    var outcome_restart = Button.new()
    outcome_restart.text = "同じ戦闘を再試行"
    outcome_restart.pressed.connect(_on_retry_same_pressed)
    outcome_box.add_child(outcome_restart)
    var outcome_setup = Button.new()
    outcome_setup.text = "デッキ / 敵設定へ"
    outcome_setup.pressed.connect(_on_return_to_setup_pressed)
    outcome_box.add_child(outcome_setup)

    developer_toggle = CheckButton.new()
    developer_toggle.visible = false
    developer_toggle.button_pressed = false
    developer_toggle.toggled.connect(_on_developer_toggle)
    root.add_child(developer_toggle)

    developer_panel = VBoxContainer.new()
    developer_panel.visible = false
    developer_panel.add_theme_constant_override("separation", 6)
    root.add_child(developer_panel)

    var hud_preview_row = HBoxContainer.new()
    hud_preview_row.add_theme_constant_override("separation", 8)
    developer_panel.add_child(hud_preview_row)
    var hud_preview_label = Label.new()
    hud_preview_label.text = "MULTI HUD PREVIEW:"
    hud_preview_row.add_child(hud_preview_label)
    hud_count_option = OptionButton.new()
    hud_count_option.add_item("1P", 1)
    hud_count_option.add_item("2P", 2)
    hud_count_option.add_item("3P", 3)
    hud_count_option.select(0)
    hud_count_option.item_selected.connect(_on_hud_count_selected)
    hud_preview_row.add_child(hud_count_option)
    var hud_preview_hint = Label.new()
    hud_preview_hint.text = "P2/P3はUI配置確認用。Battle CoreはP1のみ。"
    hud_preview_row.add_child(hud_preview_hint)

    var debug_cards = HBoxContainer.new()
    debug_cards.add_theme_constant_override("separation", 6)
    developer_panel.add_child(debug_cards)

    var debug_label = Label.new()
    debug_label.text = "DEBUG CARDS:"
    debug_cards.add_child(debug_label)
    _add_debug_button(debug_cards, "+ Rapier", _on_debug_card.bind("DBG_RAPIER_ATTACK"))
    _add_debug_button(debug_cards, "+ Dagger Use", _on_debug_card.bind("DBG_DAGGER_USE"))
    _add_debug_button(debug_cards, "+ Greatsword Use", _on_debug_card.bind("DBG_GREATSWORD_USE"))
    _add_debug_button(debug_cards, "+ Magic Gen", _on_debug_card.bind("DBG_MAGIC_GEN"))
    _add_debug_button(debug_cards, "+ Katana Iai", _on_debug_card.bind("DBG_KATANA_IAI"))
    _add_debug_button(debug_cards, "+ Bottom", _on_debug_card.bind("DBG_BOTTOM"))
    _add_debug_button(debug_cards, "+ Discard", _on_debug_card.bind("DBG_DISCARD"))

    var catalog_controls = HBoxContainer.new()
    catalog_controls.add_theme_constant_override("separation", 6)
    developer_panel.add_child(catalog_controls)

    var catalog_label = Label.new()
    catalog_label.text = "120-CARD CATALOG:"
    catalog_controls.add_child(catalog_label)

    card_id_input = LineEdit.new()
    card_id_input.placeholder_text = "C001 - C120"
    card_id_input.text = "C016"
    card_id_input.custom_minimum_size = Vector2(120, 0)
    catalog_controls.add_child(card_id_input)

    var add_catalog_button = Button.new()
    add_catalog_button.text = "Add ID to hand"
    add_catalog_button.pressed.connect(_on_add_catalog_card)
    catalog_controls.add_child(add_catalog_button)
    debug_buttons.append(add_catalog_button)

    var validation_button = Button.new()
    validation_button.text = "旧v1.7カード監査（参考）"
    validation_button.pressed.connect(_on_run_validation)
    catalog_controls.add_child(validation_button)
    debug_buttons.append(validation_button)

    var simulation_button = Button.new()
    simulation_button.text = "旧v1.7簡易試算（参考）"
    simulation_button.pressed.connect(_on_run_batch_simulation)
    catalog_controls.add_child(simulation_button)
    debug_buttons.append(simulation_button)

    var core_regression_button = Button.new()
    core_regression_button.text = "Run v1.7.0 Battle Core gate"
    core_regression_button.pressed.connect(_on_run_battle_core_regression)
    catalog_controls.add_child(core_regression_button)
    debug_buttons.append(core_regression_button)

    var battle_result_button = Button.new()
    battle_result_button.text = "Run v1.7.0 BattleResult gate"
    battle_result_button.pressed.connect(_on_run_battle_result_validation)
    catalog_controls.add_child(battle_result_button)
    debug_buttons.append(battle_result_button)

    var debug_traits = GridContainer.new()
    debug_traits.columns = 6
    debug_traits.add_theme_constant_override("h_separation", 6)
    debug_traits.add_theme_constant_override("v_separation", 4)
    developer_panel.add_child(debug_traits)

    var trait_debug_label = Label.new()
    trait_debug_label.text = "DEBUG WEAPON:"
    debug_traits.add_child(trait_debug_label)
    _add_debug_button(debug_traits, "精密 ON", _on_debug_trait.bind("精密"))
    _add_debug_button(debug_traits, "連刃 ON", _on_debug_trait.bind("連刃"))
    _add_debug_button(debug_traits, "重撃 ON", _on_debug_trait.bind("重撃"))
    _add_debug_button(debug_traits, "魔導 ON", _on_debug_trait.bind("魔導"))
    _add_debug_button(debug_traits, "納刀 ON", _on_debug_trait.bind("納刀"))

    var attr_debug_label = Label.new()
    attr_debug_label.text = "DEBUG PLAYER ATTR:"
    debug_traits.add_child(attr_debug_label)
    _add_debug_button(debug_traits, "剛力 +3", _on_debug_attribute_trait.bind("剛力"))
    _add_debug_button(debug_traits, "帯電 +3", _on_debug_attribute_trait.bind("帯電"))
    _add_debug_button(debug_traits, "堅牢 +3", _on_debug_attribute_trait.bind("堅牢"))
    _add_debug_button(debug_traits, "恩寵 +3", _on_debug_attribute_trait.bind("恩寵"))
    _add_debug_button(debug_traits, "魔珠 +3", _on_debug_attribute_trait.bind("魔珠"))

    var attr_debug_label2 = Label.new()
    attr_debug_label2.text = "DEBUG ATTR / ENEMY #1:"
    debug_traits.add_child(attr_debug_label2)
    _add_debug_button(debug_traits, "疾風 +3", _on_debug_attribute_trait.bind("疾風"))
    _add_debug_button(debug_traits, "爆発 +3", _on_debug_enemy_attribute_trait.bind(0, "爆発"))
    _add_debug_button(debug_traits, "鈍化 +3", _on_debug_enemy_attribute_trait.bind(0, "鈍化"))
    _add_debug_button(debug_traits, "呪印 +3", _on_debug_enemy_attribute_trait.bind(0, "呪印"))
    _add_debug_button(debug_traits, "猛毒 +3", _on_debug_enemy_attribute_trait.bind(0, "猛毒"))

    var execute_debug_label = Label.new()
    execute_debug_label.text = "DEBUG SPECIAL:"
    debug_traits.add_child(execute_debug_label)
    _add_debug_button(debug_traits, "#3 Execute Setup", _on_debug_prepare_execution)
    _add_debug_button(debug_traits, "Player -10 HP", _on_debug_damage_player)

    var validation_title = Label.new()
    validation_title.text = "AUTOMATED VALIDATION"
    developer_panel.add_child(validation_title)

    validation_view = RichTextLabel.new()
    validation_view.custom_minimum_size = Vector2(0, 120)
    validation_view.bbcode_enabled = false
    validation_view.visible = false
    validation_view.text = "Validation結果をここに表示します。"
    developer_panel.add_child(validation_view)

    log_toggle = CheckButton.new()
    log_toggle.visible = false
    log_toggle.button_pressed = false
    log_toggle.toggled.connect(_on_log_toggle)
    root.add_child(log_toggle)

    log_panel = VBoxContainer.new()
    log_panel.visible = false
    root.add_child(log_panel)

    log_box = RichTextLabel.new()
    log_box.custom_minimum_size = Vector2(0, 150)
    log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_box.bbcode_enabled = false
    log_panel.add_child(log_box)

    _build_setup_tab()
    _build_loadout_tab()
    _build_playtest_tab()
    _build_step8_tab()
    _build_pile_overlay()

func _build_pile_overlay() -> void:
    pile_overlay = PanelContainer.new()
    pile_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pile_overlay.visible = false
    pile_overlay.z_index = 100
    pile_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(pile_overlay)

    var outer_margin = MarginContainer.new()
    outer_margin.add_theme_constant_override("margin_left", 72)
    outer_margin.add_theme_constant_override("margin_top", 54)
    outer_margin.add_theme_constant_override("margin_right", 72)
    outer_margin.add_theme_constant_override("margin_bottom", 54)
    pile_overlay.add_child(outer_margin)

    var panel = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    outer_margin.add_child(panel)

    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)

    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    box.add_child(header)

    pile_overlay_title = Label.new()
    pile_overlay_title.text = "カード一覧"
    pile_overlay_title.add_theme_font_size_override("font_size", 24)
    pile_overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(pile_overlay_title)

    var close_top = Button.new()
    close_top.text = "閉じる"
    pile_overlay_close = close_top
    close_top.pressed.connect(_close_pile_screen)
    header.add_child(close_top)

    pile_overlay_subtitle = Label.new()
    pile_overlay_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    pile_overlay_subtitle.add_theme_font_size_override("font_size", 13)
    box.add_child(pile_overlay_subtitle)

    box.add_child(HSeparator.new())

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    box.add_child(scroll)

    pile_overlay_grid = GridContainer.new()
    pile_overlay_grid.columns = 4
    pile_overlay_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pile_overlay_grid.add_theme_constant_override("h_separation", 8)
    pile_overlay_grid.add_theme_constant_override("v_separation", 8)
    scroll.add_child(pile_overlay_grid)

    pile_overlay_empty = Label.new()
    pile_overlay_empty.text = "カードはありません。"
    pile_overlay_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pile_overlay_empty.add_theme_font_size_override("font_size", 18)
    pile_overlay_empty.visible = false
    box.add_child(pile_overlay_empty)

    box.add_child(HSeparator.new())

    var footer = HBoxContainer.new()
    box.add_child(footer)
    var footer_hint = Label.new()
    footer_hint.text = "カード詳細はカードへマウスを合わせて確認"
    footer_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(footer_hint)
    var close_bottom = Button.new()
    close_bottom.text = "戦闘へ戻る"
    close_bottom.pressed.connect(_close_pile_screen)
    footer.add_child(close_bottom)

func _build_setup_tab() -> void:
    var setup_scroll = ScrollContainer.new()
    setup_scroll.name = "Setup"
    setup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    setup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_container.add_child(setup_scroll)

    var setup_root = VBoxContainer.new()
    setup_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    setup_root.add_theme_constant_override("separation", 8)
    setup_scroll.add_child(setup_root)

    var title = Label.new()
    title.text = "BATTLE SETUP — manual 120-card browser / equipment-generated 24-card deck"
    title.add_theme_font_size_override("font_size", 22)
    setup_root.add_child(title)

    var hint = Label.new()
    hint.text = "Build exactly 24 cards manually, or use the Loadout tab to generate 24 cards from six equipment slots. Choose an enemy preset and Seed, then start the battle."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    setup_root.add_child(hint)

    var filter_row = HBoxContainer.new()
    filter_row.add_theme_constant_override("separation", 8)
    setup_root.add_child(filter_row)

    setup_attribute_filter = OptionButton.new()
    for value in ATTRIBUTES:
        setup_attribute_filter.add_item(value)
    setup_attribute_filter.item_selected.connect(_on_setup_filter_changed)
    filter_row.add_child(setup_attribute_filter)

    setup_weapon_filter = OptionButton.new()
    for value in WEAPONS:
        setup_weapon_filter.add_item(value)
    setup_weapon_filter.item_selected.connect(_on_setup_filter_changed)
    filter_row.add_child(setup_weapon_filter)

    setup_role_filter = OptionButton.new()
    for value in ROLES:
        setup_role_filter.add_item(value)
    setup_role_filter.item_selected.connect(_on_setup_filter_changed)
    filter_row.add_child(setup_role_filter)

    setup_search_input = LineEdit.new()
    setup_search_input.placeholder_text = "Search ID / card text"
    setup_search_input.custom_minimum_size = Vector2(260, 0)
    setup_search_input.text_changed.connect(_on_setup_search_changed)
    filter_row.add_child(setup_search_input)

    var body = HBoxContainer.new()
    body.add_theme_constant_override("separation", 10)
    body.custom_minimum_size = Vector2(0, 515)
    setup_root.add_child(body)

    var browser_panel = VBoxContainer.new()
    browser_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(browser_panel)

    var browser_title = Label.new()
    browser_title.text = "CARD BROWSER"
    browser_panel.add_child(browser_title)

    setup_card_list = ItemList.new()
    setup_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    setup_card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    setup_card_list.custom_minimum_size = Vector2(480, 300)
    setup_card_list.item_selected.connect(_on_setup_card_selected)
    setup_card_list.item_activated.connect(_on_setup_card_activated)
    browser_panel.add_child(setup_card_list)

    var browser_buttons = HBoxContainer.new()
    browser_panel.add_child(browser_buttons)

    var add_button = Button.new()
    add_button.text = "Add selected +1"
    add_button.pressed.connect(_on_setup_add_selected)
    browser_buttons.add_child(add_button)

    setup_card_detail = RichTextLabel.new()
    setup_card_detail.bbcode_enabled = false
    setup_card_detail.custom_minimum_size = Vector2(480, 150)
    setup_card_detail.text = "Select a card to inspect it."
    browser_panel.add_child(setup_card_detail)

    var deck_panel = VBoxContainer.new()
    deck_panel.custom_minimum_size = Vector2(450, 0)
    body.add_child(deck_panel)

    var deck_title = Label.new()
    deck_title.text = "CURRENT DECK"
    deck_panel.add_child(deck_title)

    setup_status_label = Label.new()
    deck_panel.add_child(setup_status_label)

    setup_deck_list = ItemList.new()
    setup_deck_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    setup_deck_list.custom_minimum_size = Vector2(430, 330)
    deck_panel.add_child(setup_deck_list)

    var deck_buttons = HBoxContainer.new()
    deck_panel.add_child(deck_buttons)

    var remove_button = Button.new()
    remove_button.text = "Remove selected -1"
    remove_button.pressed.connect(_on_setup_remove_selected)
    deck_buttons.add_child(remove_button)

    var prototype_button = Button.new()
    prototype_button.text = "Load prototype 24"
    prototype_button.pressed.connect(_on_setup_load_prototype)
    deck_buttons.add_child(prototype_button)

    var clear_button = Button.new()
    clear_button.text = "Clear"
    clear_button.pressed.connect(_on_setup_clear_deck)
    deck_buttons.add_child(clear_button)

    var launch_row = HBoxContainer.new()
    launch_row.add_theme_constant_override("separation", 8)
    setup_root.add_child(launch_row)

    var enemy_label = Label.new()
    enemy_label.text = "Enemy preset"
    launch_row.add_child(enemy_label)

    setup_enemy_preset = OptionButton.new()
    setup_enemy_preset_ids.clear()
    var preset_catalog = BattleController.new().get_enemy_preset_catalog()
    var default_preset_index: int = 0
    var preset_index: int = 0
    for preset in preset_catalog:
        setup_enemy_preset.add_item(str(preset.get("label", preset.get("id", "preset"))))
        var preset_id: String = str(preset.get("id", "standard_trio"))
        setup_enemy_preset_ids.append(preset_id)
        if preset_id == current_enemy_preset:
            default_preset_index = preset_index
        preset_index += 1
    setup_enemy_preset.select(default_preset_index)
    setup_enemy_preset.custom_minimum_size = Vector2(330, 0)
    launch_row.add_child(setup_enemy_preset)

    var seed_label = Label.new()
    seed_label.text = "Seed"
    launch_row.add_child(seed_label)

    setup_seed_input = SpinBox.new()
    setup_seed_input.min_value = 1
    setup_seed_input.max_value = 999999999
    setup_seed_input.step = 1
    setup_seed_input.value = 1001
    setup_seed_input.custom_minimum_size = Vector2(140, 0)
    launch_row.add_child(setup_seed_input)

    setup_start_button = Button.new()
    setup_start_button.text = "START BATTLE"
    setup_start_button.pressed.connect(_on_setup_start_battle)
    launch_row.add_child(setup_start_button)

func _build_loadout_tab() -> void:
    var scroll = ScrollContainer.new()
    scroll.name = "Loadout"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_container.add_child(scroll)

    var root = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 8)
    scroll.add_child(root)

    var title = Label.new()
    title.text = "EQUIPMENT LOADOUT — 6 slots × 4 cards = 24-card deck"
    title.add_theme_font_size_override("font_size", 22)
    root.add_child(title)

    var hint = Label.new()
    hint.text = "Prototype equipment only. Each slot contributes exactly 4 cards. Rarity currently controls prototype special-effect slots: Common 0 / Rare 1 / Epic 2 / Legendary 3. Unequipped slots contribute Basic cards and no special effects. Changing this tab never mutates a battle already in progress."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(hint)

    loadout_selectors.clear()
    loadout_selector_item_ids.clear()
    for slot_id in loadout_builder.equipment_db.get_slot_ids():
        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        root.add_child(row)
        var label = Label.new()
        label.text = loadout_builder.equipment_db.get_slot_label(slot_id)
        label.custom_minimum_size = Vector2(130, 0)
        row.add_child(label)
        var selector = OptionButton.new()
        selector.custom_minimum_size = Vector2(340, 0)
        selector.add_item("Unequipped / Basic cards")
        var ids: Array[String] = [""]
        for item in loadout_builder.equipment_db.get_items_for_slot(slot_id):
            selector.add_item("[%s] %s" % [str(item.get("rarity", "Common")), str(item.get("name", item.get("id", "item")))])
            ids.append(str(item.get("id", "")))
        selector.item_selected.connect(_on_loadout_slot_changed.bind(slot_id))
        row.add_child(selector)
        loadout_selectors[slot_id] = selector
        loadout_selector_item_ids[slot_id] = ids

    var controls = HBoxContainer.new()
    controls.add_theme_constant_override("separation", 8)
    root.add_child(controls)

    var prototype_button = Button.new()
    prototype_button.text = "Load prototype equipment"
    prototype_button.pressed.connect(_on_loadout_prototype)
    controls.add_child(prototype_button)

    var empty_button = Button.new()
    empty_button.text = "Unequip all"
    empty_button.pressed.connect(_on_loadout_unequip_all)
    controls.add_child(empty_button)

    var apply_button = Button.new()
    apply_button.text = "Apply 24 cards to Setup"
    apply_button.pressed.connect(_on_loadout_apply_to_setup)
    controls.add_child(apply_button)

    var validate_button = Button.new()
    validate_button.text = "Run loadout validation"
    validate_button.pressed.connect(_on_loadout_validate)
    controls.add_child(validate_button)

    loadout_status_label = Label.new()
    loadout_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(loadout_status_label)

    loadout_preview = RichTextLabel.new()
    loadout_preview.bbcode_enabled = false
    loadout_preview.custom_minimum_size = Vector2(0, 320)
    root.add_child(loadout_preview)

    loadout_validation_view = RichTextLabel.new()
    loadout_validation_view.bbcode_enabled = false
    loadout_validation_view.custom_minimum_size = Vector2(0, 180)
    loadout_validation_view.visible = false
    root.add_child(loadout_validation_view)

func _build_playtest_tab() -> void:
    var playtest_scroll = ScrollContainer.new()
    playtest_scroll.name = "Playtest"
    playtest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    playtest_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_container.add_child(playtest_scroll)

    var root = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 8)
    playtest_scroll.add_child(root)

    var title = Label.new()
    title.text = "PLAYTEST TELEMETRY — reproducible battle report"
    title.add_theme_font_size_override("font_size", 22)
    root.add_child(title)

    var hint = Label.new()
    hint.text = "The report contains only battle-local test data: Seed, 24-card deck IDs, enemy preset, turns, card usage and combat totals. Save it after a suspicious battle to reproduce the same setup."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(hint)

    var controls = HBoxContainer.new()
    controls.add_theme_constant_override("separation", 8)
    root.add_child(controls)

    var refresh_button = Button.new()
    refresh_button.text = "Refresh current report"
    refresh_button.pressed.connect(_refresh_playtest_ui)
    controls.add_child(refresh_button)

    playtest_save_button = Button.new()
    playtest_save_button.text = "Save latest JSON report"
    playtest_save_button.pressed.connect(_on_save_playtest_report)
    controls.add_child(playtest_save_button)

    var result_save_button = Button.new()
    result_save_button.text = "Save BattleResult JSON"
    result_save_button.pressed.connect(_on_save_battle_result)
    controls.add_child(result_save_button)
    var journal_button := Button.new()
    journal_button.text = "行動履歴JSON"
    journal_button.tooltip_text = "再生機能は未実装。確定したカード使用・ターン終了の入力記録を保存します。"
    journal_button.pressed.connect(_export_battle_actions)
    controls.add_child(journal_button)

    var selftest_button = Button.new()
    selftest_button.text = "Run telemetry self-test"
    selftest_button.pressed.connect(_on_run_telemetry_selftest)
    controls.add_child(selftest_button)

    var battle_button = Button.new()
    battle_button.text = "Back to Battle"
    battle_button.pressed.connect(_on_playtest_back_to_battle)
    controls.add_child(battle_button)

    playtest_status_label = Label.new()
    playtest_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    playtest_status_label.text = "Report not saved yet."
    root.add_child(playtest_status_label)

    playtest_view = RichTextLabel.new()
    playtest_view.bbcode_enabled = false
    playtest_view.custom_minimum_size = Vector2(0, 520)
    playtest_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(playtest_view)

func _export_battle_actions() -> void:
    if action_journal == null: return
    var path: String = action_journal.export_local()
    if playtest_status_label != null:
        playtest_status_label.text = "行動履歴を保存: " + path if path != "" else "行動履歴の保存に失敗しました。"

func _refresh_playtest_ui() -> void:
    if playtest_view == null or battle == null:
        return
    var report = battle.get_playtest_report()
    var lines: Array[String] = []
    lines.append(battle.get_playtest_summary_text())
    lines.append("")
    lines.append("Reproduction")
    lines.append("  Seed: %d" % int(report.get("seed", 0)))
    lines.append("  Enemy preset: %s" % str(report.get("enemy_preset", "")))
    var deck_ids: Array = report.get("deck_ids", [])
    lines.append("  Deck (%d): %s" % [deck_ids.size(), ", ".join(deck_ids)])
    var equipment_snapshot: Dictionary = report.get("equipment_loadout", {})
    lines.append("  Equipment snapshot: %s" % ("manual deck" if equipment_snapshot.is_empty() else str(equipment_snapshot)))
    lines.append("  Equipment special effects: %s" % str(report.get("equipment_special_effects", [])))
    lines.append("")
    lines.append("BattleResult / next-encounter handoff")
    var battle_result = battle.get_battle_result()
    if battle_result.is_empty():
        lines.append("  IN_PROGRESS — BattleResult has not been finalized.")
    else:
        lines.append("  Result: %s / reason: %s" % [str(battle_result.get("result", "")), str(battle_result.get("reason", ""))])
        lines.append("  Eligible for next encounter: %s" % str(battle_result.get("eligible_for_next_encounter", false)))
        var next_payload = battle.get_next_encounter_payload()
        lines.append("  Next payload: %s" % ("not available" if next_payload.is_empty() else "ready — HP %d/%d, deck %d" % [int(next_payload.get("player_hp_remaining", 0)), int(next_payload.get("player_max_hp", 0)), next_payload.get("deck_ids", []).size()]))
    lines.append("")
    lines.append("Final player state")
    lines.append("  HP %d/%d" % [int(report.get("player_hp_end", 0)), int(report.get("player_max_hp", 0))])
    lines.append("  Weapon traits: %s" % str(report.get("weapon_traits_end", {})))
    lines.append("  Attribute traits: %s" % str(report.get("attribute_traits_end", {})))
    lines.append("  Engines: %s" % str(report.get("continuous_effects_end", {})))
    lines.append("")
    lines.append("Final enemies")
    for enemy in report.get("enemy_states_end", []):
        lines.append("  #%d %s HP %d/%d Block %d | traits %s" % [
            int(enemy.get("order_index", 0)), str(enemy.get("name", "Enemy")),
            int(enemy.get("hp", 0)), int(enemy.get("max_hp", 0)), int(enemy.get("block", 0)),
            str(enemy.get("attribute_traits", {}))
        ])
    playtest_view.text = "\n".join(lines)

func _on_save_playtest_report() -> void:
    if battle == null:
        return
    var report = battle.get_playtest_report()
    report["battle_log"] = battle.get_diagnostic_log()
    var path = "user://playtest_report_latest.json"
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        playtest_status_label.text = "Save failed: %s" % path
        return
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    playtest_status_label.text = "Saved: %s" % path
    _refresh_playtest_ui()

func _on_save_battle_result() -> void:
    if battle == null:
        return
    var result = battle.get_battle_result()
    if result.is_empty():
        playtest_status_label.text = "BattleResult is not available until Victory/Defeat."
        return
    result["battle_log"] = battle.get_diagnostic_log()
    result["next_encounter_payload"] = battle.get_next_encounter_payload()
    var path = "user://battle_result_latest.json"
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        playtest_status_label.text = "Save failed: %s" % path
        return
    file.store_string(JSON.stringify(result, "  "))
    file.close()
    playtest_status_label.text = "Saved: %s" % path
    _refresh_playtest_ui()

func _on_run_telemetry_selftest() -> void:
    var runner = PlaytestTelemetryRunnerScript.new()
    var result: Dictionary = runner.run_all()
    var text = "Telemetry self-test: %s | PASS %d | FAIL %d" % [
        "PASS" if bool(result.get("ok", false)) else "FAIL",
        int(result.get("passed", 0)),
        int(result.get("failed", 0))
    ]
    var failures: Array = result.get("failures", [])
    if not failures.is_empty():
        text += " | " + ", ".join(failures)
    playtest_status_label.text = text

func _on_playtest_back_to_battle() -> void:
    tab_container.current_tab = 0


func _refresh_player_hud_panels() -> void:
    if battle_hud_adapter == null or player_hud_panels.is_empty():
        return
    var models: Array[Dictionary] = battle_hud_adapter.get_player_view_models(battle, hud_player_count)
    for slot in range(player_hud_panels.size()):
        var hud = player_hud_panels[slot]
        var should_show: bool = slot < models.size()
        hud.visible = should_show
        if not should_show:
            continue
        hud.set_compact(hud_player_count >= 2)
        hud.set_player_data(models[slot])
        hud.set_active(slot == 0)
    _refresh_hover_preview()

func _on_player_pile_requested(player_slot: int, pile_type: String) -> void:
    if player_slot != 0:
        notice_label.text = "P%d はHUDレイアウト確認用です。実データ接続はマルチBattle Core実装時に行います。" % (player_slot + 1)
        return
    match pile_type:
        "draw":
            _show_draw_pile_info()
        "discard":
            _show_discard_info()
        "exhaust":
            _show_exhaust_info()

func _on_hud_count_selected(index: int) -> void:
    if hud_count_option == null:
        return
    hud_player_count = int(hud_count_option.get_item_id(index))
    hud_player_count = int(clamp(hud_player_count, 1, 3))
    _refresh_player_hud_panels()

func _on_card_hovered(index: int) -> void:
    if generation_job != null:
        return
    if battle == null or battle.combat_over or battle.is_hand_selection_active():
        return
    if index < 0 or index >= battle.hand.size():
        return
    hover_candidate_index = index
    if hand_box != null and index < hand_box.get_child_count():
        hand_box.get_child(index).z_index = 50
    if hover_clear_timer != null:
        hover_clear_timer.stop()
    if hovered_hand_index == index:
        return
    if hover_preview_timer != null:
        hover_preview_timer.stop()
        hover_preview_timer.start()

func _on_card_hover_exited(index: int) -> void:
    if generation_job != null:
        return
    if hand_box != null and index < hand_box.get_child_count():
        hand_box.get_child(index).z_index = index
    if hover_candidate_index == index:
        hover_candidate_index = -1
    if hover_preview_timer != null:
        hover_preview_timer.stop()
    if hovered_hand_index == index and hover_clear_timer != null:
        hover_clear_timer.stop()
        hover_clear_timer.start()

func _commit_hover_preview() -> void:
    if battle == null or battle.combat_over or battle.is_hand_selection_active():
        return
    if hover_candidate_index < 0 or hover_candidate_index >= battle.hand.size():
        return
    hovered_hand_index = hover_candidate_index
    _refresh_hover_preview()

func _clear_hover_preview_delayed() -> void:
    if hover_candidate_index >= 0:
        return
    hovered_hand_index = -1
    _refresh_hover_preview()

func _refresh_hover_preview() -> void:
    if prediction_label == null:
        return
    var preview_index: int=selected_hand_index if selected_hand_index>=0 else hovered_hand_index
    if battle == null or battle.combat_over or preview_index < 0 or preview_index >= battle.hand.size():
        prediction_label.text = "カードに少しマウスを置くと、ここに結果を表示します。"
        return
    prediction_label.text = _build_stable_prediction_text(preview_index)

func _build_stable_prediction_text(hand_index: int) -> String:
    return BattleCardPreview.describe(BattleCardPreview.inspect(battle,hand_index,_preview_target()))

func _enemy_preview_text_for_card(hand_index: int,enemy_index: int) -> String:
    return BattleCardPreview.describe(BattleCardPreview.inspect(battle,hand_index,enemy_index))

func _build_player_preview_model(hand_index: int) -> Dictionary:
    if hand_index < 0 or hand_index >= battle.hand.size():
        return {}
    if not battle.can_use_card(hand_index):
        return {}
    var target_type: String = battle.get_effective_target_type(hand_index)
    var target_index: int = -1
    if target_type == "enemy":
        for enemy_index in range(battle.get_enemy_count()):
            if battle.is_enemy_target_valid(enemy_index):
                target_index = enemy_index
                break
        if target_index < 0:
            return {}
    var sim: BattleController = _clone_battle_for_preview()
    if not sim.use_card(hand_index, target_index):
        return {}
    _finish_preview_hand_selection(sim)
    var notes: Array[String] = []
    var card: Dictionary = battle.hand[hand_index]
    var weapon_trait_name: String = str(card.get("weapon_trait", ""))
    if weapon_trait_name != "":
        var before_weapon: bool = bool(battle.weapon_traits.get(weapon_trait_name, false))
        var after_weapon: bool = bool(sim.weapon_traits.get(weapon_trait_name, false))
        if not before_weapon and after_weapon:
            notes.append("★ %s ON" % weapon_trait_name)
            if weapon_trait_name == "納刀":
                notes.append("次の居合 Cost 0")
    return {
        "hp_after": sim.player_hp,
        "mana_after": sim.current_mana,
        "block_after": sim.player_block,
        "weapon_traits": sim.weapon_traits.duplicate(true),
        "attribute_traits": sim.attribute_traits.duplicate(true),
        "notes": notes
    }

func _build_enemy_hover_preview(enemy_index: int) -> Dictionary:
    if hovered_hand_index < 0 or hovered_hand_index >= battle.hand.size():
        return {}
    if battle.get_effective_target_type(hovered_hand_index) != "enemy":
        return {}
    if not battle.is_enemy_target_valid(enemy_index) or not battle.can_use_card(hovered_hand_index):
        return {}
    var before_enemy: Dictionary = battle.get_enemy(enemy_index).duplicate(true)
    var sim: BattleController = _clone_battle_for_preview()
    if not sim.use_card(hovered_hand_index, enemy_index):
        return {}
    _finish_preview_hand_selection(sim)
    var after_enemy: Dictionary = sim.get_enemy(enemy_index)
    return {
        "hp_before": int(before_enemy.get("hp", 0)),
        "hp_after": int(after_enemy.get("hp", 0)),
        "block_before": int(before_enemy.get("block", 0)),
        "block_after": int(after_enemy.get("block", 0)),
        "before": before_enemy,
        "after": after_enemy
    }

func _enemy_hover_preview_text(enemy_index: int) -> String:
    var preview: Dictionary = _build_enemy_hover_preview(enemy_index)
    if preview.is_empty():
        return ""
    var parts: Array[String] = []
    var hp_before: int = int(preview.get("hp_before", 0))
    var hp_after: int = int(preview.get("hp_after", hp_before))
    if hp_before != hp_after:
        parts.append("HP %d→%d" % [hp_before, hp_after])
    var block_before: int = int(preview.get("block_before", 0))
    var block_after: int = int(preview.get("block_after", block_before))
    if block_before != block_after:
        parts.append("Block %d→%d" % [block_before, block_after])
    var before_enemy: Dictionary = preview.get("before", {})
    var after_enemy: Dictionary = preview.get("after", {})
    parts.append_array(_changed_enemy_status_parts(before_enemy, after_enemy))
    if hp_after <= 0 and hp_before > 0:
        parts.append("撃破")
    return " / ".join(parts)

func _on_developer_toggle(pressed: bool) -> void:
    if developer_panel != null:
        developer_panel.visible = pressed

func _on_log_toggle(pressed: bool) -> void:
    if log_panel != null:
        log_panel.visible = pressed

func _format_nonzero_traits(source: Dictionary, keys: Array) -> String:
    var values: Array[String] = []
    for raw_key in keys:
        var key = str(raw_key)
        var amount = int(source.get(key, 0))
        if amount > 0:
            values.append("%s %d" % [key, amount])
    return "なし" if values.is_empty() else " / ".join(values)

func _get_ui_icon(icon_name: String):
    if icon_cache.has(icon_name):
        return icon_cache[icon_name]
    var resource = load("res://assets/icons/ui/%s.svg" % icon_name)
    icon_cache[icon_name] = resource
    return resource

func _make_counter_button(icon_name: String, amount: int, tooltip: String, callback: Callable) -> Button:
    var button = Button.new()
    button.flat = true
    button.icon = _get_ui_icon(icon_name)
    button.text = str(amount)
    button.custom_minimum_size = Vector2(48, 30)
    button.tooltip_text = tooltip
    button.focus_mode = Control.FOCUS_NONE
    if callback.is_valid():
        button.pressed.connect(callback)
    return button

func _make_resource_button(icon_name: String, value_text: String, tooltip: String) -> Button:
    var button = Button.new()
    button.flat = true
    button.icon = _get_ui_icon(icon_name)
    button.text = value_text
    button.custom_minimum_size = Vector2(78, 34)
    button.tooltip_text = tooltip
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_default_cursor_shape = Control.CURSOR_HELP
    return button

func _clear_container(container: Container) -> void:
    for child in container.get_children():
        child.queue_free()

func _weapon_trait_icon_name(trait_name: String) -> String:
    match trait_name:
        "流転": return "weapon_sword"
        "精密": return "weapon_precision"
        "連刃": return "weapon_combo"
        "重撃": return "weapon_charge"
        "魔導": return "weapon_magic"
        "納刀": return "weapon_sheathe"
    return "engine"

func _attribute_trait_icon_name(trait_name: String) -> String:
    match trait_name:
        "剛力": return "attr_might"
        "爆発": return "attr_blast"
        "鈍化": return "attr_slow"
        "帯電": return "attr_charge"
        "堅牢": return "attr_guard"
        "恩寵": return "attr_grace"
        "呪印": return "attr_curse"
        "猛毒": return "attr_poison"
        "魔珠": return "attr_orb"
        "疾風": return "attr_wind"
    return "engine"

func _trait_tooltip(trait_name: String, amount: int) -> String:
    var detail = ""
    match trait_name:
        "流転": detail = "ON時、次の対応片手剣カードでAttackならダメージ50%をBlock、DefenseならBlock50%を追加ダメージ。発動後OFF。"
        "精密": detail = "ON時、次の対応レイピアAttackでBlockありならBlock Ignore、なければ攻撃後に脆弱1。発動後OFF。"
        "連刃": detail = "ON時、次の対応短剣Attackを同ダメージの2Hitにする。2Hit目はダメージのみ。発動後OFF。"
        "重撃": detail = "ON時、次の対応大剣Attackのダメージ×1.5。発動後OFF。"
        "魔導": detail = "ON時、次の対応魔法剣CONSUMEカードの属性特性獲得量+2。発動後OFF。"
        "納刀": detail = "ON時、次の居合対応カードをCost0。居合使用後OFF。納刀ONからの居合決着技はHP10%以下で処刑。"
        "剛力": detail = "3スタックごとにAttackカードのダメージ+1。1枚につき1回。"
        "爆発": detail = "新しい3/6/9…閾値到達時に即時ダメージ。"
        "鈍化": detail = "3スタックごとに敵Attack行動の合計ダメージ-2。最低1。"
        "帯電": detail = "敵Attack行動終了後、3スタックごとに3反撃ダメージ。"
        "堅牢": detail = "プレイヤーターン開始時、3スタックごとにBlock2。"
        "恩寵": detail = "プレイヤーターン開始時、3スタックごとにHP1回復。"
        "呪印": detail = "各ターン最初に呪印状態の敵へAttackした時、3スタックごとにHP2回復。"
        "猛毒": detail = "敵ターン終了時、3スタックごとに2ダメージ。"
        "魔珠": detail = "新しい3/6/9…閾値到達ごとにMana1回復。"
        "疾風": detail = "新しい3/6/9…閾値到達ごとに次カードCost-1を1回獲得。"
        "脆弱": detail = "次に受けるAttackダメージを25%増加し、そのAttack後に解除。"
    if trait_name in ["流転", "精密", "連刃", "重撃", "魔導", "納刀"]:
        return "%s ON\n%s" % [trait_name, detail]
    return "%s %d\n%s" % [trait_name, amount, detail]

func _add_status_icon(parent: Container, icon_name: String, amount: int, tooltip: String) -> void:
    if amount <= 0:
        return
    var button = _make_counter_button(icon_name, amount, tooltip, Callable())
    button.custom_minimum_size = Vector2(44, 28)
    parent.add_child(button)

func _refresh_player_status_icons() -> void:
    if player_status_box == null:
        return
    _clear_container(player_status_box)
    var any_status = false
    for trait_name in ["流転", "精密", "連刃", "重撃", "魔導", "納刀"]:
        if bool(battle.weapon_traits.get(trait_name, false)):
            var button: Button = Button.new()
            button.flat = true
            button.icon = _get_ui_icon(_weapon_trait_icon_name(trait_name))
            button.text = "ON"
            button.custom_minimum_size = Vector2(58, 28)
            button.tooltip_text = _trait_tooltip(trait_name, 1)
            button.focus_mode = Control.FOCUS_NONE
            player_status_box.add_child(button)
            any_status = true
    for trait_name in ["剛力", "帯電", "堅牢", "恩寵", "魔珠", "疾風"]:
        var amount = int(battle.attribute_traits.get(trait_name, 0))
        if amount > 0:
            _add_status_icon(player_status_box, _attribute_trait_icon_name(trait_name), amount, _trait_tooltip(trait_name, amount))
            any_status = true
    if battle.swift_cost_reduction_charges > 0:
        _add_status_icon(player_status_box, "cost_down", battle.swift_cost_reduction_charges, "疾風 Cost-1 回数 %d" % battle.swift_cost_reduction_charges)
        any_status = true
    var engine_summary = battle.get_continuous_effect_summary()
    if engine_summary != "none" and engine_summary != "":
        _add_status_icon(player_status_box, "engine", 1, "継続効果\n%s" % engine_summary)
        any_status = true
    var equipment_summary = battle.get_equipment_special_effect_summary()
    if equipment_summary != "none" and equipment_summary != "":
        _add_status_icon(player_status_box, "equipment", 1, "装備効果\n%s" % equipment_summary)
        any_status = true
    trait_label.text = "状態なし" if not any_status else ""

func _compact_enemy_name(enemy_name: String) -> String:
    var bracket_index = enemy_name.find(" [")
    if bracket_index >= 0:
        return enemy_name.substr(0, bracket_index)
    return enemy_name

func _enemy_preset_display_name(preset_id: String) -> String:
    match preset_id:
        "region1_stage1": return "Region 1 / Stage I"
        "slime_duo": return "Slime Duo"
        "armored_pair": return "Armored Pair"
        "boss_solo": return "Boss Solo"
        "standard_trio": return "Standard Trio"
    return preset_id

func _add_debug_button(parent: Container, label: String, callback: Callable) -> void:
    var button = Button.new()
    button.text = label
    button.pressed.connect(callback)
    parent.add_child(button)
    debug_buttons.append(button)

func _rebuild_enemy_buttons() -> void:
    preview_enemy_index=-1;hovered_enemy_index=-1
    for child in enemy_box.get_children():
        enemy_box.remove_child(child)
        child.queue_free()
    enemy_buttons.clear()
    enemy_status_boxes.clear()

    for enemy_index in range(battle.get_enemy_count()):
        var cell = VBoxContainer.new()
        cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cell.add_theme_constant_override("separation", 3)
        enemy_box.add_child(cell)

        var button = Button.new()
        button.custom_minimum_size = Vector2(0, 162)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 15)
        button.pressed.connect(_on_enemy_pressed.bind(enemy_index))
        button.mouse_entered.connect(_on_preview_enemy_enter.bind(enemy_index))
        button.mouse_exited.connect(_on_preview_enemy_exit.bind(enemy_index))
        cell.add_child(button)
        enemy_buttons.append(button)

        var status_box = HBoxContainer.new()
        status_box.alignment = BoxContainer.ALIGNMENT_CENTER
        status_box.add_theme_constant_override("separation", 2)
        status_box.custom_minimum_size.y = 28
        status_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cell.add_child(status_box)
        enemy_status_boxes.append(status_box)

func _refresh_ui() -> void:
    _watch_presentation()
    battle_presentation.pending_events.clear()
    if region_run_ui!=null: region_run_ui.sync_battle()
    for navigation in get_tree().get_nodes_in_group("sce_developer_navigation"):
        navigation.disabled=region_run_ui!=null and region_run_ui.locked()
    hovered_enemy_index=-1
    hovered_hand_index = -1
    hover_candidate_index = -1
    if hover_preview_timer != null:
        hover_preview_timer.stop()
    if hover_clear_timer != null:
        hover_clear_timer.stop()
    if battle.combat_over:
        battle_state_label.text = "戦闘終了"
    elif battle.is_hand_selection_active():
        battle_state_label.text = "カード解決中"
    elif selected_hand_index >= 0:
        battle_state_label.text = "カード選択中"
    else:
        battle_state_label.text = "Turn %d" % battle.turn_number

    if prediction_label != null:
        prediction_label.text = "カードに少しマウスを置くと、ここに結果を表示します。"

    player_label.text = "HP %d/%d    Mana %d    Block %d" % [
        battle.player_hp,
        battle.player_max_hp,
        battle.current_mana,
        battle.player_block
    ]
    player_hp_bar.max_value = battle.player_max_hp
    player_hp_bar.value = battle.player_hp
    mana_bar.max_value = max(6, max(battle.current_mana, BattleController.BASE_MANA))
    mana_bar.value = battle.current_mana

    if battle_title_label != null:
        var preset: String=battle.get_active_enemy_preset()
        battle_title_label.text = "Region %s / Stage I"%preset.substr(6,1) if preset.begins_with("region") else "%s — 模擬戦闘" % _enemy_preset_display_name(preset)
    piles_label.text = "Turn %d   /   Seed %d   /   %s" % [
        battle.turn_number,
        battle.get_active_seed(),
        battle.get_active_enemy_preset()
    ]
    _refresh_player_hud_panels()
    notice_label.text = battle.last_notice
    for status in ["Poison","Burn","Weak","Vulnerable","Shock","Frost","Frozen","Marked","ManaTax"]:
        if int(battle.campaign_status.get(status,0))>0: notice_label.text+="　%s %d"%[status,int(battle.campaign_status[status])]

    _refresh_enemies()
    _rebuild_hand()
    _refresh_turn_feedback()

    var selected_card: Dictionary = _get_selected_card()
    if battle.is_hand_selection_active():
        selection_label.text = "解決中: %s" % battle.get_hand_selection_prompt()
    elif selected_card.is_empty():
        selection_label.text = "カードを選択してください。詳細はカードへマウスを合わせると表示されます。"
    else:
        var target_type: String = battle.get_effective_target_type(selected_hand_index)
        if target_type == "enemy":
            selection_label.text = "%s 選択中 → 敵をクリック、または敵へドラッグ" % selected_card.get("id", "?")
        else:
            selection_label.text = "%s 選択中 → 上へドラッグ、または［使用］" % selected_card.get("id", "?")

    var selected_target_type = "none" if selected_card.is_empty() else battle.get_effective_target_type(selected_hand_index)
    use_button.visible = (not battle.is_hand_selection_active()) and (not selected_card.is_empty()) and selected_target_type != "enemy"
    cancel_button.disabled = battle.is_hand_selection_active() or selected_card.is_empty()
    end_turn_button.disabled = battle.is_hand_selection_active() or (not battle.resolving_card.is_empty()) or (not selected_card.is_empty()) or battle.combat_over
    restart_button.disabled = battle.is_hand_selection_active() or (not battle.resolving_card.is_empty())
    return_setup_button.disabled = battle.is_hand_selection_active() or (not battle.resolving_card.is_empty())
    if region_run_ui!=null and region_run_ui.locked():
        restart_button.disabled=true
        return_setup_button.disabled=true

    for button in debug_buttons:
        button.disabled = battle.combat_over or battle.is_hand_selection_active() or not battle.resolving_card.is_empty()
        if region_run_ui!=null and region_run_ui.locked(): button.disabled=true

    outcome_panel.visible = battle.combat_over
    hand_box.get_parent().custom_minimum_size.y=236
    if battle.combat_over:
        var result_snapshot = battle.get_battle_result()
        var result_code = str(result_snapshot.get("result", "VICTORY" if battle.victory else "DEFEAT"))
        result_label.text = result_code
        outcome_label.text = "%s  |  %s  |  Turn %d  |  Seed %d  |  %s" % [
            result_code,
            str(result_snapshot.get("reason", "")),
            battle.turn_number,
            battle.get_active_seed(),
            battle.get_active_enemy_preset()
        ]
    else:
        result_label.text = ""
        outcome_label.text = ""

    log_box.text = "\n".join(battle.logs)
    log_box.scroll_to_line(max(0, battle.logs.size() - 1))
    _refresh_playtest_ui()
    if battle.is_salvage_selection_active():
        _show_salvage_selection()
    elif pile_overlay_close != null:
        pile_overlay_close.disabled = false

func _refresh_enemies() -> void:
    if enemy_buttons.size() != battle.get_enemy_count():
        _rebuild_enemy_buttons()

    var selected_card = _get_selected_card()
    var attack_selected = (not selected_card.is_empty()) and battle.get_effective_target_type(selected_hand_index) == "enemy" and not battle.is_hand_selection_active()

    for enemy_index in range(enemy_buttons.size()):
        var button: Button = enemy_buttons[enemy_index]
        var status_box: HBoxContainer = enemy_status_boxes[enemy_index]
        _clear_container(status_box)

        var enemy = battle.get_enemy(enemy_index)
        var hp: int = int(enemy.get("hp", 0))
        var max_hp: int = int(enemy.get("max_hp", 0))
        var block: int = int(enemy.get("block", 0))
        var vulnerable: int = int(enemy.get("vulnerable", 0))
        var order_index: int = int(enemy.get("order_index", enemy_index + 1))
        var enemy_name: String = str(enemy.get("name", "Enemy"))
        var display_name = _compact_enemy_name(enemy_name)
        if str(enemy.get("id",""))=="R6-N07": display_name+="（画像未設定）"
        if enemy.has("phase_hp"):
            display_name+="　Phase %d/%d"%[int(enemy.phase_index)+1,enemy.phase_hp.size()]
            if str(enemy.id)=="R6-B04": display_name+=" — "+str(RegionCatalog.FINAL_PHASE_NAMES[int(enemy.phase_index)])
        var intent_text = battle.get_enemy_intent_display_label(enemy_index)

        if hp <= 0:
            button.text = "#%d %s\n撃破済み" % [order_index, display_name]
            button.tooltip_text = enemy_name
            button.disabled = true
            MonsterPortrait.update(button, enemy)
            continue

        var target_prefix = "▶ " if attack_selected else ""
        var block_text = "  ◆%d" % block if block > 0 else ""
        button.text = "%s#%d %s\nHP %d/%d%s\n次: %s" % [target_prefix, order_index, display_name, hp, max_hp, block_text, intent_text]
        button.tooltip_text = "%s\nEnemyOrderIndex %d\nHP %d/%d  Block %d\n次の行動: %s" % [enemy_name, order_index, hp, max_hp, block, intent_text]
        if intent_text.contains("蓄力"):
            button.tooltip_text += "\n【蓄力とは】敵がためた攻撃準備の力。強攻撃では蓄力をすべて使い、その分を加算した予測ダメージを表示します。『0』はダメージ0ではありません。"
        var region_status: Dictionary=enemy.get("r1_status",{})
        for key in region_status:
            if int(region_status[key])>0: button.tooltip_text+="\n%s %d" % [str(key),int(region_status[key])]
        button.disabled = battle.combat_over
        MonsterPortrait.update(button, enemy)
        var active_status_count: int = 0
        for key in region_status:
            if int(region_status[key])>0:
                var counter=Label.new()
                counter.text="%s:%d" % ["蓄力" if str(key)=="Charge" else str(key),int(region_status[key])]
                counter.add_theme_font_size_override("font_size",12)
                status_box.add_child(counter)
                active_status_count += 1

        if vulnerable > 0:
            _add_status_icon(status_box, "vulnerable", vulnerable, _trait_tooltip("脆弱", vulnerable))
            active_status_count += 1
        for trait_name in ["爆発", "鈍化", "呪印", "猛毒"]:
            var trait_amount = battle.get_enemy_attribute_trait(enemy_index, trait_name)
            if trait_amount > 0:
                _add_status_icon(status_box, _attribute_trait_icon_name(trait_name), trait_amount, _trait_tooltip(trait_name, trait_amount))
                active_status_count += 1
        if active_status_count == 0:
            var empty_status:=Label.new()
            empty_status.text="状態効果なし"
            empty_status.add_theme_font_size_override("font_size",11)
            empty_status.modulate=Color("82929f")
            status_box.add_child(empty_status)

func _rebuild_hand() -> void:
    for child in hand_box.get_children():
        hand_box.remove_child(child)
        child.queue_free()

    for i in range(battle.hand.size()):
        var card: Dictionary = battle.hand[i]
        var button = PlaytestCardButtonScript.new()
        button.hand_index = i
        button.configure(card,battle.get_effective_cost(i),{
            "mana":_get_ui_icon("mana"),"attack":_get_ui_icon("attack"),"block":_get_ui_icon("block")
        },i==selected_hand_index,battle.is_hand_selection_active(),battle.current_mana>=battle.get_effective_cost(i))
        button.tooltip_text = str(card.get("text",""))
        button.custom_minimum_size = Vector2(164, 190)
        button.mark_weapon_condition(_weapon_trait_will_be_consumed(card,i))
        button.apply_target_preview(BattleCardPreview.inspect(battle,i,_preview_target()))
        button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        button.clip_text = true

        if battle.is_hand_selection_active():
            button.disabled = false
        else:
            button.disabled = battle.combat_over or (not battle.can_use_card(i) and i != selected_hand_index)

        button.card_clicked.connect(_on_card_pressed)
        button.card_drag_started.connect(_on_card_drag_started)
        button.card_drag_moved.connect(_on_card_drag_moved)
        button.card_drag_released.connect(_on_card_drag_released)
        button.card_hovered.connect(_on_card_hovered)
        button.card_hover_exited.connect(_on_card_hover_exited)
        hand_box.add_child(button)
        button.apply_hand_arc(i, battle.hand.size(), i == selected_hand_index)
    _layout_hand_cards()
    call_deferred("_layout_hand_cards")

func _layout_hand_cards() -> void:
    if hand_box == null:
        return
    var count: int = hand_box.get_child_count()
    if count == 0:
        return
    var card_width: float = 164.0
    var card_height: float = 190.0
    var gap: float = 10.0
    var span: float = card_width * float(count) + gap * float(maxi(0, count - 1))
    # Do not overlap cards even at 10-card hand size; ScrollContainer handles overflow.
    if not is_equal_approx(hand_box.custom_minimum_size.x, span):
        hand_box.custom_minimum_size.x = span
    var space: float = maxf(span, hand_box.size.x)
    var origin: float = maxf(0.0, (space - span) * 0.5)
    for i in range(count):
        var button: Control = hand_box.get_child(i) as Control
        if button == null:
            continue
        button.set_size(Vector2(card_width, card_height))
        button.position = Vector2(origin + float(i) * (card_width + gap), 6.0)
        button.rotation_degrees = 0.0
        button.z_index = i
        if button.has_method("apply_hand_arc"):
            button.apply_hand_arc(i, count, i == selected_hand_index)

func _on_card_drag_started(index: int, press_global_position: Vector2) -> void:
    if _auto_input_locked(): return
    if region_run_ui != null and region_run_ui.animation_busy: return
    if generation_job != null:
        return
    if battle.combat_over or battle.is_hand_selection_active():
        return
    if index < 0 or index >= battle.hand.size() or not battle.can_use_card(index):
        return
    drag_hand_index = index
    drag_start_global_position = press_global_position
    drag_last_global_position = press_global_position
    drag_active = true
    selected_hand_index = index
    var card: Dictionary = battle.hand[index]
    var rect: Rect2 = hand_box.get_child(index).get_global_rect()
    rect.position -= global_position
    battle_presentation.start_drag(card,battle.get_effective_cost(index),rect)
    var target_type: String = battle.get_effective_target_type(index)
    if target_type == "enemy":
        selection_label.text = "%s — 敵へドラッグして離すと使用" % card.get("id", "?")
    else:
        selection_label.text = "%s — 上へドラッグして離すと使用" % card.get("id", "?")
    _refresh_enemies()

func _on_card_drag_moved(index: int, global_position: Vector2) -> void:
    if drag_active: battle_presentation.move_drag(global_position-self.global_position)
    if generation_job != null:
        return
    if not drag_active or index != drag_hand_index:
        return
    drag_last_global_position = global_position
    if index < 0 or index >= battle.hand.size():
        return
    var card: Dictionary = battle.hand[index]
    var target_type: String = battle.get_effective_target_type(index)
    if target_type == "enemy":
        var hovered_enemy: int = _enemy_index_at_global_position(global_position)
        if hovered_enemy >= 0:
            selection_label.text = "%s — #%d に使用" % [card.get("id", "?"), hovered_enemy + 1]
        else:
            selection_label.text = "%s — 対象の敵へドラッグ" % card.get("id", "?")
    else:
        selection_label.text = "%s — 上へドラッグして離すと使用" % card.get("id", "?")

func _on_card_drag_released(index: int, global_position: Vector2) -> void:
    if generation_job != null:
        return
    if not drag_active or index != drag_hand_index:
        return
    drag_active = false
    drag_last_global_position = global_position
    if index < 0 or index >= battle.hand.size():
        _reset_drag_state()
        return

    selected_hand_index = index
    var target_type: String = battle.get_effective_target_type(index)
    if target_type == "enemy":
        var enemy_index: int = _enemy_index_at_global_position(global_position)
        if enemy_index >= 0:
            _reset_drag_state(false)
            _confirm_selected_card(enemy_index)
            return
    else:
        var hand_rect: Rect2 = hand_box.get_global_rect()
        var released_above_hand: bool = global_position.y < hand_rect.position.y - 12.0
        var moved_up_enough: bool = global_position.y <= drag_start_global_position.y - 38.0
        if released_above_hand or moved_up_enough:
            _reset_drag_state(false)
            _confirm_selected_card(-1)
            return

    _reset_drag_state()

func _enemy_index_at_global_position(global_position: Vector2) -> int:
    if enemy_scroll != null and not enemy_scroll.get_global_rect().has_point(global_position):
        return -1
    for enemy_index in range(enemy_buttons.size()):
        var enemy_button: Button = enemy_buttons[enemy_index]
        if enemy_button.disabled:
            continue
        if enemy_button.get_global_rect().has_point(global_position):
            return enemy_index
    return -1

func _reset_drag_state(refresh_after: bool = true) -> void:
    if battle_presentation != null: battle_presentation.stop_drag()
    drag_hand_index = -1
    drag_start_global_position = Vector2.ZERO
    drag_last_global_position = Vector2.ZERO
    drag_active = false
    if refresh_after:
        selected_hand_index = -1
        _refresh_ui()

func _on_card_pressed(index: int) -> void:
    if _auto_input_locked(): return
    if region_run_ui!=null and region_run_ui.animation_busy: return
    if generation_job != null:
        return
    if battle.combat_over:
        return
    if index < 0 or index >= battle.hand.size():
        return

    if battle.is_hand_selection_active():
        var before: Dictionary = _visual_snapshot()
        var points: Array = _visual_enemy_points()
        battle.select_hand_for_pending(index)
        _visual_changes(before,points,hand_box.get_global_rect().get_center()-global_position)
        selected_hand_index = -1
        _refresh_ui()
        return

    if selected_hand_index == index:
        _cancel_selection()
        return

    if not battle.can_use_card(index):
        return

    selected_hand_index = index
    if battle_audio != null: battle_audio.play_cue("select")
    _refresh_ui()

func _preview_target() -> int:
    if battle.is_enemy_target_valid(hovered_enemy_index):return hovered_enemy_index
    return preview_enemy_index if battle.is_enemy_target_valid(preview_enemy_index) else -1

func _on_preview_enemy_enter(index: int) -> void:
    hovered_enemy_index=index;_update_target_previews()

func _on_preview_enemy_exit(index: int) -> void:
    if hovered_enemy_index==index:hovered_enemy_index=-1;_update_target_previews()

func _update_target_previews() -> void:
    for i in range(mini(hand_box.get_child_count(),battle.hand.size())):
        hand_box.get_child(i).apply_target_preview(BattleCardPreview.inspect(battle,i,_preview_target()))
    var index: int=selected_hand_index if selected_hand_index>=0 else hovered_hand_index
    if index>=0:prediction_label.text=_build_stable_prediction_text(index)

func _on_enemy_pressed(enemy_index: int) -> void:
    if _auto_input_locked(): return
    if _get_selected_card().is_empty():
        preview_enemy_index=enemy_index;_update_target_previews();return
    var card = _get_selected_card()
    if card.is_empty() or battle.get_effective_target_type(selected_hand_index) != "enemy":
        return
    _confirm_selected_card(enemy_index)

func _on_use_pressed() -> void:
    if _auto_input_locked(): return
    if generation_job != null:
        return
    var card = _get_selected_card()
    if card.is_empty() or battle.get_effective_target_type(selected_hand_index) == "enemy":
        return
    _confirm_selected_card(-1)

func _confirm_selected_card(target_enemy_index: int = -1) -> void:
    if _auto_input_locked(): return
    if region_run_ui!=null and region_run_ui.animation_busy: return
    if generation_job != null:
        return
    if selected_hand_index < 0:
        return
    var index = selected_hand_index
    var card_id: String = str(battle.hand[index].id)
    var attack: bool = str(battle.hand[index].get("card_type",""))=="attack"
    var finisher: bool = str(battle.hand[index].get("role",""))=="決着技"
    var visual_attribute: String=str(battle.hand[index].get("attribute","物理"))
    var card: Dictionary = battle.hand[index].duplicate(true)
    var card_rect: Rect2 = hand_box.get_child(index).get_global_rect()
    card_rect.position -= global_position
    var before: Dictionary = _visual_snapshot()
    var points: Array = _visual_enemy_points()
    selected_hand_index = -1
    var hp_before: int=battle.player_hp
    var damage_before: int=int(battle.playtest_stats.get("damage_dealt",0))
    var used: bool = battle.use_card(index, target_enemy_index)
    if used:
        if action_journal != null: action_journal.record_action(battle, "card", card_id, target_enemy_index)
        var destination: Vector2 = points[target_enemy_index] if target_enemy_index>=0 and target_enemy_index<points.size() else _visual_player_point()
        battle_presentation.card_flight(card_id,card_rect,destination,attack)
        battle_presentation.weapon_glyph(str(card.get("weapon", "")), destination, finisher)
        if battle_audio != null: battle_audio.play_cue("finisher" if finisher else "use", str(card.get("weapon", "")), visual_attribute)
        _visual_changes(before,points,card_rect.get_center())
        if finisher:battle_presentation.glyph(visual_attribute,destination,true)
        # Already-resolved card effects and BattlePresentation event values.
        if battle_3h_bridge != null:
            battle_3h_bridge.queue_card(card,battle_presentation.last_events,target_enemy_index,float(ux_preferences.speed),BattlePresentation.quality)
    _refresh_ui()
    if region_run_ui!=null: region_run_ui.animate_battle(maxi(0,hp_before-battle.player_hp),int(battle.playtest_stats.get("damage_dealt",0))-damage_before)

func _cancel_selection() -> void:
    if battle.is_hand_selection_active():
        return
    if selected_hand_index >= 0 and battle_audio != null: battle_audio.play_cue("cancel")
    selected_hand_index = -1
    _refresh_ui()

func _on_end_turn_pressed() -> void:
    if _auto_input_locked(): return
    if region_run_ui!=null and region_run_ui.animation_busy: return
    if generation_job != null:
        return
    selected_hand_index = -1
    var before: Dictionary = _visual_snapshot()
    var points: Array = _visual_enemy_points()
    var hp_before: int=battle.player_hp
    var damage_before: int=int(battle.playtest_stats.get("damage_dealt",0))
    if action_journal != null: action_journal.record_action(battle, "end_turn")
    battle.end_player_turn()
    _visual_changes(before,points,enemy_box.get_global_rect().get_center()-global_position)
    if battle_3h_bridge != null:
        battle_3h_bridge.queue_enemy_turn(battle_presentation.last_events,float(ux_preferences.speed),BattlePresentation.quality)
    _refresh_ui()
    if region_run_ui!=null: region_run_ui.animate_battle(maxi(0,hp_before-battle.player_hp),int(battle.playtest_stats.get("damage_dealt",0))-damage_before)

func _on_restart_pressed() -> void:
    battle_presentation.clear_effects()
    if battle_3h_bridge != null: battle_3h_bridge.reset_display()
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    selected_hand_index = -1
    var seed_value = 1001 if seed_input == null else int(seed_input.value)
    battle.start_battle(seed_value, current_battle_deck_ids, current_enemy_preset, current_loadout_snapshot)
    if action_journal != null: action_journal.begin(battle)
    _rebuild_enemy_buttons()
    _hide_pile_info()
    _refresh_ui()

func _on_retry_same_pressed() -> void:
    battle_presentation.clear_effects()
    if battle_3h_bridge != null: battle_3h_bridge.reset_display()
    if region_run_ui!=null and region_run_ui.locked(): return
    selected_hand_index = -1
    var seed_value = battle.get_active_seed()
    seed_input.value = seed_value
    battle.start_battle(seed_value, current_battle_deck_ids, current_enemy_preset, current_loadout_snapshot)
    if action_journal != null: action_journal.begin(battle)
    _rebuild_enemy_buttons()
    _hide_pile_info()
    _refresh_ui()

func _on_return_to_setup_pressed() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    selected_hand_index = -1
    _refresh_setup_ui()
    _refresh_loadout_ui()
    tab_container.current_tab = 1

func _on_open_loadout_pressed() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    selected_hand_index = -1
    _refresh_loadout_ui()
    tab_container.current_tab = 2

func _on_open_playtest_pressed() -> void:
    selected_hand_index = -1
    _refresh_playtest_ui()
    tab_container.current_tab = 3

func _on_battle_dev_button_pressed() -> void:
    if developer_panel == null:
        return
    developer_panel.visible = not developer_panel.visible
    if battle_dev_button != null:
        battle_dev_button.text = "開発を閉じる" if developer_panel.visible else "開発"

func _on_battle_log_button_pressed() -> void:
    if log_panel == null:
        return
    log_panel.visible = not log_panel.visible
    if battle_log_button != null:
        battle_log_button.text = "ログを閉じる" if log_panel.visible else "ログ"

func _on_debug_card(card_id: String) -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    battle.add_debug_card_to_hand(card_id)
    _refresh_ui()

func _on_add_catalog_card() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if card_id_input == null:
        return
    var card_id = card_id_input.text.strip_edges().to_upper()
    if card_id == "":
        return
    battle.add_debug_card_to_hand(card_id)
    _refresh_ui()

func _on_run_validation() -> void:
    var runner = CardValidationRunnerScript.new()
    var result: Dictionary = runner.run_all()
    var lines: Array[String] = []
    lines.append("Result: %s   PASS %d   FAIL %d   WARN %d" % [
        "PASS" if bool(result.get("ok", false)) else "FAIL",
        int(result.get("passed", 0)),
        int(result.get("failed", 0)),
        int(result.get("warnings", 0))
    ])
    for line in result.get("scenario_lines", []):
        lines.append(str(line))
    var failure_lines: Array = result.get("failures", [])
    if not failure_lines.is_empty():
        lines.append("--- FAILURES ---")
        for line in failure_lines:
            lines.append(str(line))
    var warning_lines: Array = result.get("warning_lines", [])
    if not warning_lines.is_empty():
        lines.append("--- WARNINGS ---")
        for line in warning_lines:
            lines.append(str(line))
    validation_view.visible = true
    validation_view.text = "\n".join(lines)

func _on_run_batch_simulation() -> void:
    var runner = BattleSimulationRunnerScript.new()
    var result: Dictionary = runner.run_all()
    var lines: Array[String] = []
    lines.append("v1.7.0 Batch: %s   PASS %d   FAIL %d   WARN %d" % [
        "PASS" if bool(result.get("ok", false)) else "FAIL",
        int(result.get("passed", 0)),
        int(result.get("failed", 0)),
        int(result.get("warnings", 0))
    ])
    for line in result.get("scenario_lines", []):
        lines.append(str(line))
    var failure_lines: Array = result.get("failures", [])
    if not failure_lines.is_empty():
        lines.append("--- FAILURES ---")
        for line in failure_lines:
            lines.append(str(line))
    validation_view.visible = true
    validation_view.text = "\n".join(lines)


func _on_run_battle_core_regression() -> void:
    var runner = BattleCoreRegressionRunnerScript.new()
    var result: Dictionary = runner.run_all()
    var output: Array[String] = []
    output.append("v1.7.0 Battle Core Gate: %s   PASS %d   FAIL %d   WARN %d" % [
        "PASS" if bool(result.get("ok", false)) else "FAIL",
        int(result.get("passed", 0)),
        int(result.get("failed", 0)),
        int(result.get("warnings", 0))
    ])
    for line in result.get("lines", []):
        output.append(str(line))
    var failure_lines: Array = result.get("failures", [])
    if not failure_lines.is_empty():
        output.append("--- FAILURES ---")
        for line in failure_lines:
            output.append(str(line))
    var warning_lines: Array = result.get("warning_lines", [])
    if not warning_lines.is_empty():
        output.append("--- WARNINGS ---")
        for line in warning_lines:
            output.append(str(line))
    validation_view.visible = true
    validation_view.text = "\n".join(output)

func _on_run_battle_result_validation() -> void:
    var runner = BattleResultValidationRunnerScript.new()
    var result: Dictionary = runner.run_all()
    var output: Array[String] = []
    output.append("v1.7.0 BattleResult Gate: %s   PASS %d   FAIL %d" % [
        "PASS" if bool(result.get("ok", false)) else "FAIL",
        int(result.get("passed", 0)),
        int(result.get("failed", 0))
    ])
    for line in result.get("lines", []):
        output.append(str(line))
    var failure_lines: Array = result.get("failures", [])
    if not failure_lines.is_empty():
        output.append("--- FAILURES ---")
        for line in failure_lines:
            output.append(str(line))
    validation_view.visible = true
    validation_view.text = "\n".join(output)

func _on_debug_trait(trait_name: String) -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    battle.add_debug_weapon_trait(trait_name, 1)
    _refresh_ui()

func _on_debug_attribute_trait(trait_name: String) -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    battle.add_debug_attribute_trait(trait_name, 3)
    _refresh_ui()

func _on_debug_enemy_attribute_trait(enemy_index: int, trait_name: String) -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    battle.add_debug_enemy_attribute_trait(enemy_index, trait_name, 3)
    _refresh_ui()

func _on_debug_prepare_execution() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    battle.debug_prepare_execution_target(2)
    _refresh_ui()

func _on_debug_damage_player() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    battle.debug_damage_player(10)
    _refresh_ui()

func _show_draw_pile_info() -> void:
    _open_pile_screen(
        "デッキ  %d枚" % battle.draw_pile.size(),
        "現在の残り山札を順不同で表示します。ドロー順は公開しません。",
        battle.draw_pile
    )

func _show_discard_info() -> void:
    _open_pile_screen(
        "捨て場  %d枚" % battle.discard_pile.size(),
        "現在の捨て場にあるカード一覧です。",
        battle.discard_pile
    )

func _show_salvage_selection() -> void:
    if pile_overlay == null or pile_overlay_grid == null or not battle.is_salvage_selection_active():
        return
    pile_overlay_title.text = "サルベージ：回収するカードを選択"
    pile_overlay_subtitle.text = "捨て札のカードをタップすると即座に手札へ移動します。選択を完了するまで戦闘操作はできません。"
    if pile_overlay_close != null:
        pile_overlay_close.disabled = true
    _clear_container(pile_overlay_grid)
    var indexes: Array[int] = battle.get_salvage_selectable_indices()
    pile_overlay_empty.visible = indexes.is_empty()
    for i in indexes:
        var c: Dictionary = battle.discard_pile[i]
        var choice: Button = Button.new()
        choice.text = "%s  Cost%d\n%s / %s\n%s" % [
            str(c.get("id", "?")), int(c.get("cost", 0)),
            str(c.get("attribute", "?")), str(c.get("weapon", "?")),
            str(c.get("role", "?"))]
        choice.tooltip_text = str(c.get("text", ""))
        choice.custom_minimum_size = Vector2(0, 92)
        choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choice.pressed.connect(_on_salvage_choice.bind(i))
        pile_overlay_grid.add_child(choice)
    pile_overlay.visible = true

func _on_salvage_choice(discard_index: int) -> void:
    if _auto_input_locked(): return
    if region_run_ui!=null and region_run_ui.animation_busy: return
    if generation_job != null:
        return
    if battle == null or not battle.is_salvage_selection_active():
        return
    if battle.select_discard_for_pending(discard_index):
        if pile_overlay != null:
            pile_overlay.visible = false
        _refresh_ui()

func _show_exhaust_info() -> void:
    _open_pile_screen(
        "除外  0枚",
        "現行120枚Battle Coreでは除外領域を使用しません。将来の拡張用表示です。",
        []
    )

func _open_pile_screen(title_text: String, subtitle_text: String, cards: Array) -> void:
    if pile_overlay == null or pile_overlay_grid == null:
        return
    pile_overlay_title.text = title_text
    pile_overlay_subtitle.text = subtitle_text
    _clear_container(pile_overlay_grid)

    var counts: Dictionary = {}
    var representatives: Dictionary = {}
    for raw_card in cards:
        var card: Dictionary = raw_card
        var card_id = str(card.get("id", "?"))
        counts[card_id] = int(counts.get(card_id, 0)) + 1
        if not representatives.has(card_id):
            representatives[card_id] = card

    var ids: Array = counts.keys()
    ids.sort()
    pile_overlay_empty.visible = ids.is_empty()

    for raw_id in ids:
        var card_id = str(raw_id)
        var card: Dictionary = representatives.get(card_id, {})
        var amount = int(counts.get(card_id, 0))
        var button = Button.new()
        var count_text = "  ×%d" % amount if amount > 1 else ""
        button.text = "%s%s    Cost %d\n%s / %s\n%s" % [
            card_id,
            count_text,
            int(card.get("cost", 0)),
            card.get("attribute", "-"),
            card.get("weapon", "-"),
            card.get("role", "-")
        ]
        button.tooltip_text = _describe_static_card(card)
        button.custom_minimum_size = Vector2(0, 92)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.focus_mode = Control.FOCUS_NONE
        pile_overlay_grid.add_child(button)

    pile_overlay.visible = true

func _close_pile_screen() -> void:
    if battle != null and battle.is_salvage_selection_active():
        return
    if pile_overlay != null:
        pile_overlay.visible = false

func _hide_pile_info() -> void:
    _close_pile_screen()

func _refresh_setup_ui() -> void:
    if setup_card_list == null or deck_builder == null:
        return
    _refresh_setup_card_list()
    _refresh_setup_deck_list()
    var source_text = " | Source: Manual deck" if pending_loadout_snapshot.is_empty() else " | Source: Equipment loadout (6×4)"
    setup_status_label.text = deck_builder.get_status_text() + source_text
    setup_start_button.disabled = not deck_builder.is_ready()

func _refresh_setup_card_list() -> void:
    if setup_card_list == null:
        return
    var previous_id = setup_selected_card_id
    setup_card_list.clear()
    var attribute_filter: String = str(ATTRIBUTES[setup_attribute_filter.selected])
    var weapon_filter: String = str(WEAPONS[setup_weapon_filter.selected])
    var role_filter: String = str(ROLES[setup_role_filter.selected])
    var query = setup_search_input.text if setup_search_input != null else ""
    var ids = deck_builder.get_filtered_card_ids(attribute_filter, weapon_filter, role_filter, query)
    var restore_index = -1
    for card_id in ids:
        var card = deck_builder.get_card(card_id)
        setup_card_list.add_item("%s | %s | %s | %s | C%d" % [
            card_id,
            card.get("attribute", "-"),
            card.get("weapon", "-"),
            card.get("role", "-"),
            int(card.get("cost", 0))
        ])
        var index = setup_card_list.get_item_count() - 1
        setup_card_list.set_item_metadata(index, card_id)
        if card_id == previous_id:
            restore_index = index
    if restore_index >= 0:
        setup_card_list.select(restore_index)

func _refresh_setup_deck_list() -> void:
    if setup_deck_list == null:
        return
    setup_deck_list.clear()
    var counts = deck_builder.get_deck_count_map()
    var ids: Array = counts.keys()
    ids.sort()
    for raw_id in ids:
        var card_id = str(raw_id)
        var card = deck_builder.get_card(card_id)
        setup_deck_list.add_item("%s ×%d | %s / %s / %s" % [
            card_id,
            int(counts.get(card_id, 0)),
            card.get("attribute", "-"),
            card.get("weapon", "-"),
            card.get("role", "-")
        ])
        var index = setup_deck_list.get_item_count() - 1
        setup_deck_list.set_item_metadata(index, card_id)

func _on_setup_filter_changed(_index: int) -> void:
    _refresh_setup_card_list()

func _on_setup_search_changed(_new_text: String) -> void:
    _refresh_setup_card_list()

func _on_setup_card_selected(index: int) -> void:
    if index < 0 or index >= setup_card_list.get_item_count():
        return
    setup_selected_card_id = str(setup_card_list.get_item_metadata(index))
    setup_card_detail.text = deck_builder.describe_card(setup_selected_card_id)

func _on_setup_card_activated(index: int) -> void:
    if generation_job != null:
        return
    _on_setup_card_selected(index)
    _on_setup_add_selected()

func _on_setup_add_selected() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    if setup_selected_card_id == "":
        return
    deck_builder.add_card(setup_selected_card_id)
    pending_loadout_snapshot.clear()
    _refresh_setup_ui()

func _on_setup_remove_selected() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    var selected = setup_deck_list.get_selected_items()
    if selected.is_empty():
        return
    var index = int(selected[0])
    var card_id = str(setup_deck_list.get_item_metadata(index))
    deck_builder.remove_one(card_id)
    pending_loadout_snapshot.clear()
    _refresh_setup_ui()

func _on_setup_load_prototype() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    deck_builder.load_prototype_deck()
    pending_loadout_snapshot.clear()
    _refresh_setup_ui()

func _on_setup_clear_deck() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    deck_builder.clear_deck()
    pending_loadout_snapshot.clear()
    _refresh_setup_ui()

func _on_setup_start_battle() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    if not deck_builder.is_ready():
        setup_status_label.text = deck_builder.get_status_text() + " — battle requires exactly 24 cards."
        return
    current_battle_deck_ids = deck_builder.get_deck_ids()
    current_loadout_snapshot = pending_loadout_snapshot.duplicate(true)
    var selected_preset_index = setup_enemy_preset.selected
    if selected_preset_index >= 0 and selected_preset_index < setup_enemy_preset_ids.size():
        current_enemy_preset = setup_enemy_preset_ids[selected_preset_index]
    else:
        current_enemy_preset = "standard_trio"
    var seed_value = int(setup_seed_input.value)
    seed_input.value = seed_value
    selected_hand_index = -1
    battle.start_battle(seed_value, current_battle_deck_ids, current_enemy_preset, current_loadout_snapshot)
    _rebuild_enemy_buttons()
    _hide_pile_info()
    tab_container.current_tab = 0
    _refresh_ui()

func _refresh_loadout_ui() -> void:
    if loadout_builder == null or loadout_preview == null:
        return
    for slot_id in loadout_builder.equipment_db.get_slot_ids():
        var selector: OptionButton = loadout_selectors.get(slot_id)
        var ids: Array = loadout_selector_item_ids.get(slot_id, [])
        if selector == null:
            continue
        var selected_id = loadout_builder.get_selected_item_id(slot_id)
        var index = ids.find(selected_id)
        selector.select(max(0, index))
    loadout_status_label.text = ("Valid 24-card loadout | Max HP %d" % loadout_builder.calculate_player_max_hp()) if loadout_builder.is_valid() else "INVALID LOADOUT"
    loadout_preview.text = loadout_builder.get_summary_text()

func _on_loadout_slot_changed(index: int, slot_id: String) -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    var ids: Array = loadout_selector_item_ids.get(slot_id, [])
    if index < 0 or index >= ids.size():
        return
    loadout_builder.set_equipment(slot_id, str(ids[index]))
    _refresh_loadout_ui()

func _on_loadout_prototype() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    loadout_builder.load_prototype_loadout()
    _refresh_loadout_ui()

func _on_loadout_unequip_all() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    loadout_builder.unequip_all()
    _refresh_loadout_ui()

func _on_loadout_apply_to_setup() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    if not loadout_builder.is_valid():
        loadout_status_label.text = "Cannot apply: loadout is invalid."
        return
    var deck_ids = loadout_builder.build_deck_ids()
    if not deck_builder.set_deck_ids(deck_ids):
        loadout_status_label.text = "Cannot apply: generated deck was rejected."
        return
    pending_loadout_snapshot = loadout_builder.get_snapshot()
    _refresh_setup_ui()
    tab_container.current_tab = 1

func _on_loadout_validate() -> void:
    var runner = LoadoutValidationRunnerScript.new()
    var result: Dictionary = runner.run_all()
    var out: Array[String] = []
    out.append("Loadout validation: %s | PASS %d | FAIL %d" % ["PASS" if bool(result.get("ok", false)) else "FAIL", int(result.get("passed", 0)), int(result.get("failed", 0))])
    for line in result.get("lines", []):
        out.append(str(line))
    if not result.get("failures", []).is_empty():
        out.append("--- FAILURES ---")
        for line in result.get("failures", []):
            out.append(str(line))
    loadout_validation_view.visible = true
    loadout_validation_view.text = "\n".join(out)

func _describe_static_card(card: Dictionary) -> String:
    var target_type = str(card.get("target_type", "none"))
    var target_label = "敵1体" if target_type == "enemy" else ("自分" if target_type == "self" else "対象不要")
    return "%s | %s / %s / %s\nCost %d | Target: %s\n%s" % [
        card.get("id", "?"),
        card.get("attribute", "-"),
        card.get("weapon", "-"),
        card.get("role", "-"),
        int(card.get("cost", 0)),
        target_label,
        WeaponTraitCardDescription.combined_text(card)
    ]

func _describe_runtime_card(card: Dictionary, hand_index: int) -> String:
    var target_type: String = battle.get_effective_target_type(hand_index)
    var target_label: String = "敵1体" if target_type == "enemy" else ("自分" if target_type == "self" else "対象不要")
    var lines: Array[String] = []
    lines.append("%s | %s / %s / %s" % [card.get("id", "?"), card.get("attribute", "-"), card.get("weapon", "-"), card.get("role", "-")])
    lines.append("Printed Cost %d → %s | Target: %s" % [int(card.get("cost", 0)), battle.get_cost_preview_text(hand_index), target_label])
    lines.append(WeaponTraitCardDescription.combined_text(card,1 if _weapon_trait_will_be_consumed(card,hand_index) else 0))
    lines.append("")
    lines.append_array(_build_use_preview_lines(card, hand_index))
    lines.append_array(_build_result_preview_lines(card, hand_index))
    return "\n".join(lines)

func _build_use_preview_lines(card: Dictionary, hand_index: int) -> Array[String]:
    var lines: Array[String] = []
    lines.append("【使用予測】")
    var effective_cost: int = battle.get_effective_cost(hand_index)
    lines.append("Mana %d → %d" % [battle.current_mana, max(0, battle.current_mana - effective_cost)])

    var weapon_trait_name: String = str(card.get("weapon_trait", ""))
    var weapon_action: String = str(card.get("weapon_trait_action", "NEUTRAL"))
    var weapon_before: bool = bool(battle.weapon_traits.get(weapon_trait_name, false)) if weapon_trait_name != "" else false
    var weapon_consumed: bool = _weapon_trait_will_be_consumed(card, hand_index)

    if weapon_trait_name != "":
        if weapon_action == "SET":
            lines.append("%s %s → ON  / SET" % [weapon_trait_name, "ON" if weapon_before else "OFF"])
        elif weapon_action == "CONSUME":
            if weapon_consumed:
                lines.append("%s ON → OFF  / 発動: %s" % [weapon_trait_name, _weapon_trait_activation_summary(card)])
            else:
                lines.append("%s OFF  / CONSUME効果なし" % weapon_trait_name)

    var attribute_trait_name: String = str(card.get("attribute_trait", ""))
    var attribute_gain: int = int(card.get("attribute_trait_gain", 0))
    if attribute_gain > 0 and weapon_trait_name == "魔導" and weapon_action == "CONSUME" and weapon_before:
        attribute_gain += 2

    if attribute_trait_name != "" and attribute_gain > 0:
        if _is_enemy_attribute_trait(attribute_trait_name):
            var enemy_line: String = "対象の%s +%d" % [attribute_trait_name, attribute_gain]
            if int(card.get("extra_attribute_gain_on_condition", 0)) > 0:
                enemy_line += "（条件成立時はさらに増加）"
            enemy_line += "  / %s" % _attribute_activation_summary(attribute_trait_name)
            lines.append(enemy_line)
        else:
            var attribute_before: int = battle.get_attribute_trait(attribute_trait_name)
            var attribute_after: int = attribute_before + attribute_gain
            var before_stage: int = int(floor(float(attribute_before) / 3.0))
            var after_stage: int = int(floor(float(attribute_after) / 3.0))
            var attribute_line: String = "%s %d → %d" % [attribute_trait_name, attribute_before, attribute_after]
            if after_stage > before_stage:
                attribute_line += "  / 段階%d→%d: %s" % [before_stage, after_stage, _attribute_activation_summary(attribute_trait_name)]
            else:
                attribute_line += "  / 3ごとに: %s" % _attribute_activation_summary(attribute_trait_name)
            lines.append(attribute_line)

    return lines

func _clone_battle_for_preview() -> BattleController:
    var clone = BattleController.new()
    clone.database = battle.database
    clone.battle_rng.state = battle.battle_rng.state
    clone.active_seed = battle.active_seed
    clone.active_enemy_preset = battle.active_enemy_preset
    clone.active_equipment_loadout = battle.active_equipment_loadout.duplicate(true)
    clone.equipment_special_effects.clear()
    for effect in battle.equipment_special_effects:
        clone.equipment_special_effects.append(effect.duplicate(true))

    clone.draw_pile = battle.draw_pile.duplicate(true)
    clone.hand = battle.hand.duplicate(true)
    clone.discard_pile = battle.discard_pile.duplicate(true)
    clone.power_zone.clear()
    for power_card in battle.power_zone:
        clone.power_zone.append(power_card.duplicate(true))
    clone.resolving_card = battle.resolving_card.duplicate(true)

    clone.player_max_hp = battle.player_max_hp
    clone.player_hp = battle.player_hp
    clone.player_block = battle.player_block
    clone.current_mana = battle.current_mana
    clone.weapon_traits = battle.weapon_traits.duplicate(true)
    clone.attribute_traits = battle.attribute_traits.duplicate(true)
    clone.swift_cost_reduction_charges = battle.swift_cost_reduction_charges
    clone.curse_lifesteal_used = battle.curse_lifesteal_used
    clone.continuous_effects = battle.continuous_effects.duplicate(true)
    clone.power_trait_engines = battle.power_trait_engines.duplicate(true)
    clone.first_attack_engine_used = battle.first_attack_engine_used
    clone.first_magic_orb_engine_used = battle.first_magic_orb_engine_used
    clone.first_swift_engine_used = battle.first_swift_engine_used
    clone.first_slow_engine_used = battle.first_slow_engine_used
    clone.first_retaliation_engine_used = battle.first_retaliation_engine_used

    clone.turn_number = battle.turn_number
    clone.combat_over = battle.combat_over
    clone.victory = battle.victory
    clone.battle_result = battle.battle_result.duplicate(true)
    clone.battle_end_reason = battle.battle_end_reason
    clone.logs.clear()
    for line in battle.logs:
        clone.logs.append(str(line))
    clone.last_notice = battle.last_notice
    clone.battle_deck_ids.clear()
    for card_id in battle.battle_deck_ids:
        clone.battle_deck_ids.append(str(card_id))
    clone.playtest_stats = battle.playtest_stats.duplicate(true)
    clone.pending_hand_selection = battle.pending_hand_selection.duplicate(true)
    clone.enemies = battle.enemies.duplicate(true)
    clone.region1_player_status = battle.region1_player_status.duplicate(true)
    clone.region1_support = battle.region1_support.duplicate(true)
    clone.campaign_status = battle.campaign_status.duplicate(true)
    return clone

func _finish_preview_hand_selection(sim: BattleController) -> void:
    var guard: int = 0
    while sim.is_hand_selection_active() and guard < 12:
        if sim.is_salvage_selection_active():
            var targets = sim.get_salvage_selectable_indices()
            if targets.is_empty():
                break
            sim.select_discard_for_pending(targets[0])
        elif not sim.hand.is_empty():
            sim.select_hand_for_pending(0)
        else:
            break
        guard += 1

func _changed_enemy_status_parts(before_enemy: Dictionary, after_enemy: Dictionary) -> Array[String]:
    var parts: Array[String] = []
    var before_vulnerable: int = int(before_enemy.get("vulnerable", 0))
    var after_vulnerable: int = int(after_enemy.get("vulnerable", 0))
    if before_vulnerable != after_vulnerable:
        parts.append("脆弱 %d→%d" % [before_vulnerable, after_vulnerable])

    var before_traits: Dictionary = before_enemy.get("attribute_traits", {})
    var after_traits: Dictionary = after_enemy.get("attribute_traits", {})
    for trait_name in ["爆発", "鈍化", "呪印", "猛毒"]:
        var before_amount: int = int(before_traits.get(trait_name, 0))
        var after_amount: int = int(after_traits.get(trait_name, 0))
        if before_amount != after_amount:
            parts.append("%s %d→%d" % [trait_name, before_amount, after_amount])
    return parts

func _build_result_preview_lines(card: Dictionary, hand_index: int) -> Array[String]:
    var lines: Array[String] = []
    var target_type: String = battle.get_effective_target_type(hand_index)
    lines.append("")
    lines.append("【使用後予測】")

    if target_type == "enemy":
        var any_target: bool = false
        for enemy_index in range(battle.get_enemy_count()):
            if not battle.is_enemy_target_valid(enemy_index):
                continue
            any_target = true
            var before_enemy: Dictionary = battle.get_enemy(enemy_index).duplicate(true)
            var sim: BattleController = _clone_battle_for_preview()
            if not sim.use_card(hand_index, enemy_index):
                continue
            _finish_preview_hand_selection(sim)
            var after_enemy: Dictionary = sim.get_enemy(enemy_index)
            var enemy_name: String = _compact_enemy_name(str(before_enemy.get("name", "Enemy")))
            var result_parts: Array[String] = []

            var before_hp: int = int(before_enemy.get("hp", 0))
            var after_hp: int = int(after_enemy.get("hp", 0))
            if before_hp != after_hp:
                result_parts.append("HP %d→%d" % [before_hp, after_hp])
            var before_block: int = int(before_enemy.get("block", 0))
            var after_block: int = int(after_enemy.get("block", 0))
            if before_block != after_block:
                result_parts.append("Block %d→%d" % [before_block, after_block])
            result_parts.append_array(_changed_enemy_status_parts(before_enemy, after_enemy))
            if after_hp <= 0 and before_hp > 0:
                result_parts.append("撃破")
            if result_parts.is_empty():
                result_parts.append("敵状態変化なし")
            lines.append("#%d %s: %s" % [enemy_index + 1, enemy_name, " / ".join(result_parts)])

            var player_parts: Array[String] = []
            if battle.player_hp != sim.player_hp:
                player_parts.append("HP %d→%d" % [battle.player_hp, sim.player_hp])
            if battle.player_block != sim.player_block:
                player_parts.append("Block %d→%d" % [battle.player_block, sim.player_block])
            if not player_parts.is_empty():
                lines.append("   自分: %s" % " / ".join(player_parts))
        if not any_target:
            lines.append("有効な敵対象がありません。")
        return lines

    var sim: BattleController = _clone_battle_for_preview()
    if not sim.use_card(hand_index, -1):
        lines.append("現在は使用できません。")
        return lines
    _finish_preview_hand_selection(sim)
    var player_parts: Array[String] = []
    if battle.player_hp != sim.player_hp:
        player_parts.append("HP %d→%d" % [battle.player_hp, sim.player_hp])
    if battle.player_block != sim.player_block:
        player_parts.append("Block %d→%d" % [battle.player_block, sim.player_block])
    if battle.current_mana != sim.current_mana:
        player_parts.append("Mana %d→%d" % [battle.current_mana, sim.current_mana])
    if player_parts.is_empty():
        player_parts.append("即時のHP / Block変化なし")
    lines.append("自分: %s" % " / ".join(player_parts))
    return lines

func _weapon_trait_will_be_consumed(card: Dictionary, hand_index: int) -> bool:
    if str(card.get("weapon_trait_action", "NEUTRAL")) != "CONSUME":
        return false
    var weapon: String = str(card.get("weapon", ""))
    var is_attack: bool = str(card.get("card_type", "")) == "attack"
    if weapon == "刀":
        return bool(card.get("iai_compatible", false)) and bool(battle.weapon_traits.get("納刀", false)) and battle.get_effective_cost(hand_index) == 0
    if weapon == "片手剣":
        return bool(battle.weapon_traits.get("流転", false))
    if weapon == "レイピア":
        return is_attack and bool(battle.weapon_traits.get("精密", false))
    if weapon == "短剣":
        return is_attack and bool(battle.weapon_traits.get("連刃", false))
    if weapon == "大剣":
        return is_attack and bool(battle.weapon_traits.get("重撃", false))
    if weapon == "魔法剣":
        return int(card.get("attribute_trait_gain", 0)) > 0 and bool(battle.weapon_traits.get("魔導", false))
    return false

func _weapon_trait_activation_summary(card: Dictionary) -> String:
    var weapon: String = str(card.get("weapon", ""))
    if weapon == "片手剣":
        return "AttackならBlock変換 / 防御なら追加ダメージ"
    if weapon == "レイピア":
        return "Block Ignore または攻撃後に脆弱"
    if weapon == "短剣":
        return "Attackを同ダメージの2Hit化"
    if weapon == "大剣":
        return "Attackダメージ×1.5"
    if weapon == "魔法剣":
        return "このカードの属性特性獲得量+2"
    if weapon == "刀":
        return "居合Cost0、決着技なら処刑判定"
    return "武器特性発動"

func _is_enemy_attribute_trait(trait_name: String) -> bool:
    return trait_name in ["爆発", "鈍化", "呪印", "猛毒"]

func _attribute_activation_summary(trait_name: String) -> String:
    match trait_name:
        "剛力": return "Attackカードのダメージ+1/段階"
        "爆発": return "新規3/6/9…到達時に即時爆発ダメージ"
        "鈍化": return "敵Attack行動合計ダメージ-2/段階"
        "帯電": return "敵Attack終了後に3反撃ダメージ/段階"
        "堅牢": return "次Player turn開始時Block2/段階"
        "恩寵": return "次Player turn開始時HP1回復/段階"
        "呪印": return "そのターン最初のAttackでHP2回復/段階"
        "猛毒": return "Enemy turn終了時2ダメージ/段階"
        "魔珠": return "新規3/6/9…到達ごとにMana1回復"
        "疾風": return "新規3/6/9…到達ごとに次カードCost-1"
    return "3スタックごとに効果強化"

func _unhandled_input(event: InputEvent) -> void:
    if pile_overlay != null and pile_overlay.visible and event.is_action_pressed("ui_cancel"):
        _close_pile_screen()
        get_viewport().set_input_as_handled()

func _get_selected_card() -> Dictionary:
    if selected_hand_index < 0 or selected_hand_index >= battle.hand.size():
        return {}
    return battle.hand[selected_hand_index]


# -----------------------------------------------------------------------------
# STEP8 108-template equipment roll / 6-slot generated run deck
# -----------------------------------------------------------------------------
func _build_step8_tab() -> void:
    var scroll = ScrollContainer.new()
    scroll.name = "120装備抽選"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tab_container.add_child(scroll)
    step8_tab_index = tab_container.get_tab_count() - 1
    var root = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 9)
    scroll.add_child(root)

    var title = Label.new()
    title.text = "STEP 8 | 108装備テンプレート → 固定2 + ランダム2 → 24枚デッキ"
    title.add_theme_font_size_override("font_size", 23)
    root.add_child(title)
    var warning = Label.new()
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    warning.text = "初回に受け取る6装備はすべてCommon（ソケット0）。完成SC2組以上、Mana3からの特性利用手順、無条件Drawカード2枚以上を確認して生成します。初手での成立を保証するものではありません。入手済み装備は再抽選されません。装備特殊効果は無効です。"
    root.add_child(warning)

    var seed_row = HBoxContainer.new()
    root.add_child(seed_row)
    var seed_label = Label.new()
    seed_label.text = "装備入手Seed: "
    seed_row.add_child(seed_label)
    step8_seed_input = SpinBox.new()
    step8_seed_input.min_value = 1
    step8_seed_input.max_value = 999999999
    step8_seed_input.step = 1
    step8_seed_input.value = 20261008
    step8_seed_input.custom_minimum_size = Vector2(180, 0)
    seed_row.add_child(step8_seed_input)

    var defaults = {"main_weapon": "SWORD", "offhand": "SCABBARD", "head": "CIRCLET", "body": "COAT", "hands": "GLOVES", "feet": "BOOTS"}
    step8_template_selectors.clear()
    step8_template_ids.clear()
    for slot_id in loadout_builder.equipment_db.get_slot_ids():
        var line = HBoxContainer.new()
        root.add_child(line)
        var label = Label.new()
        label.text = loadout_builder.equipment_db.get_slot_label(slot_id)
        label.custom_minimum_size = Vector2(140, 0)
        line.add_child(label)
        var selector = OptionButton.new()
        selector.custom_minimum_size = Vector2(520, 0)
        line.add_child(selector)
        var ids: Array[String] = []
        var default_index := 0
        var templates = step8_roller.get_templates_for_slot(slot_id)
        for t in templates:
            # Initial gift is Common only; base-type choice and synergy search remain.
            if str(t.get("Rarity", "")) != "Common": continue
            var tid = str(t.get("EquipmentID", ""))
            selector.add_item("[%s] %s (%s)" % [str(t.get("Rarity", "?")), str(t.get("DisplayName", tid)), tid])
            ids.append(tid)
            if str(t.get("BaseCode", "")) == str(defaults.get(slot_id, "")) and str(t.get("Rarity", "")) == "Common":
                default_index = ids.size() - 1
        if not ids.is_empty():
            selector.select(default_index)
        step8_template_selectors[slot_id] = selector
        step8_template_ids[slot_id] = ids
    var controls = HBoxContainer.new()
    root.add_child(controls)
    var generate = Button.new()
    generate.text = "この6装備を入手・抽選"
    generate.pressed.connect(_on_step8_generate)
    controls.add_child(generate)
    generation_cancel_button = Button.new()
    generation_cancel_button.text = "生成を取消"
    generation_cancel_button.disabled = true
    generation_cancel_button.pressed.connect(_cancel_generation)
    controls.add_child(generation_cancel_button)
    var apply = Button.new()
    apply.text = "24枚を設定に反映"
    apply.pressed.connect(_on_step8_apply)
    controls.add_child(apply)
    var start = Button.new()
    start.text = "この装備で戦闘開始"
    start.pressed.connect(_on_step8_start_battle)
    controls.add_child(start)
    step8_status = Label.new()
    step8_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(step8_status)
    step8_preview = RichTextLabel.new()
    step8_preview.custom_minimum_size = Vector2(0, 430)
    step8_preview.bbcode_enabled = false
    root.add_child(step8_preview)
    _step8_refresh()

func _on_step8_open() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    tab_container.current_tab = step8_tab_index
    _step8_refresh()

# Hub one-click claim: if the current NEW GAME has no minted package, run the
# already-approved asynchronous six-item synergy generator, then adopt only a
# successfully validated complete Common package. No fallback to random items.
func _on_hub_claim_initial() -> void:
    if region_run_ui == null or region_run_ui.locked():
        return
    if bool(region_run_ui.run.state.get("initial_claimed", false)):
        region_run_ui.run.notice = "初期6装備は受取済みです。装備・倉庫で確認できます。"
        return
    if generation_job != null:
        region_run_ui.run.notice = "初期装備を生成中です。完了するまでお待ちください。"
        return
    if step8_items.size() == 6:
        _finish_hub_initial_claim()
        return
    # New Game deliberately clears the previous campaign's step8_items. This
    # button must regenerate, rather than silently pass {} to adopt_initial().
    _on_step8_generate()
    if generation_job != null:
        initial_claim_after_generation = true
        region_run_ui.run.notice = "初期6装備を自動生成中です。シナジー保証を確認してから無料で受け取ります。"
    else:
        region_run_ui.run.notice = "装備生成を開始できませんでした。初期6装備の生成画面で選択とSeedをご確認ください。"

func _finish_hub_initial_claim() -> bool:
    if region_run_ui == null:
        return false
    if step8_items.size() != 6:
        region_run_ui.run.notice = "受取可能な6装備がありません。もう一度生成してください。"
        return false
    # Manual STEP8 and auto-generation both must honor the Common-only rule.
    for slot in ["main_weapon", "offhand", "head", "body", "hands", "feet"]:
        var item: Dictionary = step8_items.get(slot, {})
        if item.is_empty() or str(item.get("rarity", "")) != "Common":
            region_run_ui.run.notice = "初回無料装備は6部位すべてCommonである必要があります。再生成してください。"
            return false
    if region_run_ui.run.adopt_initial(step8_items):
        region_run_ui.run.notice = "初期Common装備6部位を無料受取しました。装備・倉庫と24枚デッキをご確認ください。"
        return true
    # adopt_initial is intentionally atomic and can reject invalid items.
    if region_run_ui.run.notice.is_empty():
        region_run_ui.run.notice = "6装備を受け取れませんでした。装備の検証またはセーブ保存に失敗しています。"
    return false

func _on_step8_generate() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    if step8_roller == null or step8_roller.templates.is_empty():
        step8_status.text = "抽選データ未読込"
        return
    var base_seed := int(step8_seed_input.value)
    var template_ids: Dictionary = {}
    var slots: Array[String] = ["main_weapon", "offhand", "head", "body", "hands", "feet"]
    for index in range(slots.size()):
        var slot_id := slots[index]
        var selector: OptionButton = step8_template_selectors.get(slot_id)
        var ids: Array = step8_template_ids.get(slot_id, [])
        if selector == null or selector.selected < 0 or selector.selected >= ids.size():
            step8_status.text = "選択エラー: %s" % slot_id
            return
        template_ids[slot_id] = str(ids[selector.selected])
        if str(step8_roller.templates[template_ids[slot_id]].Rarity) != "Common":
            step8_status.text = "初期装備はCommon限定です。"
            return
    generation_job = InitialDeckGenerationJobScript.new()
    if generation_job.start(template_ids,base_seed) != OK:
        generation_job = null
        step8_status.text = "生成を開始できませんでした。現在の装備は保持されます。"
        return
    _set_generation_busy(true)
    step8_status.text = "装備生成中: 候補確認"

func _step8_commit_generated(generated: Dictionary) -> void:
    var slots: Array[String] = ["main_weapon", "offhand", "head", "body", "hands", "feet"]
    if not bool(generated.get("ok", false)):
        step8_status.text = "条件を満たす装備を生成できませんでした。Seedまたは装備を変更してください。現在の装備は保持されます。"
        return
    var new_items: Dictionary = generated["items"]
    # Validate a detached loadout, then save atomically before mutating live state.
    var checked = LoadoutBuilder.new()
    if not checked.load_data():
        step8_status.text = "装備データ読込失敗。現在の装備は保持されます。"
        return
    for slot_id in slots:
        var pending_item: Dictionary = new_items[slot_id]
        checked.equipment_db.items[str(pending_item["instance_id"])] = pending_item.duplicate(true)
        if not checked.set_equipment(slot_id, str(pending_item["instance_id"])):
            step8_status.text = "装備検証失敗。現在の装備は保持されます。"
            return
    if not checked.is_valid() or not _step8_write_items(new_items):
        step8_status.text = "装備の検証または保存に失敗しました。現在の装備は保持されます。"
        return
    for slot_id in slots:
        var item: Dictionary = new_items[slot_id]
        var item_id := str(item.get("instance_id", ""))
        loadout_builder.equipment_db.items[item_id] = item.duplicate(true)
        loadout_builder.set_equipment(slot_id, item_id)
        var selector: OptionButton = loadout_selectors.get(slot_id)
        if selector != null:
            var present_ids: Array = loadout_selector_item_ids.get(slot_id, [])
            if not present_ids.has(item_id):
                selector.add_item("[STEP8 %s] %s" % [str(item.get("rarity", "")), str(item.get("name", item_id))])
                present_ids.append(item_id)
                loadout_selector_item_ids[slot_id] = present_ids
    step8_items = new_items.duplicate(true)
    _refresh_loadout_ui()
    _step8_refresh()

func _step8_refresh() -> void:
    if step8_status == null or step8_preview == null:
        return
    if step8_items.is_empty():
        step8_status.text = "まだSTEP8装備を抽選していません。部位とSeedを選んでください。"
        step8_preview.text = "各装備は固定2枚＋ランダム2枚。初期デッキ全体で完成SC2組以上、Mana3からの特性利用手順、無条件Draw2枚以上を確認します。"
        return
    var audit: Dictionary = step8_roller.inspect_deck(step8_items)
    step8_status.text = "24枚: %d | 完成SC: %d | 孤立Action: %d | Attack: %d (目安8〜10) | 循環: %d | Salvage: %d | Cost2+: %d" % [int(audit.get("card_count", 0)), int(audit.get("completed_sc", 0)), int(audit.get("orphan", 0)), int(audit.get("attack", 0)), int(audit.get("cycle", 0)), int(audit.get("salvage", 0)), int(audit.get("cost2_plus", 0))]
    var lines: Array[String] = []
    for slot_id in ["main_weapon", "offhand", "head", "body", "hands", "feet"]:
        var item: Dictionary = step8_items.get(slot_id, {})
        lines.append("%s | [%s] %s | %s / %s | HP %d" % [slot_id, str(item.get("rarity", "")), str(item.get("name", "")), str(item.get("affinity_weapon", "")), str(item.get("rolled_attribute", "")), int(item.get("base_hp", 0))])
        lines.append("   Fixed  : %s" % str(item.get("fixed_cards", [])))
        lines.append("   Random : %s" % str(item.get("random_cards", [])))
    lines.append("\nMain Weaponの固定SCを保証。新規の初期抽選はデッキ全体のシナジー条件を確認します。旧保存装備はそのまま復元します。")
    lines.append("\n抽選した装備は保存され、再選択だけでは抽選し直されません。変更するにはSeedを変えて「この6装備を入手・抽選」を押してください。")
    step8_preview.text = "\n".join(lines)

func _on_step8_apply() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    if step8_items.size() != 6:
        step8_status.text = "先に6部位の装備を抽選してください。"
        return
    # Use the exact immutable minted package even if a historical prototype
    # selector was used after the STEP8 roll screen was opened.
    for slot_id in ["main_weapon", "offhand", "head", "body", "hands", "feet"]:
        var chosen: Dictionary = step8_items.get(slot_id, {})
        if chosen.is_empty() or not loadout_builder.set_equipment(slot_id, str(chosen.get("instance_id", ""))):
            step8_status.text = "保存済み装備の復元に失敗しました: %s" % slot_id
            return
    if not loadout_builder.is_valid():
        step8_status.text = "装備デッキに不正なカードがあります。"
        return
    if not deck_builder.set_deck_ids(loadout_builder.build_deck_ids()):
        step8_status.text = "デッキ設定に失敗しました。"
        return
    pending_loadout_snapshot = loadout_builder.get_snapshot()
    _refresh_setup_ui()
    tab_container.current_tab = 1

func _on_step8_start_battle() -> void:
    if region_run_ui!=null and region_run_ui.locked(): return
    if generation_job != null:
        return
    _on_step8_apply()
    if tab_container.current_tab == 1:
        _on_setup_start_battle()

func _step8_write_items(items: Dictionary) -> bool:
    var temporary_path: String = step8_save_path + ".tmp"
    var file = FileAccess.open(temporary_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(items))
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    if write_error != OK:
        return false
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(step8_save_path)) == OK

func _step8_restore_items() -> void:
    if not FileAccess.file_exists(step8_save_path):
        return
    var file = FileAccess.open(step8_save_path, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY or parsed.size() != 6:
        return
    var checked: Dictionary = {}
    for slot_id in loadout_builder.equipment_db.get_slot_ids():
        var item: Dictionary = parsed.get(slot_id, {})
        if str(item.get("rarity", "")) == "Common":
            item["socket_count"] = 0
            item["socket_cap"] = 0
        if item.is_empty() or str(item.get("slot", "")) != slot_id or str(item.get("rarity", "")) != "Common" or not step8_roller.validate_item(item):
            return
        checked[slot_id] = item.duplicate(true)
    for slot_id in checked.keys():
        var item: Dictionary = checked[slot_id]
        var item_id := str(item.get("instance_id", ""))
        loadout_builder.equipment_db.items[item_id] = item.duplicate(true)
        loadout_builder.set_equipment(str(slot_id), item_id)
    step8_items = checked.duplicate(true)
