extends SceneTree

var checked: int=0
var failures: Array[String]=[]

func check(label: String, ok: bool) -> void:
    checked+=1
    if not ok:
        failures.append(label)
        print("FAIL "+label)

func _initialize() -> void:
    call_deferred("run_tests")

func run_tests() -> void:
    var db:=CardDatabase.new()
    check("120 formal cards loaded",db.load_data() and db.get_official_card_count()==120)
    var counts: Dictionary={}
    var source_snapshot: Dictionary={}
    for id in db.get_official_card_ids():
        var card: Dictionary=db.get_card_copy(id)
        source_snapshot[id]=JSON.stringify(card)
        var kind: String=str(card.get("weapon_trait_action", "NEUTRAL"))
        counts[kind]=int(counts.get(kind,0))+1
        var eligible: bool=WeaponTraitCardDescription.is_applicable(card)
        var desc: String=WeaponTraitCardDescription.combined_text(card)
        check("preserves formal text "+id,desc.begins_with(str(card.get("text",""))))
        check("correct role matching "+id,eligible==(kind=="CONSUME"))
        check("CONSUME has condition "+id,(not eligible) or desc.contains("【共通武器特性】"))
        check("SET/NEUTRAL no added effects "+id,eligible or desc==str(card.get("text","")))
        if eligible:
            var on: String=WeaponTraitCardDescription.conditional_text(card,1)
            var off: String=WeaponTraitCardDescription.conditional_text(card,0)
            check("ON and OFF visible "+id,on.contains("現在ON") and off.contains("現在OFF"))
            check("gold and dim BBCode "+id,WeaponTraitCardDescription.conditional_bbcode(card,1).contains("#ffe59b") and WeaponTraitCardDescription.conditional_bbcode(card,0).contains("#9297a5"))
            check("no duplicate Katana formal "+id,(not WeaponTraitCardDescription.already_in_master(card)) or (not on.contains("対象HPが最大HP")))
        check("read only card "+id,JSON.stringify(card)==source_snapshot[id])
    check("45 SET",int(counts.get("SET",0))==45)
    check("45 CONSUME",int(counts.get("CONSUME",0))==45)
    check("30 NEUTRAL",int(counts.get("NEUTRAL",0))==30)
    var c100: Dictionary=db.get_card_copy("C100")
    check("C100 precision",WeaponTraitCardDescription.effect_text(c100).contains("Block無視") and WeaponTraitCardDescription.effect_text(c100).contains("脆弱1"))
    check("C100 magic orb preserved",WeaponTraitCardDescription.combined_text(c100).contains("魔珠が3以上"))
    for entry in [{"id":"C001","want":"50%"},{"id":"C005","want":"2Hit"},{"id":"C008","want":"1.5倍"},{"id":"C045","want":"+2"},{"id":"C012","want":"Cost0"}]:
        check("weapon text "+str(entry.id),WeaponTraitCardDescription.effect_text(db.get_card_copy(str(entry.id))).contains(str(entry.want)))
    print("WEAPON TRAIT DESCRIPTION: checked=",checked," PASS=",checked-failures.size()," FAIL=",failures.size())
    quit(0 if failures.is_empty() else 1)
