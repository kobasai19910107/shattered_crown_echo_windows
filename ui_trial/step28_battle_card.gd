extends Button
## STEP28 reusable battle-card presentation. This node only reads card data.

const TYPE_LABELS := {
    "attack": "ATTACK / 攻撃",
    "skill": "SKILL / 技能",
    "power": "POWER / 強化",
}
const ATTRIBUTE_COLORS := {
    "物理": Color("d6b98a"), "炎": Color("e26d55"), "水": Color("58a7d8"),
    "雷": Color("e6cc58"), "地": Color("9f8664"), "光": Color("e9d99a"),
    "闇": Color("9a78bb"), "毒": Color("75b86e"), "秘術": Color("6cc8c2"),
    "風": Color("77c6a3"),
}

var base_position := Vector2.ZERO
var cost_label: Label
var title_label: Label
var meta_label: Label
var effect_label: Label
var _built := false

func _ready() -> void:
    _build()

func _build() -> void:
    if _built:
        return
    _built = true
    name = "BattleCard"
    text = ""
    clip_contents = true
    focus_mode = Control.FOCUS_NONE
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    cost_label = _label(Vector2(8, 8), Vector2(34, 34), 19, HORIZONTAL_ALIGNMENT_CENTER)
    cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title_label = _label(Vector2(47, 7), Vector2(99, 38), 14, HORIZONTAL_ALIGNMENT_LEFT)
    title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    meta_label = _label(Vector2(10, 47), Vector2(134, 24), 11, HORIZONTAL_ALIGNMENT_LEFT)
    effect_label = _label(Vector2(10, 72), Vector2(134, 66), 12, HORIZONTAL_ALIGNMENT_LEFT)
    effect_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _label(pos: Vector2, extent: Vector2, font_size: int, alignment: HorizontalAlignment) -> Label:
    var label := Label.new()
    label.position = pos
    label.size = extent
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("f4ede5"))
    label.horizontal_alignment = alignment
    add_child(label)
    return label

func set_base_position(value: Vector2) -> void:
    base_position = value
    position = value

func configure_card(card: Dictionary, cost_text: String, selected: bool, unavailable: bool) -> void:
    _build()
    var attribute := str(card.get("attribute", ""))
    var accent: Color = ATTRIBUTE_COLORS.get(attribute, Color("d7b57e"))
    var display_name := str(card.get("display_name", "")).strip_edges()
    if display_name.is_empty():
        display_name = str(card.get("name", card.get("id", "?")))
    var card_id := str(card.get("id", ""))
    var card_type := str(card.get("card_type", "")).to_lower()
    var role := str(card.get("role", ""))
    var effect := str(card.get("text", ""))
    var face_name := display_name
    if not card_id.is_empty() and not role.is_empty():
        face_name = "%s  %s" % [card_id, role]

    cost_label.text = cost_text.trim_prefix("Cost ")
    title_label.text = face_name
    meta_label.text = "%s  •  %s / %s" % [TYPE_LABELS.get(card_type, card_type.to_upper()), attribute, str(card.get("weapon", ""))]
    effect_label.text = effect
    tooltip_text = "%s\nCost %s / %s / %s\n%s" % [display_name, cost_text, attribute, role, effect]
    disabled = unavailable
    position = base_position + (Vector2(0, -10) if selected else Vector2.ZERO)
    z_index = 4 if selected else 0

    var frame := StyleBoxFlat.new()
    frame.bg_color = Color("101827") if not selected else Color("192941")
    frame.border_color = accent.lightened(0.26 if selected else 0.0)
    frame.set_border_width_all(3 if selected else 2)
    frame.set_corner_radius_all(8)
    frame.shadow_color = Color(accent, 0.58 if selected else 0.22)
    frame.shadow_size = 8 if selected else 3
    add_theme_stylebox_override("normal", frame)
    var hover := frame.duplicate() as StyleBoxFlat
    hover.bg_color = Color("243249")
    hover.border_color = accent.lightened(0.35)
    hover.shadow_size = 8
    add_theme_stylebox_override("hover", hover)
    var pressed := hover.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("0d1422")
    add_theme_stylebox_override("pressed", pressed)
    var disabled_style := frame.duplicate() as StyleBoxFlat
    disabled_style.bg_color = Color("11151e")
    disabled_style.border_color = Color("596171")
    add_theme_stylebox_override("disabled", disabled_style)

    var badge := StyleBoxFlat.new()
    badge.bg_color = Color(accent, 0.22)
    badge.border_color = accent
    badge.set_border_width_all(2)
    badge.set_corner_radius_all(17)
    cost_label.add_theme_stylebox_override("normal", badge)
    cost_label.add_theme_color_override("font_color", accent.lightened(0.3))
    meta_label.add_theme_color_override("font_color", accent.lightened(0.22))
    modulate = Color(0.62, 0.65, 0.72, 1.0) if unavailable else Color.WHITE
