extends PanelContainer

signal pile_requested(player_slot: int, pile_type: String)
signal ally_target_requested(player_slot: int)

var player_slot: int = 0
var _data: Dictionary = {}
var _preview: Dictionary = {}
var _active: bool = false
var _compact: bool = false
var _icon_cache: Dictionary = {}

var _header_label: Label
var _hp_button: Button
var _mana_button: Button
var _block_button: Button
var _traits_grid: GridContainer
var _statuses_grid: GridContainer
var _draw_button: Button
var _discard_button: Button
var _exhaust_button: Button
var _preview_label: Label

func _ready() -> void:
    _build_ui()
    _refresh()

func _build_ui() -> void:
    custom_minimum_size = Vector2(304, 176)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mouse_filter = Control.MOUSE_FILTER_PASS

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_bottom", 8)
    add_child(margin)

    var root: VBoxContainer = VBoxContainer.new()
    root.add_theme_constant_override("separation", 5)
    margin.add_child(root)

    _header_label = Label.new()
    _header_label.add_theme_font_size_override("font_size", 16)
    root.add_child(_header_label)

    var resources: HBoxContainer = HBoxContainer.new()
    resources.add_theme_constant_override("separation", 3)
    root.add_child(resources)

    _hp_button = _make_icon_button("hp", "0/0", "HP")
    _hp_button.custom_minimum_size = Vector2(84, 32)
    resources.add_child(_hp_button)
    _mana_button = _make_icon_button("mana", "0", "Mana")
    _mana_button.custom_minimum_size = Vector2(62, 32)
    resources.add_child(_mana_button)
    _block_button = _make_icon_button("block", "0", "Block")
    _block_button.custom_minimum_size = Vector2(62, 32)
    resources.add_child(_block_button)

    _traits_grid = GridContainer.new()
    _traits_grid.columns = 4
    _traits_grid.add_theme_constant_override("h_separation", 2)
    _traits_grid.add_theme_constant_override("v_separation", 2)
    root.add_child(_traits_grid)

    _statuses_grid = GridContainer.new()
    _statuses_grid.columns = 4
    _statuses_grid.add_theme_constant_override("h_separation", 2)
    _statuses_grid.add_theme_constant_override("v_separation", 2)
    root.add_child(_statuses_grid)

    var piles: HBoxContainer = HBoxContainer.new()
    piles.add_theme_constant_override("separation", 4)
    root.add_child(piles)
    _draw_button = _make_icon_button("draw", "0", "山札")
    _draw_button.pressed.connect(_emit_pile_requested.bind("draw"))
    piles.add_child(_draw_button)
    _discard_button = _make_icon_button("discard", "0", "捨て札")
    _discard_button.pressed.connect(_emit_pile_requested.bind("discard"))
    piles.add_child(_discard_button)
    _exhaust_button = _make_icon_button("exhaust", "0", "除外")
    _exhaust_button.pressed.connect(_emit_pile_requested.bind("exhaust"))
    piles.add_child(_exhaust_button)

    _preview_label = Label.new()
    _preview_label.visible = false
    _preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _preview_label.add_theme_font_size_override("font_size", 11)
    root.add_child(_preview_label)


func _emit_pile_requested(pile_type: String) -> void:
    pile_requested.emit(player_slot, pile_type)

func set_player_data(data: Dictionary) -> void:
    _data = data.duplicate(true)
    player_slot = int(_data.get("slot", 0))
    _refresh()

func set_active(value: bool) -> void:
    _active = value
    _refresh()

func set_compact(value: bool) -> void:
    _compact = value
    custom_minimum_size = Vector2(304, 148 if _compact else 176)
    _refresh()

func set_preview(preview: Dictionary) -> void:
    _preview = preview.duplicate(true)
    _refresh()

func clear_preview() -> void:
    _preview.clear()
    _refresh()

func _refresh() -> void:
    if _header_label == null:
        return
    var display_name: String = str(_data.get("display_name", "P%d" % (player_slot + 1)))
    var weapon: String = str(_data.get("weapon", ""))
    var preview_only: bool = bool(_data.get("preview_only", false))
    var prefix: String = "▶ " if _active else "   "
    var suffix: String = "  [HUD Preview]" if preview_only else ""
    _header_label.text = "%s%s%s%s" % [prefix, display_name, ("  /  " + weapon) if weapon != "" and weapon != "—" else "", suffix]

    var hp: int = int(_data.get("hp", 0))
    var max_hp: int = int(_data.get("max_hp", 0))
    var mana: int = int(_data.get("mana", 0))
    var block: int = int(_data.get("block", 0))
    # v1.6.10: core HUD always shows current values. Predictions live in the dedicated center panel.
    _hp_button.text = "%d/%d" % [hp, max_hp]
    _mana_button.text = str(mana)
    _block_button.text = str(block)
    _hp_button.tooltip_text = "HP\n現在 %d / 最大 %d" % [hp, max_hp]
    _mana_button.tooltip_text = "Mana\n現在 %d / 基本 %d" % [mana, int(_data.get("base_mana", 0))]
    _block_button.tooltip_text = "Block\n現在 %d" % block

    _clear_container(_traits_grid)
    var weapon_traits: Dictionary = _data.get("weapon_traits", {})
    var attribute_traits: Dictionary = _data.get("attribute_traits", {})
    for trait_name in ["流転", "精密", "連刃", "重撃", "魔導", "納刀"]:
        var on: bool=bool(weapon_traits.get(trait_name,false))
        var badge=_make_weapon_trait_button(_weapon_trait_icon_name(trait_name),trait_name)
        badge.text="ON" if on else "OFF"
        badge.tooltip_text=trait_name+(" ON" if on else " OFF")+"\n"+_weapon_trait_detail(trait_name)
        badge.modulate=Color("ffe59b") if on else Color(0.55,0.55,0.65)
        _traits_grid.add_child(badge)
    for trait_name in ["剛力", "帯電", "堅牢", "恩寵", "魔珠", "疾風"]:
        var before: int = int(attribute_traits.get(trait_name, 0))
        if before > 0:
            _traits_grid.add_child(_make_trait_button(_attribute_trait_icon_name(trait_name), trait_name, before, before))

    _clear_container(_statuses_grid)
    var statuses: Array = _data.get("statuses", [])
    var visible_statuses: int = 0
    for raw_status in statuses:
        if visible_statuses >= (4 if _compact else 8):
            break
        if typeof(raw_status) != TYPE_DICTIONARY:
            continue
        var status: Dictionary = raw_status
        var amount: int = int(status.get("amount", 0))
        if amount <= 0:
            continue
        var status_button: Button = _make_icon_button(str(status.get("icon", "engine")), str(amount), str(status.get("tooltip", status.get("name", "状態"))))
        status_button.custom_minimum_size = Vector2(48, 28)
        _statuses_grid.add_child(status_button)
        visible_statuses += 1
    if statuses.size() > visible_statuses:
        var more: Label = Label.new()
        more.text = "+%d" % (statuses.size() - visible_statuses)
        _statuses_grid.add_child(more)

    _draw_button.text = str(int(_data.get("draw_count", 0)))
    _discard_button.text = str(int(_data.get("discard_count", 0)))
    _exhaust_button.text = str(int(_data.get("exhaust_count", 0)))
    _draw_button.tooltip_text = "山札 %d枚\nクリックで一覧" % int(_data.get("draw_count", 0))
    _discard_button.tooltip_text = "捨て札 %d枚\nクリックで一覧" % int(_data.get("discard_count", 0))
    _exhaust_button.tooltip_text = "除外 %d枚\nクリックで一覧" % int(_data.get("exhaust_count", 0))

    _preview_label.visible = false
    _preview_label.text = ""

func _format_transition(before_text: String, after_text: String, changed: bool) -> String:
    return "%s→%s" % [before_text, after_text] if changed else before_text

func _make_weapon_trait_button(icon_name: String, trait_name: String) -> Button:
    var button: Button = _make_icon_button(icon_name, "ON", "%s ON\n%s" % [trait_name, _weapon_trait_detail(trait_name)])
    button.custom_minimum_size = Vector2(66, 28)
    return button

func _weapon_trait_detail(trait_name: String) -> String:
    match trait_name:
        "流転": return "次の対応片手剣カードで、Attackならダメージ50%をBlock、DefenseならBlock50%を追加ダメージ。"
        "精密": return "次の対応レイピアAttackで、BlockありならBlock Ignore、なければ攻撃後に脆弱1。"
        "連刃": return "次の対応短剣Attackを同ダメージの2Hitにする。2Hit目はダメージのみ。"
        "重撃": return "次の対応大剣Attackのダメージ×1.5。"
        "魔導": return "次の対応魔法剣CONSUMEカードの属性特性獲得量+2。"
        "納刀": return "次の居合対応カードをCost0。居合使用後OFF。"
    return "武器特性ON"

func _make_trait_button(icon_name: String, trait_name: String, before: int, after: int) -> Button:
    var text_value: String = str(before)
    if after != before:
        text_value = "%d→%d" % [before, after]
    var tooltip: String = "%s %d" % [trait_name, before]
    if after != before:
        tooltip += "\n使用後予測: %d" % after
    if before < 3 and after >= 3:
        tooltip += "\n★ 3到達: 発動準備完了"
    var button: Button = _make_icon_button(icon_name, text_value, tooltip)
    button.custom_minimum_size = Vector2(58, 28)
    return button

func _make_icon_button(icon_name: String, text_value: String, tooltip: String) -> Button:
    var button: Button = Button.new()
    button.flat = true
    button.icon = _get_icon(icon_name)
    button.text = text_value
    button.tooltip_text = tooltip
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_default_cursor_shape = Control.CURSOR_HELP
    button.custom_minimum_size = Vector2(54, 30)
    return button

func _get_icon(icon_name: String):
    if _icon_cache.has(icon_name):
        return _icon_cache[icon_name]
    var resource = load("res://assets/icons/ui/%s.svg" % icon_name)
    _icon_cache[icon_name] = resource
    return resource

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

func _clear_container(container: Container) -> void:
    for child in container.get_children():
        child.queue_free()
