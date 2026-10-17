class_name EquipmentOfferHoverPanel
extends PanelContainer

# Shared, read-only equipment preview for solo/co-op reward, chest and merchant.
# Hover only: never changes inventory, rolls, run state, RNG, or networking.
const SLOT_LABELS := {
    "main_weapon":"主武器", "offhand":"副装備", "head":"頭",
    "body":"胴", "hands":"手", "feet":"足"
}
var cards: Dictionary = {}
var heading: Label
var information: Label
var effects: Label
var cards_grid: GridContainer
var card_details: Label

func _init() -> void:
    name="EquipmentOfferHoverDetail"
    size_flags_horizontal=Control.SIZE_EXPAND_FILL
    custom_minimum_size.x=585
    var style=StyleBoxFlat.new()
    style.bg_color=Color("202a36")
    style.border_color=Color("536782")
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.set_content_margin_all(12)
    add_theme_stylebox_override("panel",style)
    var box=VBoxContainer.new()
    box.add_theme_constant_override("separation",7)
    add_child(box)
    heading=_label(box,"装備にカーソルを合わせて詳細を確認",20)
    information=_label(box,"取得する前に、特殊効果と4枚のカードを確認できます。",14)
    effects=_label(box,"",14)
    _label(box,"技の詳細：カードにカーソルを合わせると正式効果を表示",14)
    cards_grid=GridContainer.new()
    cards_grid.name="EquipmentFourCardChoices"
    cards_grid.columns=2
    cards_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    box.add_child(cards_grid)
    card_details=_label(box,"",14)
    card_details.name="EquipmentCardFullDescription"
    var db=CardDatabase.new()
    if db.load_data():
        cards=db.cards

func _label(parent: Node,value: String,point_size: int) -> Label:
    var result=Label.new()
    result.text=value
    result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    result.add_theme_font_size_override("font_size",point_size)
    parent.add_child(result)
    return result

func show_item(item: Dictionary) -> void:
    # A stock slot may already have been purchased by the other player.
    if item.is_empty():
        clear_preview()
        return
    var rarity: String=str(item.get("rarity","Common"))
    var slot: String=str(item.get("slot",""))
    var hp: int=int(item.get("effective_hp",item.get("base_hp",0)))
    heading.text="%s  [%s]"%[str(item.get("name",item.get("equipment_id","装備"))),rarity]
    heading.modulate=HubCardView.tone(rarity)
    information.text="部位：%s  /  HP +%d  /  固定2枚＋ランダム2枚\n属性：%s  /  武器：%s"%[
        str(SLOT_LABELS.get(slot,slot)), hp,
        str(item.get("rolled_attribute","-")),str(item.get("affinity_weapon","-"))
    ]
    effects.text="【装備特殊効果】\n"+EquipmentSpecialEffectPolicy.summary(item)
    for child in cards_grid.get_children():
        cards_grid.remove_child(child)
        child.queue_free()
    var first_id: String=""
    for group in ["fixed_cards","random_cards"]:
        var label: String="固定" if group=="fixed_cards" else "ランダム"
        var ids: Array=item.get(group,[])
        for value in ids:
            var card_id: String=str(value)
            if first_id=="":first_id=card_id
            var card: Dictionary=cards.get(card_id,{})
            var action=Button.new()
            action.name="Inspect_"+card_id
            action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
            action.custom_minimum_size.y=44
            var name_text: String=str(card.get("display_name",card_id))
            action.text="%s  %s  Cost%d"%[label,card_id,int(card.get("cost",0))]
            action.tooltip_text=_card_description(card_id)
            cards_grid.add_child(action)
            action.mouse_entered.connect(_show_card.bind(card_id))
            action.focus_entered.connect(_show_card.bind(card_id))
            action.pressed.connect(_show_card.bind(card_id))
    if first_id!="":
        _show_card(first_id)
    else:
        card_details.text="カードデータがありません。"

func clear_preview() -> void:
    heading.text="装備にカーソルを合わせて詳細を確認"
    heading.modulate=Color.WHITE
    information.text="取得する前に、特殊効果と4枚のカードを確認できます。"
    effects.text=""
    card_details.text=""
    for child in cards_grid.get_children():
        cards_grid.remove_child(child)
        child.queue_free()

func _card_description(card_id: String) -> String:
    if not cards.has(card_id):
        return "カードID %s：マスターデータに見つかりません。"%card_id
    var card: Dictionary=cards[card_id]
    var meta: String="%s  /  Cost%d  /  %s  /  %s  /  %s"%[
        str(card.get("display_name",card_id)),int(card.get("cost",0)),
        str(card.get("card_type","-")).capitalize(),
        str(card.get("weapon","-")),str(card.get("attribute","-"))
    ]
    return meta+"\n"+WeaponTraitCardDescription.combined_text(card)

func _show_card(card_id: String) -> void:
    card_details.text="【技の正式効果】\n"+_card_description(card_id)

static func offer_button_text(item: Dictionary,number: int=-1) -> String:
    if item.is_empty():return "売り切れ"
    var slot: String=str(item.get("slot",""))
    var prefix: String="%d.  "%[number+1] if number>=0 else ""
    var effects = item.get("special_effects",[])
    var count: int=effects.size() if effects is Array else 0
    return "%s%s  /  %s  /  HP%d\n%s  （特殊効果%d）"%[
        prefix,str(SLOT_LABELS.get(slot,slot)),str(item.get("rarity","?")),
        int(item.get("effective_hp",item.get("base_hp",0))),
        str(item.get("name",item.get("equipment_id","装備"))),count
    ]
