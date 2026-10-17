class_name GameTitleScreen
extends Control

signal continue_requested
signal new_game_requested
signal exit_requested

var notice: Label
var resume_button: Button
var new_confirmation: ConfirmationDialog

func build(has_save: bool, summary: String, has_existing_file: bool = false) -> void:
    name = "TitleScreen"
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var background := ColorRect.new()
    background.color = Color("10131f")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(background)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(center)

    var frame := PanelContainer.new()
    frame.custom_minimum_size = Vector2(580, 480)
    frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("202632")
    panel_style.border_color = Color("a38a56")
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(16)
    panel_style.set_content_margin_all(30)
    frame.add_theme_stylebox_override("panel",panel_style)
    center.add_child(frame)

    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation",14)
    frame.add_child(column)

    var heading := Label.new()
    heading.text = "SHATTERED CROWN ECHO"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size",32)
    heading.add_theme_color_override("font_color",Color("f4d994"))
    column.add_child(heading)

    var tagline := Label.new()
    tagline.text = "砕かれた王冠に、もう一度挑む。"
    tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tagline.add_theme_font_size_override("font_size",17)
    column.add_child(tagline)

    column.add_spacer(false)

    resume_button = Button.new()
    resume_button.text = "続きから"
    resume_button.custom_minimum_size.y = 54
    resume_button.disabled = not has_save
    resume_button.pressed.connect(func():continue_requested.emit())
    column.add_child(resume_button)

    var new_button := Button.new()
    new_button.text = "最初から"
    new_button.custom_minimum_size.y = 54
    column.add_child(new_button)

    var leave := Button.new()
    leave.text = "ゲームを終了"
    leave.custom_minimum_size.y = 44
    leave.pressed.connect(func():exit_requested.emit())
    column.add_child(leave)

    notice = Label.new()
    notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.custom_minimum_size.y = 48
    notice.text = summary if summary != "" else "セーブデータなし：最初から開始できます。"
    column.add_child(notice)

    new_confirmation = ConfirmationDialog.new()
    new_confirmation.title = "最初から開始"
    new_confirmation.dialog_text = ("現在のソロセーブをバックアップし、新しい冒険を開始します。\n進行・所持装備・拠点Goldは初期状態に戻ります。\nよろしいですか？" if has_existing_file else "新しい冒険を開始します。")
    new_confirmation.ok_button_text = "最初から開始"
    new_confirmation.confirmed.connect(func():new_game_requested.emit())
    add_child(new_confirmation)
    new_button.pressed.connect(func():new_confirmation.popup_centered())

func set_message(message: String) -> void:
    if is_instance_valid(notice):
        notice.text=message
