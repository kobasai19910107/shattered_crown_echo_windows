extends SceneTree

var passes: int = 0
var fails: Array[String] = []

func check(name: String, condition: bool) -> void:
    if condition:
        passes += 1
    else:
        fails.append(name)
        push_error("FAIL: "+name)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var roller = Step8EquipmentRoller.new()
    check("policy loads 120", roller.load_data() and roller.cards.size()==120)
    var generator = Region1RunController.new()
    var rarity_counts: Dictionary = {"Common":0,"Rare":0,"Epic":0,"Legendary":0}
    var observed: Dictionary = {}
    var categories: Array[String] = ["battle","elite","boss","chest","shop"]
    for kind in categories:
        var rng = RandomNumberGenerator.new()
        rng.seed=981901
        var next: Dictionary = {"run":{"seed":718181},"sequence":0}
        for _iteration in range(300):
            var result: Dictionary=generator._drop(next,kind,rng)
            check("legal drop %s" % kind, roller.validate_item(result) and EquipmentSpecialEffectPolicy.validate_effects(result))
            var target_count: int=int(EquipmentSpecialEffectPolicy.RARITY_SLOTS[str(result.get("rarity","Common"))])
            check("rarity slot count %s" % kind, result.get("special_effects",[]).size()==target_count)
            rarity_counts[str(result.get("rarity","Common"))]+=1
            for eff in result.get("special_effects",[]): observed[str(eff.effect_id)]=true
        # Three reward choices work with the existing anti-duplicate filter.
        var offers: Array=generator._offer(next,kind,rng)
        check("3 offers %s" % kind, offers.size()==3)
        for item in offers:
            check("legal offered item %s" % kind, roller.validate_item(item) and EquipmentSpecialEffectPolicy.validate_effects(item))
    check("Rare/Epic/Legendary present", rarity_counts.Rare>0 and rarity_counts.Epic>0 and rarity_counts.Legendary>0)
    var observed_u: bool = true
    var observed_w: bool = false
    for effect_id in EquipmentSpecialEffectPolicy.U_EFFECT_IDS:
        if not observed.has(effect_id): observed_u=false
    for effect_id in EquipmentSpecialEffectPolicy.W_EFFECT_IDS:
        if observed.has(effect_id): observed_w=true
    check("U01-U10 still sampled", observed_u)
    check("some W01-W18 sampled on drops", observed_w)
    check("attribute A01-A20 available", EquipmentSpecialEffectPolicy.A_EFFECT_IDS.size()==20 and EquipmentSpecialEffectPolicy.EFFECT_IDS.size()==48)
    var typical: Dictionary = roller.generate_item(str(roller.get_templates_for_slot("main_weapon")[0].EquipmentID),240020)
    check("raw roller unchanged empty",typical.special_effects.is_empty())
    var raw_seed_rng = RandomNumberGenerator.new()
    raw_seed_rng.seed = 987654321
    var state_before: int = raw_seed_rng.state
    var effect_first: Array=EquipmentSpecialEffectPolicy.roll_on_drop(typical)
    var effect_again: Array=EquipmentSpecialEffectPolicy.roll_on_drop(typical)
    check("affix seed deterministic",effect_first==effect_again)
    check("external RNG unchanged",raw_seed_rng.state==state_before)
    # A forged invalid or duplicate ID must not pass coop admission.
    var loadout: Dictionary = {}
    for index in range(Region1RunController.SLOTS.size()):
        var slot: String=Region1RunController.SLOTS[index]
        var pool: Array=roller.get_templates_for_slot(slot)
        var selected: Dictionary={}
        for template in pool:
            if str(template.Rarity)=="Rare": selected=template; break
        var item: Dictionary=roller.generate_item(str(selected.EquipmentID),561400+index)
        item.instance_id="UNIQUE_%s" % slot
        item.special_effects=EquipmentSpecialEffectPolicy.roll_on_drop(item)
        item.enhance_level=0
        item.effective_hp=item.base_hp
        item.socket_count=int(roller.templates[str(item.equipment_id)].InitialSocketMin)
        loadout[slot]=item
    check("cooperative admission of U effects",CoopCampaignController.valid_items(loadout))
    var modified: Dictionary=loadout.duplicate(true)
    modified.main_weapon.special_effects=[{"effect_id":"W99"}]
    check("cooperative rejects unknown effect",not CoopCampaignController.valid_items(modified))
    # Legacy saves without the optional effect field are still admitted.
    modified=loadout.duplicate(true)
    for slot in modified: modified[slot].erase("special_effects")
    check("legacy empty effects admitted",CoopCampaignController.valid_items(modified))
    # Forge card rerolls may leave an affix dormant, but cannot corrupt the save.
    var forge_item: Dictionary=loadout.main_weapon.duplicate(true)
    forge_item.special_effects=[{"effect_id":"U10"}]
    check("ineligible affix remains structurally valid",EquipmentSpecialEffectPolicy.validate_effects(forge_item))
    var save_path: String="user://special_effect_phase2_test.json"
    var saved: Dictionary={"equipped":loadout,"v":2}
    check("save U effects",Region1Save.write(save_path,saved))
    var restored: Dictionary=Region1Save.read(save_path)
    check("load U effects",JSON.stringify(restored)==JSON.stringify(saved))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    print("EQUIPMENT_SPECIAL_EFFECT_DROP_TEST: %d PASS / %d FAIL / rares %s" % [passes,fails.size(),str(rarity_counts)])
    quit(0 if fails.is_empty() else 1)
