class_name HubCardView
extends PanelContainer

# Presentation only: the formal text remains intact and in its original order.
var text: String=""
var effect: RichTextLabel

static func tone(value: String) -> Color:
    var colors={"Common":"b8c4d4","Rare":"78bcff","Epic":"d1a0ff","Legendary":"ffd17c","物理":"cbd5e1","火":"ff947d","炎":"ff947d","秘術":"d1a0ff","水":"70caff","氷":"a0eaff","雷":"ffdc77","風":"9de5ba","地":"d5b687","光":"fff0af","闇":"c4a2f4","毒":"a5dc89"}
    var weapons={"片手剣":"78bcff","大剣":"ff947d","刀":"ffd17c","レイピア":"d1a0ff","短剣":"9de5ba","魔法剣":"70caff"}
    return Color(str(colors.get(value,weapons.get(value,"b5d8e8"))))

static func badge(attribute: String,weapon: String) -> Texture2D:
    var image=Image.create(32,8,false,Image.FORMAT_RGBA8)
    image.fill_rect(Rect2i(0,0,14,8),tone(attribute))
    image.fill_rect(Rect2i(18,0,14,8),tone(weapon))
    return ImageTexture.create_from_image(image)

static func emphasized(value: String) -> String:
    var result=""
    for character in value:
        if character.is_valid_int():result+="[b][color=#ffd17c]"+character+"[/color][/b]"
        elif character=="[":result+="[lb]"
        elif character=="]":result+="[rb]"
        else:result+=character
    return result

func build(id: String,analyzer: HubDeckAnalyzer) -> void:
    text=analyzer.card_description(id)
    size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var style=StyleBoxFlat.new();style.bg_color=Color("202c3b");style.border_color=Color("42556c");style.set_border_width_all(1);style.set_content_margin_all(12)
    add_theme_stylebox_override("panel",style)
    var box=VBoxContainer.new();box.add_theme_constant_override("separation",7);add_child(box)
    if not analyzer.cards.has(id):
        var missing=Label.new();missing.text=text;box.add_child(missing);return
    var card: Dictionary=analyzer.cards[id]
    var title=Label.new();title.text=str(card.get("display_name",id));title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.add_theme_font_size_override("font_size",18);box.add_child(title)
    var meta=Label.new();meta.text="%s / %s / %s　Cost %d\n役割 %s / %s"%[card.attribute,card.weapon,str(card.card_type).capitalize(),int(card.cost),card.role,str(card.get("weapon_trait_action","未設定"))];meta.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;meta.modulate=tone(str(card.attribute));box.add_child(meta)
    var weapon=Label.new();weapon.text="◆ 武器 "+str(card.weapon);weapon.modulate=tone(str(card.weapon));box.add_child(weapon)
    var base=Label.new();base.text="マスター基本値：Damage %d / Block %d / %s生成 %d\n対象・付与先・条件は下記の正式本文を参照"%[int(card.get("base_damage",0)),int(card.get("base_block",0)),str(card.get("attribute_trait","特性")),int(card.get("attribute_trait_gain",0))];base.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;base.add_theme_font_size_override("font_size",14);box.add_child(base)
    var caption=Label.new();caption.text="正式本文：Draw・条件・追加効果・解決順";caption.add_theme_font_size_override("font_size",14);box.add_child(caption)
    effect=RichTextLabel.new();effect.name="FormalEffect";effect.bbcode_enabled=true;effect.fit_content=true;effect.scroll_active=false;effect.size_flags_horizontal=Control.SIZE_EXPAND_FILL;effect.text=emphasized(str(card.text));box.add_child(effect)


    var trait_extra: String=WeaponTraitCardDescription.conditional_bbcode(card)
    if trait_extra!="":
        var shared=RichTextLabel.new()
        shared.name="SharedWeaponTraitEffect"
        shared.bbcode_enabled=true
        shared.fit_content=true
        shared.scroll_active=false
        shared.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        shared.text=trait_extra
        box.add_child(shared)
