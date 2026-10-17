class_name MonsterPortrait
extends RefCounted

# Original sheets are preserved. Atlas regions omit printed nameplates.
const NORMAL = "res://assets/monsters/region1/normal_sheet.webp"
const SPECIAL = "res://assets/monsters/region1/elite_boss_sheet.webp"
const REGIONS = {
    "R1-N01": [NORMAL, Rect2(0, 0, 400, 450)],
    "R1-N02": [NORMAL, Rect2(400, 0, 370, 450)],
    "R1-N03": [NORMAL, Rect2(770, 0, 360, 450)],
    "R1-N04": [NORMAL, Rect2(1130, 0, 406, 450)],
    "R1-N05": [NORMAL, Rect2(0, 520, 535, 405)],
    "R1-N06": [NORMAL, Rect2(535, 520, 495, 405)],
    "R1-N07": [NORMAL, Rect2(1030, 520, 506, 405)],
    "R1-E01": [SPECIAL, Rect2(0, 0, 565, 430)],
    "R1-E02": [SPECIAL, Rect2(565, 0, 440, 430)],
    "R1-E03": [SPECIAL, Rect2(1005, 0, 531, 430)],
    "R1-B01": [SPECIAL, Rect2(0, 500, 395, 425)],
    "R1-B02": [SPECIAL, Rect2(395, 500, 400, 425)],
    "R1-B03": [SPECIAL, Rect2(795, 500, 380, 425)],
    "R1-B04": [SPECIAL, Rect2(1175, 500, 361, 425)]
}
const INDIVIDUAL = {
    "R2-B01": "res://assets/monsters/individual/R2-B01.webp",
    "R2-E01": "res://assets/monsters/individual/R2-E01.webp",
    "R1-B03": "res://assets/monsters/individual/R1-B03.webp",
    "R1-B02": "res://assets/monsters/individual/R1-B02.webp",
    "R1-E02": "res://assets/monsters/individual/R1-E02.webp",
    "R1-B04": "res://assets/monsters/individual/R1-B04.webp",
    "R1-E03": "res://assets/monsters/individual/R1-E03.webp",
    "R1-B01": "res://assets/monsters/individual/R1-B01.webp",
    "R1-N03": "res://assets/monsters/individual/R1-N03.webp",
    "R1-N07": "res://assets/monsters/individual/R1-N07.webp",
    "R1-N04": "res://assets/monsters/individual/R1-N04.webp",
    "R1-N05": "res://assets/monsters/individual/R1-N05.webp",
    "R1-N01": "res://assets/monsters/individual/R1-N01.webp",
}
static var textures: Dictionary = {}

static func texture_for(enemy_id: String) -> Texture2D:
    if INDIVIDUAL.has(enemy_id):
        if not textures.has(enemy_id):textures[enemy_id]=load(INDIVIDUAL[enemy_id])
        return textures[enemy_id]
    var definition: Array=REGIONS.get(enemy_id,[])
    if definition.is_empty(): definition=_extra_definition(enemy_id)
    if definition.is_empty(): return null
    if not textures.has(enemy_id):
        var atlas = AtlasTexture.new()
        atlas.atlas = load(definition[0])
        var bounds: Rect2=definition[1]
        if not REGIONS.has(enemy_id): bounds=Rect2(bounds.position*atlas.atlas.get_size(),bounds.size*atlas.atlas.get_size())
        atlas.region = bounds
        atlas.filter_clip = true
        textures[enemy_id] = atlas
    return textures[enemy_id]

static func _extra_definition(enemy_id: String) -> Array:
    if enemy_id.length()!=6 or enemy_id.substr(0,1)!="R": return []
    var region: int=int(enemy_id.substr(1,1))
    var index: int=int(enemy_id.substr(4,2))-1
    var rank: String=enemy_id.substr(3,1)
    if region<2 or region>6 or index<0: return []
    var filename: String="elite_boss_sheet"
    var bounds: Rect2
    if rank=="N":
        if index>=7 or (region==6 and index>=6): return []
        filename="normal_sheet"
        var top_count: int=3 if region==6 else 4
        if index<top_count: bounds=Rect2(float(index)/top_count,0,1.0/top_count,0.48 if region==6 else 0.42)
        else: bounds=Rect2(float(index-top_count)/3.0,0.50,1.0/3.0,0.50 if region==6 else 0.41)
    elif rank=="E" and index<3: bounds=Rect2(float(index)/3.0,0,1.0/3.0,0.42)
    elif rank=="B" and index<4: bounds=Rect2(float(index)/4.0,0.50,0.25,0.41)
    else: return []
    return ["res://assets/monsters/region%d/%s.webp"%[region,filename],bounds]

static func update(button: Button, enemy: Dictionary) -> void:
    var texture = texture_for(str(enemy.get("id", "")))
    var visual = button.get_node_or_null("MonsterVisual")
    if texture == null:
        if visual != null:
            button.remove_child(visual)
            visual.queue_free()
        button.custom_minimum_size.y = 132
        return
    if visual == null:
        visual = VBoxContainer.new()
        visual.name = "MonsterVisual"
        visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
        visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        visual.offset_left = 6
        visual.offset_right = -6
        visual.offset_top = 6
        visual.offset_bottom = -6
        visual.add_theme_constant_override("separation", 4)
        button.add_child(visual)
        var portrait = TextureRect.new()
        portrait.name = "Portrait"
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        portrait.custom_minimum_size.y = 105
        portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        visual.add_child(portrait)
        var stats = Label.new()
        stats.name = "Stats"
        stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        stats.add_theme_font_size_override("font_size", 13)
        visual.add_child(stats)
    button.custom_minimum_size.y = 170
    visual.get_node("Portrait").texture = texture
    visual.get_node("Portrait").modulate = Color(0.4, 0.4, 0.4) if int(enemy.get("hp", 0)) <= 0 else Color.WHITE
    visual.get_node("Stats").text = button.text
    button.text = ""
