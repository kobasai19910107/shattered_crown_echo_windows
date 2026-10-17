extends Control
## Fully isolated STEP3 lab. No card costs, no RNG, no HP gameplay changes.
const BRIDGE_SCRIPT = preload("res://ui_trial/live_bridge.gd")
const WEAPONS := ["片手剣","レイピア","短剣","大剣","魔法剣","刀"]
const ATTRS := ["物理","炎","水","雷","地","光","闇","毒","秘術","風"]
var weapon_choice: OptionButton
var attribute_choice: OptionButton
var bridge: Control
var status: Label
var demo_finisher: bool = false

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = Color("101722")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation",16)
    root.add_theme_constant_override("margin_left",10)
    add_child(root)
    var title := Label.new()
    title.text = "SHATTERED CROWN ECHO / STEP 3 — 6 WEAPONS × 10 ATTRIBUTES"
    title.add_theme_font_size_override("font_size",23)
    root.add_child(title)
    var sub := Label.new()
    sub.text = "3頭身アニメ連動ラボ：武器差分 / 属性差分 / カットイン（ダミー数値・戦闘ロジック未接続）"
    sub.add_theme_font_size_override("font_size",13)
    root.add_child(sub)
    bridge = Control.new()
    bridge.set_script(BRIDGE_SCRIPT)
    bridge.custom_minimum_size = Vector2(0,280)
    bridge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_child(bridge)
    var form := HBoxContainer.new()
    root.add_child(form)
    form.add_theme_constant_override("separation",10)
    weapon_choice = OptionButton.new()
    for label in WEAPONS: weapon_choice.add_item(label)
    form.add_child(weapon_choice)
    attribute_choice = OptionButton.new()
    for label in ATTRS: attribute_choice.add_item(label)
    form.add_child(attribute_choice)
    _button(form,"Attack動作",_play_attack)
    _button(form,"Skill動作",_play_skill)
    _button(form,"Finisher動作",_play_finisher)
    _button(form,"敵ターン動作",_play_enemy)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.text = "武器と属性を選択し、ボタンを押してください。攻撃数値は表示専用のダミーです。"
    root.add_child(status)

func _button(parent: Control,title: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(130,46)
    button.pressed.connect(callback)
    parent.add_child(button)

func _selected_card(kind: String) -> Dictionary:
    var weapon: String = WEAPONS[weapon_choice.selected]
    var attribute: String = ATTRS[attribute_choice.selected]
    return {"id":"DEMO", "display_name":"DEMO / %s %s" %[attribute,weapon],
        "weapon":weapon,"attribute":attribute,
        "card_type":kind,"role":"決着技" if demo_finisher else "基本攻撃"}

func _play_attack() -> void:
    demo_finisher = false
    bridge.queue_card(_selected_card("attack"), [{"kind":"enemy_hit","hp_loss":12,"block_loss":0}],0,1.0,2)
    status.text = "Attack: 選択武器の攻撃動作＋属性エフェクト（デモ12ダメージ）"

func _play_skill() -> void:
    demo_finisher = false
    bridge.queue_card(_selected_card("skill"), [{"kind":"resource","resource":"block_gained","amount":5}],-1,1.0,2)
    status.text = "Skill: 選択武器の構え＋属性エフェクト（戦闘数値は変更しません）"

func _play_finisher() -> void:
    demo_finisher = true
    bridge.queue_card(_selected_card("attack"), [{"kind":"enemy_hit","hp_loss":28,"block_loss":0}],0,1.0,2)
    status.text = "Finisher: 高頭身カットイン＋選択武器のフィニッシュ動作（デモ28ダメージ）"

func _play_enemy() -> void:
    bridge.queue_enemy_turn([{"kind":"enemy_action","enemy":0}, {"kind":"player_hit","hp_loss":4,"block_loss":0}],1.0,2)
    status.text = "敵フェーズ: ダミー被弾演出（実戦HPには影響しません）"
