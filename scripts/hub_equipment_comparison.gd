class_name HubEquipmentComparison
extends RefCounted

var analyzer=HubDeckAnalyzer.new()

# Only copied equipment and public card metadata enter this calculation.
func compare(items: Dictionary,candidate: Dictionary) -> Dictionary:
    var before_items: Dictionary=items.duplicate(true)
    var after_items: Dictionary=items.duplicate(true)
    var slot: String=str(candidate.get("slot",""))
    if not HubDeckAnalyzer.SLOTS.has(slot):return {"valid":false}
    var current: Dictionary=before_items.get(slot,{})
    after_items[slot]=candidate.duplicate(true)
    var before: Dictionary=analyzer.analyze(before_items)
    var after: Dictionary=analyzer.analyze(after_items)
    # analyze() calculates orphan_pairs for every caller, not only comparisons.
    var focus: Dictionary={}
    for field in ["attribute","weapon"]:
        var best: String=""
        var best_count: int=-1
        for key in analyzer.categories(field):
            var count: int=int(before.distribution[field].get(key,0))
            if count>best_count:best=str(key);best_count=count
        focus[field]={"name":best,"before":int(before.distribution[field].get(best,0)),"after":int(after.distribution[field].get(best,0))}
    return {"valid":true,"slot":slot,"current":current.duplicate(true),"candidate":candidate.duplicate(true),"before_items":before_items,"after_items":after_items,"before":before,"after":after,"focus":focus,"unchanged":before_items==after_items}
