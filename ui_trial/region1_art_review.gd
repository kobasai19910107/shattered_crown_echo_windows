extends Control
## STEP10 Region1 concept-art review. Presentation-only, no Battle Core calls.
## STEP9 sprites remain the authoritative movable parts; concept images are NOT rigged.
const PROFILES_PATH = "res://ui_trial/region1_unique_profiles.json"
const ASSET_ROOT = "res://ui_trial/assets/region1_unique/"
const ART_ROOT = "res://ui_trial/assets/region1_concepts/"
const VIEW_SIZE = Vector2(1280, 720)
const GOLD = Color("e8c494")
const INK = Color("141d2c")

var stage: Control
var ids: Array[String] = []
var profiles: Dictionary = {}
var selected: int = 0
var model: Node2D
var parts: Dictionary = {}
var origins: Dictionary = {}
var elapsed: float = 0.0
var anim_busy: bool = false
var preview_art: TextureRect
var hero_title: Label
var current_name: Label
var current_role: Label
var current_id: Label
var counter: Label
var mismatch_notice: Label
var dropdown: OptionButton

func _ready() -> void:
    var data = JSON.parse_string(FileAccess.get_file_as_string(PROFILES_PATH))
    if not data is Dictionary:
        push_error("STEP10: Region1 profile JSON is missing or invalid")
        return
    profiles = data.get("enemies", {})
    for raw_id in profiles.keys(): ids.append(str(raw_id))
    ids.sort()
    stage = Control.new()
    stage.size = VIEW_SIZE
    add_child(stage)
    resized.connect(_scale_stage)
    _scale_stage()
    _build_ui()
    if not ids.is_empty(): _show_selected()

func _scale_stage() -> void:
    if stage == null: return
    var factor: float = minf(size.x / VIEW_SIZE.x, size.y / VIEW_SIZE.y)
    stage.scale = Vector2(factor, factor)
    stage.position = (size - VIEW_SIZE * factor) / 2.0

func _panel(rect: Rect2, color: Color, border: Color) -> PanelContainer:
    var panel = PanelContainer.new()
    panel.position = rect.position
    panel.size = rect.size
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style = StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    panel.add_theme_stylebox_override("panel", style)
    stage.add_child(panel)
    return panel

func _label(value: String, point: Vector2, dims: Vector2, fontsize: int, tint: Color) -> Label:
    var label = Label.new()
    label.text = value
    label.position = point
    label.size = dims
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", fontsize)
    label.add_theme_color_override("font_color", tint)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(label)
    return label

func _button(value: String, point: Vector2, dims: Vector2, callback: Callable) -> Button:
    var btn = Button.new()
    btn.text = value
    btn.position = point
    btn.size = dims
    stage.add_child(btn)
    btn.pressed.connect(callback)
    return btn

func _build_ui() -> void:
    var background = ColorRect.new()
    background.color = Color("0b111d")
    background.size = VIEW_SIZE
    stage.add_child(background)
    _panel(Rect2(24, 22, 1232, 95), INK, Color("594c50"))
    _label("SHATTERED CROWN ECHO  /  STEP 10", Vector2(44, 29), Vector2(680, 42), 30, GOLD)
    _label("Region1：14体の分割アニメーション素材 × 高精細コンセプト比較", Vector2(46, 78), Vector2(945, 27), 18, Color("bac4d7"))
    _panel(Rect2(24, 127, 591, 527), Color("162133"), Color("71899d"))
    _panel(Rect2(632, 127, 624, 527), Color("172134"), Color("92746a"))
    _label("現在の可動スプライト（STEP9：頭・胴体・武器）", Vector2(42, 142), Vector2(540, 40), 19, GOLD)
    _label("新しい高精細原画（背景付き・未リギング）", Vector2(650, 142), Vector2(565, 40), 19, GOLD)
    model = Node2D.new()
    model.position = Vector2(315, 544)
    stage.add_child(model)
    preview_art = TextureRect.new()
    preview_art.position = Vector2(663, 204)
    preview_art.size = Vector2(563, 338)
    preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(preview_art)
    current_id = _label("", Vector2(42, 182), Vector2(470, 35), 23, Color("ffffff"))
    current_name = _label("", Vector2(657, 547), Vector2(565, 42), 23, GOLD)
    current_role = _label("", Vector2(657, 588), Vector2(565, 48), 16, Color("cfdae8"))
    mismatch_notice = _label("※ 原画はデザイン検討用です。現在の可動パーツへ直接切り抜いて使うことはできません。", Vector2(35, 660), Vector2(1189, 40), 17, Color("ffcd9f"))
    _button("◀ 前の敵", Vector2(29, 570), Vector2(142, 60), _shift.bind(-1))
    _button("次の敵 ▶", Vector2(472, 570), Vector2(140, 60), _shift.bind(1))
    _button("攻撃動作", Vector2(209, 575), Vector2(189, 53), _attack)
    dropdown = OptionButton.new()
    dropdown.position = Vector2(770, 30)
    dropdown.size = Vector2(345, 51)
    stage.add_child(dropdown)
    for item in ids: dropdown.add_item(item + "  " + str(profiles[item].get("concept_name", "")))
    dropdown.item_selected.connect(_select_index)
    counter = _label("", Vector2(1147, 48), Vector2(98, 35), 18, Color.WHITE)

func _shift(direction: int) -> void:
    if anim_busy or ids.is_empty(): return
    selected = posmod(selected + direction, ids.size())
    _show_selected()

func _select_index(index: int) -> void:
    if anim_busy: return
    selected = clampi(index, 0, ids.size()-1)
    _show_selected()

func _show_selected() -> void:
    for child in model.get_children():
        model.remove_child(child)
        child.queue_free()
    parts.clear()
    origins.clear()
    elapsed = 0.0
    var enemy_id: String = ids[selected]
    var data: Dictionary = profiles[enemy_id]
    current_id.text = enemy_id + "  /  " + str(data.get("concept_name", ""))
    current_name.text = str(data.get("concept_name", ""))
    current_role.text = "戦闘上の役割：" + str(data.get("visual_role", ""))
    preview_art.texture = load(ART_ROOT + enemy_id + ".webp")
    dropdown.select(selected)
    counter.text = "%d / %d" % [selected+1, ids.size()]
    var tier: String = str(data.get("tier", "mob"))
    var part_scale: float = 1.0 if tier=="mob" else (1.05 if tier=="elite" else 1.15)
    for part in ["body", "head", "weapon"]:
        var tex: Texture2D = load(ASSET_ROOT + enemy_id + "/" + part + ".png")
        if tex == null: continue
        var sprite = Sprite2D.new()
        sprite.texture = tex
        sprite.name = part.capitalize()
        sprite.z_index = {"body":0,"head":2,"weapon":3}.get(part,0)
        var offs: Array = data.get("offsets",{}).get(part,{}).get("offset",[0.0,0.0])
        sprite.position = Vector2(float(offs[0]), float(offs[1]))
        sprite.scale = Vector2.ONE * part_scale
        model.add_child(sprite)
        parts[part] = sprite
        origins[part] = sprite.position

func _process(delta: float) -> void:
    if anim_busy: return
    elapsed += delta
    if parts.has("head"):
        var head: Sprite2D = parts["head"]
        head.position.y = (origins["head"] as Vector2).y + sin(elapsed*2.1)*2.5
        head.rotation_degrees = sin(elapsed*1.25)*1.4
    if parts.has("weapon"):
        var weapon: Sprite2D = parts["weapon"]
        weapon.rotation_degrees = sin(elapsed*1.65)*2.8

func _attack() -> void:
    if anim_busy or not parts.has("weapon"): return
    anim_busy = true
    var weapon: Sprite2D = parts["weapon"]
    var head: Sprite2D = parts.get("head")
    var body: Sprite2D = parts.get("body")
    var swing = create_tween()
    swing.tween_property(weapon,"rotation_degrees",-28.0,0.16)
    swing.tween_property(weapon,"rotation_degrees",35.0,0.19)
    swing.tween_property(weapon,"rotation_degrees",0.0,0.24)
    if is_instance_valid(body):
        var b = create_tween()
        b.tween_property(body,"position:x",(origins["body"] as Vector2).x-13.0,0.18)
        b.tween_property(body,"position:x",(origins["body"] as Vector2).x,0.31)
    if is_instance_valid(head):
        head.rotation_degrees = 0.0
    await swing.finished
    anim_busy = false
