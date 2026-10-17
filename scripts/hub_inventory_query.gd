class_name HubInventoryQuery
extends RefCounted

const RARITY_ORDER={"Common":0,"Rare":1,"Epic":2,"Legendary":3}

static func item_name(item: Dictionary) -> String:
    return str(item.get("name",item.get("equipment_id","未解決装備")))

static func rows(state: Dictionary,filters: Dictionary,cards: Dictionary) -> Array:
    var result: Array=[]
    for uid in state.get("inventory",{}):
        var item: Dictionary=state.inventory[uid]
        var equipped: bool=state.get("loadout",{}).values().has(uid)
        if bool(filters.get("equipped",false)) and not equipped:continue
        var rejected: bool=false
        for field in ["slot","rarity","rolled_attribute"]:
            var chosen: String=str(filters.get(field,""))
            if chosen!="" and str(item.get(field,""))!=chosen:rejected=true
        for field in ["attribute","weapon"]:
            var chosen: String=str(filters.get("card_"+field,""))
            if chosen=="":continue
            var found: bool=false
            for id in item.get("cards",[]):
                if str(cards.get(str(id),{}).get(field,""))==chosen:found=true
            if not found:rejected=true
        var search: String=str(filters.get("search","")).strip_edges().to_lower()
        var text: String=item_name(item)+" "+str(uid)+" "+str(item.get("slot",""))+" "+str(item.get("rarity",""))+" "+str(item.get("rolled_attribute",""))
        for id in item.get("cards",[]):text+=" "+str(id)+" "+str(cards.get(str(id),{}).get("text",""))
        if search!="" and not text.to_lower().contains(search):rejected=true
        if not rejected:result.append({"uid":str(uid),"item":item.duplicate(true),"equipped":equipped,"uid_valid":str(item.get("instance_id",""))==str(uid)})
    var mode: String=str(filters.get("sort","rarity"))
    result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        var rarity_a: int=int(RARITY_ORDER.get(str(a.item.get("rarity","")),-1))
        var rarity_b: int=int(RARITY_ORDER.get(str(b.item.get("rarity","")),-1))
        var hp_a: int=int(a.item.get("effective_hp",a.item.get("base_hp",0)))
        var hp_b: int=int(b.item.get("effective_hp",b.item.get("base_hp",0)))
        if mode=="hp" and hp_a!=hp_b:return hp_a>hp_b
        if mode!="name" and rarity_a!=rarity_b:return rarity_a>rarity_b
        if mode!="name" and hp_a!=hp_b:return hp_a>hp_b
        var order: int=item_name(a.item).naturalnocasecmp_to(item_name(b.item))
        return str(a.uid)<str(b.uid) if order==0 else order<0)
    return result
