extends SceneTree

const OUT="user://test_outputs/"
var passed: int=0
var failures: Array=[]
var images: Array=[]
func check(label: String,ok: bool) -> void:
    if ok:passed+=1
    else:failures.append(label);print("FAIL "+label)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
    for i in range(10):await process_frame
func capture(label: String) -> void:
    if DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image();var path: String=OUT+label+".png"
    check("capture "+label,image!=null and image.save_png(path)==OK);images.append(path)
func fresh(ids: Array) -> BattleController:
    var core=BattleController.new();core.start_battle(772004,ids,"standard_trio")
    core.hand=core.database.create_deck_from_ids(ids);core.current_mana=30;core.draw_pile=core.database.create_deck_from_ids(["C001","C002","C003","C004"])
    for enemy in core.enemies:enemy.hp=500;enemy.max_hp=500;enemy.block=0
    return core
func run() -> void:
    if not (OS.get_environment("APPDATA").contains("step37_runs") or OS.get_environment("SCE_HUB_ISOLATED_TEST")=="1"):quit(2);return
    root.size=Vector2i(1280,900)
    var ui=load("res://main.tscn").instantiate();root.add_child(ui);await settle()
    var icons={"mana":ui._get_ui_icon("mana"),"attack":ui._get_ui_icon("attack"),"block":ui._get_ui_icon("block")}
    var before: String=JSON.stringify(ui.battle.export_region1_state())
    for id in ui.battle.database.official_card_ids:
        var card: Dictionary=ui.battle.database.create_card_copy(id)
        var button=load("res://scripts/playtest_card_button.gd").new()
        button.custom_minimum_size=Vector2(165,230);button.configure(card,int(card.cost),icons,false,false,true);root.add_child(button)
        check(id+" full body",button.body_text.get_parsed_text()==str(card.text))
        check(id+" cost",button.mana_label.text==str(int(card.cost)))
        if int(card.get("base_damage",0))==0 and int(card.get("draw_count",0))>0:
            check(id+" Draw metric",button.draw_label.text==str(int(card.draw_count)))
        check(id+" role",button.role_label.text.contains(str(card.role)))
        button.mark_attribute_condition(true);button.mark_weapon_condition(true)
        check(id+" emphasized text unchanged",button.body_text.get_parsed_text()==str(card.text))
        var detail=button._make_custom_tooltip(str(card.text))
        check(id+" full detail",detail.get_child(0).get_child(1).get_parsed_text()==str(card.text))
        detail.free();button.free()
    check("card render readonly",before==JSON.stringify(ui.battle.export_region1_state()))
    # Actual Core with and without a presentation subscriber must yield the same state/RNG.
    var a=fresh(["C005","C002","C001"]);var b=fresh(["C005","C002","C001"])
    a.weapon_traits["連刃"]=true;b.weapon_traits["連刃"]=true
    a.enemies[0].block=7;b.enemies[0].block=7
    var events: Array=[];a.presentation_event.connect(func(event):events.append(event.duplicate(true)))
    check("multi hit use",a.use_card(0,0) and b.use_card(0,0))
    var hits: Array=events.filter(func(e):return e.kind=="enemy_hit")
    check("real two Hits",hits.size()==2)
    check("Hit block order",hits.size()==2 and int(hits[0].block_loss)==5 and int(hits[0].hp_loss)==0 and int(hits[1].block_loss)==2 and int(hits[1].hp_loss)==3)
    check("notifications do not change state",JSON.stringify(a.export_region1_state())==JSON.stringify(b.export_region1_state()))
    check("notifications do not change RNG",a.battle_rng.state==b.battle_rng.state)
    events.clear();a.player_block=7;a._take_player_damage(5);a._take_player_damage(5)
    hits=events.filter(func(e):return e.kind=="player_hit")
    check("player absorbed order",hits.size()==2 and hits[0].block_loss==5 and hits[0].hp_loss==0 and hits[1].block_loss==2 and hits[1].hp_loss==3)
    events.clear();a.hand.clear();a.draw_cards(2)
    var draws=events.filter(func(e):return e.kind=="draw")
    check("Draw IDs are actual cards",draws.size()==2 and str(draws[0].id)==str(a.hand[0].id) and str(draws[1].id)==str(a.hand[1].id))
    events.clear();a.finish_player_turn_effects()
    check("real discard events",events.filter(func(e):return e.kind=="discard").size()==2)
    # Each attribute uses an actual official Attack, not an invented card.
    for id in ["C001","C013","C026","C039","C050","C063","C073","C085","C100","C113"]:
        var core=fresh([id]);events.clear();core.presentation_event.connect(func(event):events.append(event.duplicate(true)))
        check(id+" real attribute use",core.use_card(0,0))
        hits=events.filter(func(e):return e.kind=="enemy_hit")
        check(id+" attribute identity",not hits.is_empty() and str(hits[0].attribute)==str(core.database.create_card_copy(id).attribute))
        ui.battle_presentation.glyph(str(core.database.create_card_copy(id).attribute),Vector2(400+(int(id.substr(1))%5)*120,190+(int(id.substr(1))%2)*85))
    await process_frame;await capture("attributes")
    # SET/CONSUME and ON/OFF use the adopted Core rules, including Iai.
    for pair in [["C002","C001","流転"],["C039","C003","精密"],["C006","C005","連刃"],["C007","C008","重撃"],["C011","C012","納刀"],["C022","C045","魔導"]]:
        var core=fresh([pair[0],pair[1]])
        check(str(pair[2])+" SET use",core.use_card(0,0))
        while core.is_hand_selection_active():core.select_hand_for_pending(1 if core.hand.size()>1 else 0)
        check(str(pair[2])+" ON",bool(core.weapon_traits[pair[2]]))
        events.clear();core.presentation_event.connect(func(event):events.append(event.duplicate(true)))
        var index: int=-1
        for i in range(core.hand.size()):
            if str(core.hand[i].id)==str(pair[1]):index=i
        check(str(pair[2])+" CONSUME use",index>=0 and core.use_card(index,0))
        check(str(pair[2])+" confirmed consumption",events.any(func(e):return e.kind=="log" and str(e.message).contains(str(pair[2])+"ON consumed")))
    var core=fresh(["C084"]);core.weapon_traits["納刀"]=true;core.enemies[0].hp=55
    events.clear();core.presentation_event.connect(func(event):events.append(event.duplicate(true)))
    check("execution use",core.use_card(0,0))
    check("execution confirmed",int(core.enemies[0].hp)==0 and events.any(func(e):return e.kind=="log" and str(e.message).begins_with("処刑:")))
    core=fresh(["C097"]);core.attribute_traits["魔珠"]=1;events.clear()
    core.presentation_event.connect(func(event):events.append(event.duplicate(true)))
    check("Mana threshold card",core.use_card(0,-1))
    check("Mana gain confirmed",events.any(func(e):return e.kind=="resource" and e.resource=="mana_gained" and int(e.amount)==1))
    check("threshold 3 actual",int(core.attribute_traits["魔珠"])==3)
    core=fresh(["C044","C001"]);events.clear();core.presentation_event.connect(func(event):events.append(event.duplicate(true)))
    check("Bottom card",core.use_card(0,-1))
    var bottom_id: String=str(core.hand[0].id)
    check("Bottom selection",core.select_hand_for_pending(0))
    check("Bottom actual destination",str(core.draw_pile[0].id)==bottom_id and events.any(func(e):return e.kind=="bottom" and str(e.id)==bottom_id))
    # Main scene layout and input use the real existing callbacks.
    ui.battle.start_battle(772004,[],"standard_trio")
    ui.battle.hand=ui.battle.database.create_deck_from_ids(["C001","C002","C006","C044","C083","C084","C015","C098","C109","C120"])
    ui.tab_container.current_tab=0;ui._refresh_ui();await settle()
    check("ten actual cards",ui.hand_box.get_child_count()==10)
    check("five readable columns",ui.hand_box.columns==5 and ui.hand_box.get_child(0).size.x>=145)
    check("vertical cards",ui.hand_box.get_child(0).size.y>ui.hand_box.get_child(0).size.x)
    check("end turn inside window",ui.end_turn_button.get_global_rect().end.y<=900)
    check("auto inside window",ui.auto_battle_button.get_global_rect().end.y<=900)
    var scroll=ui.hand_box.get_parent()
    check("internal hand scroll",scroll is ScrollContainer and scroll.get_v_scroll_bar().max_value>scroll.size.y)
    await capture("hand10")
    scroll.scroll_vertical=240;await settle();await capture("hand10_bottom")
    check("second row accessible",ui.hand_box.get_child(9).get_global_rect().intersects(scroll.get_global_rect()))
    scroll.scroll_vertical=0
    before=JSON.stringify(ui.battle.export_region1_state());ui.hand_box.get_child(0).show_detail();await settle()
    check("detail readonly",before==JSON.stringify(ui.battle.export_region1_state()))
    check("detail visible",ui.hand_box.get_child(0).detail_popup.visible);await capture("card_detail")
    ui.hand_box.get_child(0).detail_popup.hide()
    ui._on_card_pressed(0);check("selection",ui.selected_hand_index==0)
    ui._cancel_selection();check("cancel readonly",ui.selected_hand_index==-1 and before==JSON.stringify(ui.battle.export_region1_state()))
    ui.battle.hand=ui.battle.database.create_deck_from_ids(["C005"]);ui.battle.weapon_traits["連刃"]=true;ui.battle.enemies[0].block=7
    ui._refresh_ui();await settle();ui._on_card_pressed(0);ui._on_enemy_pressed(0)
    check("main captures real Hits",ui.battle_presentation.last_events.filter(func(e):return e.kind=="enemy_hit").size()==2)
    await process_frame;await capture("multi_hit")
    await create_timer(1.3).timeout
    check("VFX resources released",ui.battle_presentation.get_child_count()==0 and ui.battle_presentation.timeline.is_empty() and ui.battle_presentation.flashed.is_empty())
    for quality in [0,1,2]:
        BattlePresentation.quality=quality;ui.battle_presentation.glyph("炎",Vector2(500,250))
        check("VFX mode "+str(quality),ui.battle_presentation.get_child_count()==(0 if quality==0 else 1))
        ui.battle_presentation.clear_effects();await process_frame
        check("skip cleanup "+str(quality),ui.battle_presentation.get_child_count()==0)
    BattlePresentation.quality=2
    for i in range(300):ui.battle_presentation.glyph("炎",Vector2(450,190))
    check("burst bounded",ui.battle_presentation.get_child_count()<=41)
    ui.battle_presentation.clear_effects();await process_frame
    check("burst cleanup",ui.battle_presentation.get_child_count()==0)
    # Stress the same enemy layout used for summons, without claiming natural summon balance.
    for count in [1,3,15]:
        var enemy: Dictionary=ui.battle.enemies[0].duplicate(true);ui.battle.enemies.clear()
        for i in range(count):ui.battle.enemies.append(enemy.duplicate(true))
        ui._refresh_ui();await settle()
        check("enemies "+str(count),ui.enemy_buttons.size()==count and ui.end_turn_button.get_global_rect().end.y<=900)
    await capture("summoned15")
    ui.battle.start_battle(772004,[],"standard_trio")
    ui.battle.hand=ui.battle.database.create_deck_from_ids(["C062"]);ui.battle.player_hp=20;ui.battle.attribute_traits["恩寵"]=3
    ui._refresh_ui();await settle();ui._on_card_pressed(0);ui._on_use_pressed()
    check("real conditional heal",ui.battle.player_hp==22 and ui.battle.player_block==4)
    check("heal notification actual",ui.battle_presentation.last_events.any(func(e):return e.kind=="resource" and e.resource=="healing_done" and e.amount==2))
    before=JSON.stringify(ui.battle.export_region1_state());await settle()
    check("green heal VFX",ui.battle_presentation.get_children().any(func(node):return node is BattleVFXGlyph and node.attribute=="光" and node.modulate.g>node.modulate.r and node.modulate.g>node.modulate.b))
    check("animation readonly",before==JSON.stringify(ui.battle.export_region1_state()))
    await capture("healing");await create_timer(1.2).timeout
    # Real victory and defeat, followed by bounded visual cleanup.
    check("actual Region monsters",ui.battle.start_region1(772004,[],["R1-N01","R1-N04","R1-N07"],{},48))
    ui.battle.hand=ui.battle.database.create_deck_from_ids(["C001","C002","C006","C044","C083","C084","C015","C098","C109","C120"])
    ui._refresh_ui();await settle();await capture("region1_battle")
    ui.battle.hand=ui.battle.database.create_deck_from_ids(["C001"])
    for enemy in ui.battle.enemies:enemy.hp=0
    ui.battle.enemies[0].hp=1;ui._refresh_ui();ui._on_card_pressed(0);ui._on_enemy_pressed(0);await settle()
    check("real victory",ui.battle.combat_over and ui.battle.victory)
    check("victory controls visible",ui.auto_battle_button.get_global_rect().end.y<=900 and ui.auto_battle_button.get_global_rect().end.x<=1280)
    await capture("victory");await create_timer(1.5).timeout
    check("victory cleanup",ui.battle_presentation.get_child_count()==0 and ui.battle_presentation.timeline.is_empty())
    ui.battle.start_battle(772004,[],"standard_trio");ui.battle.player_hp=1;ui._refresh_ui();ui._on_end_turn_pressed();await settle()
    check("real defeat",ui.battle.combat_over and not ui.battle.victory)
    await capture("defeat");await create_timer(2.0).timeout
    check("defeat cleanup",ui.battle_presentation.get_child_count()==0 and ui.battle_presentation.timeline.is_empty())
    # Confirmed cooperative snapshots use the existing party controller and unchanged commands.
    var items: Dictionary={}
    for package in JSON.parse_string(FileAccess.get_file_as_string(OUT+"../region1_ranked_packages.json")).packages:
        if str(package.label)=="KATANA/R":items=package.items.duplicate(true)
    var party=CoopCampaignController.new();party.save_path="user://phase_e_coop.json"
    check("coop members",party.initialize_member(0,items) and party.initialize_member(1,items))
    check("coop begin",party.apply(0,{"op":"propose","kind":"begin","value":978123}) and party.apply(1,{"op":"confirm"}))
    check("coop battle",party.apply(0,{"op":"propose","kind":"route","value":0}) and party.apply(1,{"op":"confirm"}))
    var coop=ui.coop_ui;coop.session.party=party;coop.session.hosting=true;coop.session.connected_ok=true;coop.session.confirmed=[true,true];coop.session.publish()
    ui.tab_container.current_tab=coop.get_index();await settle()
    before=JSON.stringify(party.export_state());coop.render();await settle()
    check("coop UI readonly",before==JSON.stringify(party.export_state()))
    var player=party.combat.players[0];var chosen: int=-1
    for i in range(player.hand.size()):
        if player.can_use_card(i):chosen=i;break
    check("coop actual use",chosen>=0 and party.apply(0,{"op":"combat","action":{"kind":"card","index":chosen,"id":str(player.hand[chosen].id),"target":0}}))
    coop.session.publish();await settle()
    check("coop confirmed VFX",coop.presentation.active_popups>0)
    check("coop no invented Hits",coop.presentation.last_events.is_empty())
    check("coop popup visible",coop.presentation.get_children().any(func(node):return node is Label and node.get_global_rect().intersects(Rect2(Vector2.ZERO,Vector2(1280,900)))))
    await capture("coop_confirmed");await create_timer(1.2).timeout
    check("coop cleanup",coop.presentation.get_child_count()==0)
    ui.battle_presentation.clear_effects();ui.free();await settle()
    var result={"pass":passed,"fail":failures.size(),"failures":failures,"images":images}
    var file=FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "gpu.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(result,"  "))
    print("PHASE_E PASS=%d FAIL=%d"%[passed,failures.size()]);quit(0 if failures.is_empty() else 1)
