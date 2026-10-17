extends Button

signal card_clicked(index: int)
signal card_drag_started(index: int, press_global_position: Vector2)
signal card_drag_moved(index: int, global_position: Vector2)
signal card_drag_released(index: int, global_position: Vector2)
signal card_hovered(index: int)
signal card_hover_exited(index: int)

var hand_index: int = -1
var _press_global_position: Vector2 = Vector2.ZERO
var _drag_started: bool = false
const DRAG_THRESHOLD: float = 14.0
var visual: MarginContainer
var mana_label: Label
var damage_label: Label
var block_label: Label
var draw_label: Label
var attr_gain_label: Label
var action_label: Label
var condition_label: Label
var hover_tween: Tween
var entry_tween: Tween
var _arc_angle: float = 0.0
var _arc_offset: float = 0.0
var type_icon_view: TextureRect
var action_icon_view: TextureRect
var attribute_icon_view: TextureRect
var weapon_icon_view: TextureRect
var condition_icon_view: TextureRect
var weapon_state_icon_view: TextureRect
var draw_metric_box: Control
var attr_gain_metric_box: Control
var title_label: Label
var condition_container: VBoxContainer
var condition_outcome_row: HBoxContainer
var _condition_marked: bool = false

func apply_hand_arc(index: int, count: int, selected: bool) -> void:
    # Flat, non-overlapping horizontal hand: no fan, tilt, or curved offsets.
    _arc_angle = 0.0
    _arc_offset = -4.0 if selected else 0.0
    if visual != null:
        visual.rotation_degrees = 0.0
        visual.position.y = _arc_offset

func _label(value: String, font_size: int, color: Color = Color.WHITE) -> Label:
    var label = Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _icon_rect(texture: Texture2D, size: Vector2 = Vector2(22, 22), tint: Color = Color.WHITE) -> TextureRect:
    var icon_view := TextureRect.new()
    icon_view.texture = texture
    icon_view.custom_minimum_size = size
    icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon_view.modulate = tint
    return icon_view

func _metric(parent: Container, texture: Texture2D, value: String, color: Color, min_width: float = 0.0) -> Array:
    var chip := PanelContainer.new()
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if min_width > 0.0:
        chip.custom_minimum_size.x = min_width
    var chip_style := StyleBoxFlat.new()
    chip_style.bg_color = Color(1, 1, 1, 0.04)
    chip_style.border_color = Color(1, 1, 1, 0.14)
    chip_style.set_border_width_all(1)
    chip_style.set_corner_radius_all(8)
    chip_style.set_content_margin_all(4)
    chip.add_theme_stylebox_override("panel", chip_style)
    parent.add_child(chip)

    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 4)
    chip.add_child(row)

    var icon_view := _icon_rect(texture, Vector2(18, 18), color)
    row.add_child(icon_view)
    var number := _label(value, 19, color)
    row.add_child(number)
    return [chip, number, icon_view]

func _small_metric(parent: Container, texture: Texture2D, value: String, color: Color) -> Array:
    var group := HBoxContainer.new()
    group.mouse_filter = Control.MOUSE_FILTER_IGNORE
    group.add_theme_constant_override("separation", 2)
    parent.add_child(group)
    group.add_child(_icon_rect(texture, Vector2(15, 15), color))
    var number := _label(value, 16, color)
    group.add_child(number)
    return [group, number]

func _card_title(card: Dictionary) -> String:
    var display_name: String = str(card.get("display_name", "")).strip_edges()
    if display_name != "":
        var parts := display_name.split(" / ")
        if parts.size() > 0 and str(parts[0]).strip_edges() != "":
            return str(parts[0]).strip_edges()
        return display_name
    return str(card.get("id", "?"))

func _attribute_icon_name(attribute: String) -> String:
    return {
        "物理":"attr_might","炎":"attr_blast","水":"attr_slow","雷":"attr_charge","地":"attr_guard",
        "光":"attr_grace","闇":"attr_curse","毒":"attr_poison","秘術":"attr_orb","風":"attr_wind"
    }.get(attribute, "attack")

func _weapon_icon_name(weapon: String) -> String:
    return {
        "片手剣":"weapon_sword","レイピア":"weapon_precision","短剣":"weapon_combo",
        "大剣":"weapon_charge","魔法剣":"weapon_magic","刀":"weapon_sheathe"
    }.get(weapon, "equipment")

func _type_icon_name(card_type: String) -> String:
    return {"attack":"attack","skill":"block","power":"engine"}.get(card_type, "equipment")

func _action_icon_name(action: String) -> String:
    return {"SET":"engine","CONSUME":"exhaust","NEUTRAL":"equipment"}.get(action, "equipment")

func _action_text(action: String) -> String:
    return {"SET":"ON","CONSUME":"USE","NEUTRAL":""}.get(action, "")

func _add_condition_outcome(parent: HBoxContainer, icon_name: String, value: String, color: Color) -> void:
    var group := HBoxContainer.new()
    group.mouse_filter = Control.MOUSE_FILTER_IGNORE
    group.add_theme_constant_override("separation", 2)
    parent.add_child(group)
    group.add_child(_icon_rect(load("res://assets/icons/ui/%s.svg" % icon_name), Vector2(16, 16), color))
    group.add_child(_label(value, 15, color))

func _build_condition_display(parent: VBoxContainer, card: Dictionary) -> void:
    # Only metadata-defined outcomes may be drawn. A threshold never means a bonus.
    var threshold: int = int(card.get("condition_threshold", 0))
    if threshold <= 0:
        condition_container = null
        condition_outcome_row = null
        return

    condition_container = VBoxContainer.new()
    condition_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    condition_container.add_theme_constant_override("separation", 1)
    parent.add_child(condition_container)

    var requirement := HBoxContainer.new()
    requirement.mouse_filter = Control.MOUSE_FILTER_IGNORE
    requirement.alignment = BoxContainer.ALIGNMENT_CENTER
    requirement.add_theme_constant_override("separation", 4)
    condition_container.add_child(requirement)
    var trait_icon: String = _attribute_icon_name(str(card.get("attribute", "")))
    requirement.add_child(_icon_rect(load("res://assets/icons/ui/%s.svg" % trait_icon), Vector2(17, 17), HubCardView.tone(str(card.get("attribute", "")))))
    requirement.add_child(_label("≥%d" % threshold, 15, Color("c6cedd")))
    requirement.add_child(_label("→", 17, Color("c6cedd")))

    condition_outcome_row = HBoxContainer.new()
    condition_outcome_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    condition_outcome_row.alignment = BoxContainer.ALIGNMENT_CENTER
    condition_outcome_row.add_theme_constant_override("separation", 7)
    condition_container.add_child(condition_outcome_row)

    var conditional_damage: int = int(card.get("condition_damage_bonus", 0))
    var conditional_block: int = int(card.get("condition_block_bonus", 0))
    var conditional_draw: int = int(card.get("condition_draw_bonus", 0))
    var conditional_heal: int = maxi(int(card.get("condition_heal_bonus", 0)), int(card.get("condition_heal_after_attack", 0)))
    var conditional_gain: int = int(card.get("extra_attribute_gain_on_condition", 0))
    var alternate_draw: int = int(card.get("conditional_draw_count", 0))
    var conditional_count: int = 0
    if conditional_damage > 0:
        _add_condition_outcome(condition_outcome_row, "attack", str(int(card.get("base_damage", 0)) + conditional_damage), Color("ffb19c"))
        conditional_count += 1
    if conditional_block > 0:
        _add_condition_outcome(condition_outcome_row, "block", str(int(card.get("base_block", 0)) + conditional_block), Color("90d7ff"))
        conditional_count += 1
    if conditional_draw > 0 or alternate_draw > 0:
        _add_condition_outcome(condition_outcome_row, "draw", str(alternate_draw if alternate_draw > 0 else int(card.get("draw_count", 0)) + conditional_draw), Color("a2e6d3"))
        conditional_count += 1
    if conditional_heal > 0:
        _add_condition_outcome(condition_outcome_row, "hp", "+%d" % conditional_heal, Color("9ddd99"))
        conditional_count += 1
    if conditional_gain > 0:
        _add_condition_outcome(condition_outcome_row, trait_icon, "+%d" % (int(card.get("attribute_trait_gain", 0)) + conditional_gain), HubCardView.tone(str(card.get("attribute", ""))))
        conditional_count += 1
    if alternate_draw > 0:
        # Conditional Draw 3 -> Bottom 2; not Discard 2.
        _add_condition_outcome(condition_outcome_row, "bottom", str(int(card.get("conditional_select_count", 0))), Color("c6cedd"))
        conditional_count += 1
    if conditional_count == 0:
        # The remaining metadata-light branch (C004) is a salvage-one effect.
        # Its draw-one fallback remains explained in the formal detail panel.
        _add_condition_outcome(condition_outcome_row, "salvage", "1", Color("a2e6d3"))

    condition_container.tooltip_text = str(card.get("text", ""))
    condition_container.modulate = Color("9da5b7")

var formal_card: Dictionary = {}
var body_text: RichTextLabel
var role_label: Label
var trait_condition_label: RichTextLabel
var _weapon_trait_on: int = -1
var base_tint: Color = Color.WHITE
var detail_popup: PopupPanel

func configure(card: Dictionary, cost: int, icons: Dictionary, selected: bool, choosing: bool, affordable: bool) -> void:
    formal_card = card.duplicate(true)
    text = ""
    clip_contents = true
    tooltip_text = WeaponTraitCardDescription.combined_text(card)

    var accent := Color("bd7b69") if str(card.get("card_type", "")) == "attack" else Color("78bcff")
    if str(card.get("card_type", "")) == "power":
        accent = Color("ffd17c")

    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        var style := StyleBoxFlat.new()
        style.bg_color = Color("242035") if state != "hover" else Color("373048")
        style.border_color = Color("ffe59b") if selected or choosing else accent
        if state == "disabled":
            style.bg_color = Color("191922")
            style.border_color = Color("4b5665")
        style.set_border_width_all(3 if selected or choosing else 2)
        style.set_corner_radius_all(14)
        style.shadow_color = Color(0, 0, 0, 0.3)
        style.shadow_size = 4
        add_theme_stylebox_override(state, style)

    visual = MarginContainer.new()
    visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
    visual.clip_contents = true
    for side in ["left", "right"]:
        visual.add_theme_constant_override("margin_" + side, 8)
    for side in ["top", "bottom"]:
        visual.add_theme_constant_override("margin_" + side, 8)
    add_child(visual)

    var body := VBoxContainer.new()
    body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body.add_theme_constant_override("separation", 5)
    visual.add_child(body)

    var header := HBoxContainer.new()
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_theme_constant_override("separation", 5)
    body.add_child(header)

    var mana_box := HBoxContainer.new()
    mana_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mana_box.add_theme_constant_override("separation", 3)
    header.add_child(mana_box)
    mana_box.add_child(_icon_rect(load("res://assets/icons/ui/mana.svg"), Vector2(18, 18), Color("85d2ff") if affordable else Color("ff8d88")))
    mana_label = _label(str(cost), 24, Color("85d2ff") if affordable else Color("ff8d88"))
    mana_box.add_child(mana_label)

    title_label = _label(_card_title(card), 16, Color.WHITE)
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(title_label)

    type_icon_view = _icon_rect(load("res://assets/icons/ui/%s.svg" % _type_icon_name(str(card.get("card_type", "")))), Vector2(24, 24), accent)
    header.add_child(type_icon_view)

    # Attribute/weapon/trait type identity remains available in the tooltip.
    # Do not draw a redundant middle row of identity icons on the card face.
    attribute_icon_view = null
    weapon_icon_view = null
    action_icon_view = null
    weapon_state_icon_view = null
    condition_icon_view = null

    var metrics := HBoxContainer.new()
    metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
    metrics.alignment = BoxContainer.ALIGNMENT_CENTER
    metrics.add_theme_constant_override("separation", 6)
    body.add_child(metrics)

    var damage_result := _metric(metrics, icons.attack, str(int(card.get("base_damage", 0))), Color("ffb19c"), 58.0)
    damage_label = damage_result[1]
    var block_result := _metric(metrics, icons.block, str(int(card.get("base_block", 0))), Color("90d7ff"), 58.0)
    block_label = block_result[1]

    # Compact secondary effects always stay beneath the Damage / Block row.
    # Three effects (Draw, +trait, ON) fit inside a 164px card.
    var effect_row := HBoxContainer.new()
    effect_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    effect_row.alignment = BoxContainer.ALIGNMENT_CENTER
    effect_row.add_theme_constant_override("separation", 5)
    body.add_child(effect_row)

    var base_draw: int = int(card.get("draw_count", 0))
    var draw_result := _small_metric(effect_row, load("res://assets/icons/ui/draw.svg"), str(base_draw), Color("a2e6d3"))
    draw_metric_box = draw_result[0]
    draw_label = draw_result[1]
    draw_metric_box.visible = base_draw > 0

    var gain_value: int = int(card.get("attribute_trait_gain", 0))
    var attr_gain_result := _small_metric(effect_row, load("res://assets/icons/ui/%s.svg" % _attribute_icon_name(str(card.get("attribute", "")))), ("+%d" % gain_value) if gain_value > 0 else "", HubCardView.tone(str(card.get("attribute", ""))))
    attr_gain_metric_box = attr_gain_result[0]
    attr_gain_label = attr_gain_result[1]
    attr_gain_metric_box.visible = gain_value > 0

    var action_text: String = _action_text(str(card.get("weapon_trait_action", "NEUTRAL")))
    var action_result := _small_metric(effect_row, load("res://assets/icons/ui/%s.svg" % _action_icon_name(str(card.get("weapon_trait_action", "NEUTRAL")))), action_text, accent)
    action_label = action_result[1]
    action_result[0].visible = action_text != ""

    _build_condition_display(body, card)

    role_label = Label.new()
    role_label.visible = false
    body_text = RichTextLabel.new()
    body_text.visible = false

    if str(card.get("rarity", "")) in ["Common", "Rare", "Epic", "Legendary"]:
        var rarity_color: Color = {"Common": Color("99a2b3"), "Rare": Color("68b8ec"), "Epic": Color("bb8cea"), "Legendary": Color("eab85c")}[str(card.get("rarity", ""))]
        for state in ["normal", "hover", "pressed", "focus"]:
            if not selected and not choosing:
                var border_style: StyleBoxFlat = get_theme_stylebox(state).duplicate() as StyleBoxFlat
                border_style.border_color = rarity_color
                add_theme_stylebox_override(state, border_style)

    if selected:
        visual.position.y = -4
    base_tint = Color.WHITE if affordable else Color(0.6, 0.6, 0.7)
    visual.modulate = base_tint
    _refresh_icon_states(false, false)

static func attribute_icon_name(attribute: String) -> String:
    return {"物理":"attr_might","炎":"attr_blast","水":"attr_slow","雷":"attr_charge","地":"attr_guard","光":"attr_grace","闇":"attr_curse","毒":"attr_poison","秘術":"attr_orb","風":"attr_wind"}.get(attribute,"attack")

var active_conditions: PackedStringArray = []
func _update_weapon_condition_label() -> void:
    _refresh_icon_states(false, false)

func _refresh_icon_states(condition_active: bool, condition_waiting: bool) -> void:
    _condition_marked = condition_active
    if condition_container != null:
        condition_container.modulate = Color("ffe59b") if condition_active else (Color("b5c1d0") if condition_waiting else Color("8490a3"))
    if action_label != null and str(formal_card.get("weapon_trait_action", "")) == "SET":
        action_label.modulate = Color("ffe59b") if _weapon_trait_on == 1 else Color.WHITE

func mark_weapon_condition(active: bool) -> void:
    if WeaponTraitCardDescription.is_applicable(formal_card):
        _weapon_trait_on = 1 if active else 0
        _update_weapon_condition_label()

func mark_attribute_condition(active: bool) -> void:
    _refresh_icon_states(active, false)

func _emphasize_conditions() -> void:
    _refresh_icon_states(not active_conditions.is_empty(), false)

func _make_custom_tooltip(for_text: String) -> Object:
    var panel = PanelContainer.new()
    var box = VBoxContainer.new(); box.custom_minimum_size.x = 450; panel.add_child(box)
    var title = _label(str(formal_card.get("id", "")) + " — 正式効果全文", 20, Color("ffd17c")); box.add_child(title)
    var detail = RichTextLabel.new(); detail.bbcode_enabled = true; detail.fit_content = true; detail.scroll_active = false; detail.custom_minimum_size.x = 450; detail.text = HubCardView.emphasized(for_text) + "\n\n" + WeaponTraitCardDescription.conditional_bbcode(formal_card, _weapon_trait_on); box.add_child(detail)
    return panel

func show_detail() -> void:
    if is_instance_valid(detail_popup) and detail_popup.visible:
        detail_popup.hide()
        return
    for popup in get_tree().get_nodes_in_group("sce_card_detail_popups"):
        if is_instance_valid(popup):
            popup.hide()
    if is_instance_valid(detail_popup):
        detail_popup.queue_free()
    detail_popup = PopupPanel.new()
    detail_popup.add_to_group("sce_card_detail_popups")
    add_child(detail_popup)
    var column = VBoxContainer.new()
    detail_popup.add_child(column)
    var close = Button.new()
    close.text = "✕　詳細を閉じる（右クリックでも閉じます）"
    close.pressed.connect(detail_popup.hide)
    column.add_child(close)
    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(470, 270)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    var view = _make_custom_tooltip(str(formal_card.get("id", "")) + " / Cost " + mana_label.text + "\n" + str(formal_card.get("text", "")))
    scroll.add_child(view)
    detail_popup.window_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
            detail_popup.hide())
    detail_popup.popup_centered(Vector2i(510, 360))

func _animate_hover(raised: bool) -> void:
    if visual == null: return
    if hover_tween != null: hover_tween.kill()
    visual.pivot_offset = size * 0.5
    hover_tween = create_tween().set_parallel(true)
    hover_tween.tween_property(visual, "scale", Vector2(1.085, 1.085) if raised else Vector2.ONE, 0.12)
    hover_tween.tween_property(visual, "rotation_degrees", 0.0 if raised else _arc_angle, 0.12)
    hover_tween.tween_property(visual, "position:y", _arc_offset - 10.0 if raised else _arc_offset, 0.12)
    hover_tween.tween_property(visual, "modulate", Color(1.15, 1.15, 1.15) if raised else base_tint, 0.12)

func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    if visual != null:
        visual.modulate.a = 0.0
        entry_tween = create_tween()
        entry_tween.tween_interval(float(maxi(0, hand_index)) * 0.025)
        entry_tween.tween_property(visual, "modulate:a", 1.0, 0.15)

func _on_mouse_entered() -> void:
    if not disabled: _animate_hover(true)
    card_hovered.emit(hand_index)

func _on_mouse_exited() -> void:
    _animate_hover(false)
    card_hover_exited.emit(hand_index)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        show_detail(); accept_event(); return
    if disabled: return
    if event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton = event
        if mouse_button.button_index != MOUSE_BUTTON_LEFT:
            return
        if mouse_button.pressed:
            _press_global_position = mouse_button.global_position
            _drag_started = false
            accept_event()
            return

        if _drag_started:
            card_drag_released.emit(hand_index, mouse_button.global_position)
        else:
            card_clicked.emit(hand_index)
        _drag_started = false
        accept_event()
        return

    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        var mouse_motion: InputEventMouseMotion = event
        if not _drag_started and _press_global_position.distance_to(mouse_motion.global_position) >= DRAG_THRESHOLD:
            _drag_started = true
            card_drag_started.emit(hand_index, _press_global_position)
        if _drag_started:
            card_drag_moved.emit(hand_index, mouse_motion.global_position)
            accept_event()

func apply_target_preview(value: Dictionary) -> void:
    active_conditions.clear()
    var condition_waiting: bool = bool(value.get("condition_waiting", false))
    var condition_active: bool = bool(value.get("condition", false))
    if _weapon_trait_on == 1:
        active_conditions.append(str(formal_card.get("weapon_trait", "")))
    if condition_active:
        active_conditions.append(str(formal_card.get("condition_trait", "")))

    # Show actual card damage/Block, not the target HP delta from the preview.
    # HP delta may be reduced by enemy Block; it is not the card's Attack power.
    var base_damage: int = int(formal_card.get("base_damage", 0))
    var base_block: int = int(formal_card.get("base_block", 0))
    var base_draw: int = int(formal_card.get("draw_count", 0))
    damage_label.text = str(base_damage + int(formal_card.get("condition_damage_bonus", 0)) if condition_active else base_damage)
    block_label.text = str(base_block + int(formal_card.get("condition_block_bonus", 0)) if condition_active else base_block)
    if draw_label != null:
        draw_label.text = str(base_draw)
        draw_metric_box.visible = base_draw > 0
    if attr_gain_label != null:
        var gain_value: int = int(formal_card.get("attribute_trait_gain", 0))
        attr_gain_label.text = ("+%d" % gain_value) if gain_value > 0 else ""
    if action_label != null:
        action_label.text = _action_text(str(formal_card.get("weapon_trait_action", "NEUTRAL")))
    _refresh_icon_states(condition_active, condition_waiting)

    var target_text: String = BattleCardPreview.describe(value)
    tooltip_text = str(formal_card.get("text", "")) + "\n\n" + target_text + "\n基本Damage %d / 基本Block %d / 基本Draw %d" % [int(formal_card.get("base_damage", 0)), int(formal_card.get("base_block", 0)), int(formal_card.get("draw_count", 0))]
