class_name BattleUXPreferences
extends RefCounted

# Independent UI-only settings: never written to campaign / equipment saves.
const PATH := "user://battle_ux_preferences.cfg"
var vfx_quality: int = 2
var speed: int = 1
var ui_volume: float = 0.45
var sfx_volume: float = 0.6
var bgm_volume: float = 0.6

func load_local() -> void:
    var config := ConfigFile.new()
    if config.load(PATH) != OK:
        return
    vfx_quality = clampi(int(config.get_value("presentation", "quality", 2)), 0, 2)
    speed = clampi(int(config.get_value("presentation", "speed", 1)), 1, 3)
    ui_volume = clampf(float(config.get_value("audio", "ui", 0.45)), 0.0, 1.0)
    sfx_volume = clampf(float(config.get_value("audio", "sfx", 0.6)), 0.0, 1.0)
    bgm_volume = clampf(float(config.get_value("audio", "bgm", 0.6)), 0.0, 1.0)

func save_local() -> void:
    var config := ConfigFile.new()
    config.set_value("presentation", "quality", vfx_quality)
    config.set_value("presentation", "speed", speed)
    config.set_value("audio", "ui", ui_volume)
    config.set_value("audio", "sfx", sfx_volume)
    config.set_value("audio", "bgm", bgm_volume)
    var err := config.save(PATH)
    if err != OK:
        push_warning("Battle UI settings could not be saved: %s" % error_string(err))
