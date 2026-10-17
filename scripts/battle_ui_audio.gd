class_name BattleUIAudio
extends Node

# Small procedural cues keep the prototype fully functional without licensed assets.
# Audio is local presentation only; no battle controller or multiplayer network state.
var ui_volume: float = 0.45
var sfx_volume: float = 0.6
var bgm_volume: float = 0.6 # Reserved for a future BGM player.
var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _cursor: int = 0

func _ready() -> void:
    for i in range(6):
        var player := AudioStreamPlayer.new()
        player.bus = "Master"
        add_child(player)
        _players.append(player)

func set_levels(ui: float, sfx: float, bgm: float) -> void:
    ui_volume = clampf(ui, 0.0, 1.0)
    sfx_volume = clampf(sfx, 0.0, 1.0)
    bgm_volume = clampf(bgm, 0.0, 1.0)

func play_cue(kind: String, weapon: String = "", attribute: String = "") -> void:
    var is_ui := kind in ["select", "cancel", "draw"]
    var volume: float = ui_volume if is_ui else sfx_volume
    if volume <= 0.001 or _players.is_empty():
        return
    if not _cache.has(kind):
        _cache[kind] = _make_tone(kind)
    var player: AudioStreamPlayer = _players[_cursor % _players.size()]
    _cursor += 1
    player.stop()
    player.stream = _cache[kind]
    # Subtle timbre distinctions, not tied to game balance or simulation RNG.
    var weapon_offset: int = ["片手剣", "レイピア", "短剣", "大剣", "魔法剣", "刀"].find(weapon)
    var attribute_offset: int = ["物理", "炎", "水", "雷", "地", "光", "闇", "毒", "秘術", "風"].find(attribute)
    player.pitch_scale = clampf(1.0 + float(weapon_offset) * 0.055 + float(attribute_offset) * 0.013, 0.75, 1.65)
    player.volume_db = linear_to_db(maxf(0.001, volume * 0.35))
    player.play()

func _make_tone(kind: String) -> AudioStreamWAV:
    var hz: float = {"select": 560.0, "cancel": 350.0, "draw": 470.0, "use": 410.0,
        "hit": 220.0, "block": 290.0, "heal": 660.0, "kill": 330.0,
        "combo": 735.0, "finisher": 175.0}.get(kind, 400.0)
    var duration: float = 0.17 if kind == "finisher" else 0.095
    var rate: int = 22050
    var count: int = int(duration * rate)
    var samples := PackedByteArray()
    samples.resize(count * 2)
    for i in range(count):
        var phase: float = float(i) / float(rate)
        var envelope: float = pow(1.0 - float(i) / float(count), 2.0)
        var value: int = int(14000.0 * envelope * sin(TAU * hz * phase))
        samples.encode_s16(i * 2, value)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = samples
    return stream
