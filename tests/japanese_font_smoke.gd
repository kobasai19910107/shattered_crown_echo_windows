extends SceneTree

const REQUIRED_TEXT := "日本語・新規開始・続きから・終了"

func _initialize() -> void:
    var label := Label.new()
    root.add_child(label)
    var font := label.get_theme_font("font")
    var missing: Array[String] = []
    for character in REQUIRED_TEXT:
        if not font.has_char(character.unicode_at(0)):
            missing.append(character)
    if not missing.is_empty():
        printerr("Japanese font is missing glyphs: ", " ".join(missing))
        quit(1)
        return
    print("Japanese font smoke test passed: ", REQUIRED_TEXT)
    quit(0)
