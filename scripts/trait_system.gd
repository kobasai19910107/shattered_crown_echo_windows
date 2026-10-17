class_name TraitSystem
extends RefCounted

const PLAYER_TRAITS := ["剛力", "帯電", "堅牢", "恩寵", "魔珠", "疾風"]
const ENEMY_TRAITS := ["爆発", "鈍化", "呪印", "猛毒"]

static func stage(stack_count: int) -> int:
    return int(floor(float(max(0, stack_count)) / 3.0))

static func crossed_stages(old_stack: int, new_stack: int) -> Array[int]:
    var result: Array[int] = []
    var old_stage = stage(old_stack)
    var new_stage = stage(new_stack)
    if new_stage <= old_stage:
        return result
    for stage_index in range(old_stage + 1, new_stage + 1):
        result.append(stage_index)
    return result

static func explosion_damage(stage_index: int) -> int:
    # 1st threshold = 5, then +2 each threshold: 5, 7, 9, 11 ...
    return 3 + stage_index * 2

static func is_player_trait(trait_name: String) -> bool:
    return PLAYER_TRAITS.has(trait_name)

static func is_enemy_trait(trait_name: String) -> bool:
    return ENEMY_TRAITS.has(trait_name)
