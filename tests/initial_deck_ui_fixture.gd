extends "res://scripts/main.gd"

# Detached UI fixture: no _ready(), real user save restore, or battle scene startup.
func _refresh_loadout_ui() -> void:
    pass

func _step8_refresh() -> void:
    pass

# Legacy-profile synchronous commit fixture; asynchronous production entry has separate tests.
func _on_step8_generate() -> void:
    if step8_roller == null or step8_roller.templates.is_empty():
        step8_status.text = "抽選データ未読込"
        return
    var base_seed := int(step8_seed_input.value)
    var template_ids: Dictionary = {}
    var slots: Array[String] = ["main_weapon", "offhand", "head", "body", "hands", "feet"]
    for index in range(slots.size()):
        var slot_id := slots[index]
        var selector: OptionButton = step8_template_selectors.get(slot_id)
        var ids: Array = step8_template_ids.get(slot_id, [])
        if selector == null or selector.selected < 0 or selector.selected >= ids.size():
            step8_status.text = "選択エラー: %s" % slot_id
            return
        template_ids[slot_id] = str(ids[selector.selected])
    var generator = InitialDeckGeneratorScript.new()
    var generated: Dictionary = generator.generate_initial_loadout(template_ids, base_seed)
    _step8_commit_generated(generated)

