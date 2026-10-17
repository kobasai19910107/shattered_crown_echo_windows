class_name RegionCatalog
extends RefCounted
const NAMES = ["森", "廃墟・毒沼", "火山・風", "氷海・雷", "神殿・星界", "虚空"]
const FINAL_PHASE_NAMES = ["森", "廃墟", "火山", "氷海", "神殿", "虚空"]
static func title(index: int) -> String:
    return "Region %d — %s" % [index+1,NAMES[clampi(index,0,5)]]
