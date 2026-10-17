extends "res://ui_trial/battle_ui_step9.gd"
## STEP21: visual-only R1-B01 Battle Core integration.
## Inherit the STEP9 card, target, pending-selection and campaign-checkpoint UI.
## Never modify enemy action, card data, health or Mana from this presentation class.

const R1_B01_RIG_SCRIPT = preload("res://ui_trial/actors/boss_b01_rig_step19.gd")
const R1_B01_ID := "R1-B01"
# Slightly reduce the R1-B01 rig and keep the feet above the card panel.
const R1_B01_SCREEN_SCALE := 0.98
const R1_B01_BASE := Vector2(947.0,478.0)
var b01_visual_slot: int = -1

func _enemy_base(index: int) -> Vector2:
    # Only this real boss encounter uses adjusted placement.
    if battle != null and index >= 0 and index < battle.get_enemy_count():
        if str(battle.get_enemy(index).get("id", "")) == R1_B01_ID:
            return R1_B01_BASE
    return super._enemy_base(index)

func _rebuild_enemy_visuals() -> void:
    # STEP9 remains the source of truth for hit targets, buttons, status bars,
    # real enemy IDs and on-screen Intent labels. Replace only the visual actor.
    super._rebuild_enemy_visuals()
    b01_visual_slot = -1
    if battle == null:
        return
    for i in range(mini(actors.size(), battle.get_enemy_count())):
        var enemy: Dictionary = battle.get_enemy(i)
        if str(enemy.get("id", "")) != R1_B01_ID:
            continue
        var previous: Node2D = actors[i]
        if is_instance_valid(previous):
            # The target Button is in a separate Control and is not deleted.
            previous.queue_free()
        var articulated: Node2D = R1_B01_RIG_SCRIPT.new()
        articulated.name = "R1B01_ArticulatedVisual"
        articulated.position = _enemy_base(i)
        articulated.scale = Vector2.ONE * R1_B01_SCREEN_SCALE
        field_layer.add_child(articulated)
        articulated.configure_region(enemy, "boss")
        articulated.set_rest_position(_enemy_base(i))
        actors[i] = articulated
        b01_visual_slot = i
        # The upper HUD already shows this solo boss's HP and Intent; the
        # floating duplicate obscured its horn. Keep the invisible target
        # button large enough to click the head, body, or front legs.
        if i < enemy_huds.size() and is_instance_valid(enemy_huds[i]):
            enemy_huds[i].hide()
        if i < enemy_buttons.size() and is_instance_valid(enemy_buttons[i]):
            var boss_hit_button: Button = enemy_buttons[i]
            boss_hit_button.position = Vector2(630,172)
            boss_hit_button.size = Vector2(580,330)

func _show_boss_attack_cutin(index: int) -> void:
    # The actual enemy_action has already been resolved by BattleController.
    # This is a visual lead-in only, not a new attack or a new boss phase.
    if index >= 0 and index < actors.size() and battle != null:
        var enemy: Dictionary = battle.get_enemy(index)
        if str(enemy.get("id", "")) == R1_B01_ID and is_instance_valid(actors[index]):
            if actors[index].has_method("play_roar"):
                await actors[index].play_roar(speed)
    await super._show_boss_attack_cutin(index)

func _ready() -> void:
    super._ready()
    # The regular campaign tab invokes bind_campaign_battle() from STEP7/9.
    # It passes the exact CampaignController BattleController instance.
    if is_instance_valid(status):
        status.text = "STEP21：R1-B01 可動ボス接続 / 既存 Battle Core を使用"
