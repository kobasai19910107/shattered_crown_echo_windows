class_name BattleLogDialog
extends RefCounted

# A copy of confirmed logs only: opening this window never advances combat.
static func show_log(owner_node: Node, entries: Array, summary: String="敗北時の戦闘ログ") -> AcceptDialog:
    var dialog=AcceptDialog.new();dialog.name="DefeatBattleLog";dialog.title=summary
    dialog.min_size=Vector2i(560,360);dialog.ok_button_text="閉じる";owner_node.add_child(dialog)
    var box=VBoxContainer.new();dialog.add_child(box)
    var text=TextEdit.new();text.name="ConfirmedBattleLog";text.editable=false;text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
    text.custom_minimum_size=Vector2(540,300);text.size_flags_vertical=Control.SIZE_EXPAND_FILL
    var lines: PackedStringArray=[]
    for entry in entries:lines.append(str(entry))
    text.text="\n".join(lines) if not entries.is_empty() else "保存された戦闘ログはありません。"
    box.add_child(text)
    var copy=Button.new();copy.text="ログをコピー";box.add_child(copy)
    copy.pressed.connect(func():DisplayServer.clipboard_set(text.text))
    dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free)
    var viewport: Vector2i=owner_node.get_viewport().get_visible_rect().size
    dialog.popup_centered(Vector2i(mini(860,viewport.x-40),mini(620,viewport.y-40)))
    text.set_caret_line(maxi(0,text.get_line_count()-1))
    return dialog
