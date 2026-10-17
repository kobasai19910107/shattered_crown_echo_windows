extends Node
const OUT="user://test_outputs/"
var passed: int=0
var failures: Array=[]
func check(title: String,ok: bool) -> void:
    if ok:passed+=1
    else:failures.append(title);print("FAIL "+title)
func _ready() -> void:call_deferred("run_tests")
func settle() -> void:
    for i in range(10):await get_tree().process_frame
func capture(title: String) -> void:
    if DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    check("GPU "+title,get_tree().root.get_texture().get_image().save_png(OUT+title+".png")==OK)
func fresh(id: String) -> BattleController:
    var c=BattleController.new();c.start_battle(131010,[id,"C001","C004"],"standard_trio")
    c.hand=c.database.create_deck_from_ids([id]);c.current_mana=30
    for enemy in c.enemies:enemy.hp=500;enemy.max_hp=500;enemy.block=7
    return c
func find_button(parent: Node,text: String) -> Button:
    for child in parent.get_children():
        if child is Button and child.text.contains(text):return child
        var found=find_button(child,text)
        if found!=null:return found
    return null
func run_tests() -> void:
    if not (OS.get_environment("APPDATA").contains("step37_runs") or OS.get_environment("SCE_HUB_ISOLATED_TEST")=="1"):get_tree().quit(2);return
    get_tree().root.size=Vector2i(1280,900)
    var main=load("res://main.tscn").instantiate();get_tree().root.add_child(main);await settle()
    var ids: Array=[]
    for id in main.battle.database.official_card_ids:
        if str(main.battle.database.create_card_copy(id).get("condition_trait","")) in ["爆発","鈍化","呪印","猛毒"]:ids.append(id)
    check("23 enemy condition cards",ids.size()==23)
    for id in ids:
        var c=fresh(id);var card: Dictionary=c.hand[0];var trait_name: String=card.condition_trait;var threshold: int=int(card.condition_threshold)
        c.enemies[0].attribute_traits[trait_name]=threshold;c.enemies[1].attribute_traits[trait_name]=threshold-1
        var before: String=JSON.stringify(c.export_region1_state());var rng: int=c.battle_rng.state
        var waiting: Dictionary=BattleCardPreview.inspect(c,0,-1)
        var yes: Dictionary=BattleCardPreview.inspect(c,0,0);var no: Dictionary=BattleCardPreview.inspect(c,0,1)
        check(id+" waiting not asserted",waiting.waiting and waiting.condition_waiting and not waiting.condition)
        check(id+" target-specific condition",yes.condition and not no.condition)
        var player_public: Dictionary={"attribute_traits":c.attribute_traits,"weapon_traits":c.weapon_traits}
        check(id+" coop public condition same",BattleCardPreview.public_condition(card,player_public,c.enemies[0])==bool(yes.condition) and BattleCardPreview.public_condition(card,player_public,c.enemies[1])==bool(no.condition))
        check(id+" preview readonly",JSON.stringify(c.export_region1_state())==before and c.battle_rng.state==rng)
        main.battle=c;main._rebuild_enemy_buttons();main.selected_hand_index=-1;main._refresh_ui()
        var button=main.hand_box.get_child(0)
        check(id+" card waiting label",button.role_label.text.contains("対象待ち") and button.damage_label.text=="?")
        main._on_preview_enemy_enter(0);check(id+" fulfilled star",button.role_label.text.contains("★ 条件成立") and button.body_text.text.contains("[b]"))
        main._on_preview_enemy_exit(0);main._on_preview_enemy_enter(1)
        check(id+" unmet not highlighted",not button.role_label.text.contains("条件成立"))
        main._on_preview_enemy_exit(1)
        check(id+" highlight reset",button.role_label.text.contains("対象待ち"))
        check(id+" formal text intact",button.body_text.get_parsed_text()==str(card.text))
        if bool(yes.available) and not bool(yes.partial):
            var actual=fresh(id);actual.enemies=c.enemies.duplicate(true)
            var hp: int=int(actual.enemies[0].hp);var block: int=actual.player_block
            check(id+" actual use",actual.use_card(0,0))
            check(id+" actual HP Block match",int(yes.damage)==hp-maxi(0,int(actual.enemies[0].hp)) and int(yes.block_delta)==actual.player_block-block and int(yes.mana_after)==actual.current_mana)
    # Forty-five CONSUME cards in ON/OFF; compare actual resolution when fully determined.
    for id in main.battle.database.official_card_ids:
        var definition: Dictionary=main.battle.database.create_card_copy(id)
        if str(definition.weapon_trait_action)!="CONSUME":continue
        for on in [false,true]:
            var c=fresh(id);c.weapon_traits[str(definition.weapon_trait)]=on
            var before: String=JSON.stringify(c.export_region1_state());var prediction: Dictionary=BattleCardPreview.inspect(c,0,0)
            check(id+" ON/OFF readonly "+str(on),before==JSON.stringify(c.export_region1_state()))
            if bool(prediction.available) and not bool(prediction.partial):
                var hp: int=int(c.enemies[0].hp);var block: int=c.player_block
                check(id+" real use "+str(on),c.use_card(0,0))
                check(id+" predicted HP Block Mana "+str(on),int(prediction.damage)==hp-maxi(0,int(c.enemies[0].hp)) and int(prediction.block_delta)==c.player_block-block and int(prediction.mana_after)==c.current_mana)
    var draw=fresh("C044");draw.draw_pile=draw.database.create_deck_from_ids(["C100","C001"])
    var saved: String=JSON.stringify(draw.export_region1_state())
    check("unknown Draw labeled",BattleCardPreview.inspect(draw,0).partial and BattleCardPreview.describe(BattleCardPreview.inspect(draw,0)).contains("未確定"))
    var original_prediction: Dictionary=BattleCardPreview.inspect(draw,0)
    draw.draw_pile.reverse();check("future draw order ignored",original_prediction==BattleCardPreview.inspect(draw,0))
    draw.draw_pile.reverse();check("Draw preview state unchanged",JSON.stringify(draw.export_region1_state())==saved)
    main.battle=fresh("C014");main.battle.enemies[0].attribute_traits["爆発"]=3;main._rebuild_enemy_buttons();main._refresh_ui();main.tab_container.current_tab=0;await settle()
    check("battle tab actually visible",main.hand_box.is_visible_in_tree())
    main._on_card_pressed(0);main._on_preview_enemy_enter(0);await settle();await capture("target_fulfilled")
    main._on_preview_enemy_enter(1);await settle();await capture("target_unmet")
    main._on_preview_enemy_exit(1);main._cancel_selection();await settle();await capture("target_waiting")
    # Existing canonical run state; only the UI changes. Controlled shop fixture.
    var ui: Region1RunUI=main.region_run_ui;ui.run.save_path="user://target_shop_test.json"
    var helper=load("res://tests/hub_inventory_analysis_test.gd").new();var items: Dictionary=helper.make_items(ui.run.roller,517901);helper.free()
    check("adopt fixture",ui.run.adopt_initial(items));check("begin fixture",ui.run.begin(131011))
    var state: Dictionary=ui.run.state.duplicate(true);state.phase="service";state.run.kind="shop";state.run.gold=2000;state.run.hp=1
    state.run.stock=ui.run._offer(state,"shop",ui.run._rng(state.run));check("canonical shop fixture",ui.run._commit(state))
    ui.render();main.tab_container.current_tab=ui.get_index();await settle()
    var tabs: TabContainer=ui.find_child("ShopNPCSections",true,false)
    check("two distinct NPCs",tabs.get_tab_title(0)=="遺品商" and tabs.get_tab_title(1)=="僧侶")
    var snapshot: String=JSON.stringify(ui.run.state);var bytes: String=FileAccess.get_file_as_string(ui.run.save_path)
    tabs.current_tab=1;await settle()
    check("NPC switch readonly",snapshot==JSON.stringify(ui.run.state) and bytes==FileAccess.get_file_as_string(ui.run.save_path))
    await capture("shop_priest")
    find_button(tabs.get_child(1),"35%回復").pressed.emit();await settle()
    check("existing heal cost and quantity",int(ui.run.state.run.gold)==1910 and int(ui.run.state.run.hp)==1+maxi(1,int(float(ui.run.state.run.max_hp)*0.35)))
    tabs=ui.find_child("ShopNPCSections",true,false);check("priest tab retained",tabs.current_tab==1)
    var hp_before: int=int(ui.run.state.run.hp)
    find_button(tabs.get_child(1),"最初のAttack").pressed.emit();await settle()
    check("existing support cost",int(ui.run.state.run.gold)==1850 and ui.run.state.run.support.attack==1 and int(ui.run.state.run.hp)==hp_before)
    tabs=ui.find_child("ShopNPCSections",true,false);check("support purchase disabled",find_button(tabs.get_child(1),"最初のAttack").disabled)
    tabs.current_tab=0;await settle();await capture("shop_merchant")
    find_button(tabs.get_child(0),"280G").pressed.emit();await settle()
    check("existing buy cost inventory",int(ui.run.state.run.gold)==1570 and ui.run.state.run.bag.size()==1 and ui.run.state.run.stock[0].is_empty())
    tabs=ui.find_child("ShopNPCSections",true,false);check("sold out disabled",find_button(tabs.get_child(0),"売り切れ").disabled)
    check("shop reload",ui.run.load_saved());ui.render();await settle()
    check("shop state restored",ui.run.state.phase=="service" and ui.run.state.run.support.attack==1 and ui.run.state.run.bag.size()==1)
    state=ui.run.state.duplicate(true);state.run.gold=0;check("insufficient gold fixture",ui.run._commit(state));ui.render();await settle()
    tabs=ui.find_child("ShopNPCSections",true,false)
    check("merchant poor disabled",find_button(tabs.get_child(0),"商品更新").disabled)
    check("priest poor disabled",find_button(tabs.get_child(1),"全回復").disabled)
    # Cooperative view uses the same commands; no EOS/network state change.
    var coop: CoopLobbyUI=main.coop_ui;coop.session.connected_ok=true;coop.session.hosting=false
    coop.render_service(ui.run.state)
    var coop_tabs: TabContainer=coop.state_box.find_child("ShopNPCSections",true,false)
    check("cooperative NPC separation",coop_tabs!=null and coop_tabs.get_tab_count()==2)
    check("cooperative poor disabled",find_button(coop_tabs.get_child(1),"全回復").disabled and find_button(coop_tabs.get_child(0),"商品更新").disabled)
    check("cooperative public condition true",BattleCardPreview.public_condition(main.battle.hand[0],{},main.battle.enemies[0]))
    check("cooperative public condition false",not BattleCardPreview.public_condition(main.battle.hand[0],{},main.battle.enemies[1]))
    # Host-side cooperative shop UI invokes the unchanged authority/transaction path.
    var party=CoopCampaignController.new();party.save_path="user://target_shop_coop_fixture.json"
    party.identity={"secret":"shop-test-secret","room":"shop-test-room","guest_token":"shop-test-guest","revision":0}
    check("coop member0 fixture",party.initialize_member(0,items));check("coop member1 fixture",party.initialize_member(1,items))
    for member in party.members:
        var member_state: Dictionary=ui.run.state.duplicate(true);member_state.run.gold=2000;member_state.run.hp=1;member_state.run.support={}
        check("coop canonical shop fixture",member._commit(member_state))
    coop.session.close();coop.remove_child(coop.session);coop.session.queue_free()
    coop.session=CoopCodeSession.new();coop.add_child(coop.session)
    coop.session.party=party;coop.session.hosting=true;coop.session.connected_ok=true;coop.session.confirmed=[true,true]
    coop.session.build_hash=CoopSession.fingerprint();coop.session.changed.connect(coop.render);coop.session.publish();main.tab_container.current_tab=coop.get_index();await settle()
    var other_before: String=JSON.stringify(party.members[1].state)
    coop_tabs=coop.find_child("ShopNPCSections",true,false);check("coop actual view NPC tabs",coop_tabs!=null)
    coop_tabs.current_tab=1;await settle()
    find_button(coop_tabs.get_child(1),"35%回復").pressed.emit();await settle()
    check("coop heal authority cost",int(party.members[0].state.run.gold)==1910 and int(party.members[0].state.run.hp)>1)
    coop_tabs=coop.find_child("ShopNPCSections",true,false);check("coop NPC tab retained",coop_tabs.current_tab==1)
    find_button(coop_tabs.get_child(1),"Block4").pressed.emit();await settle()
    check("coop support authority cost",int(party.members[0].state.run.gold)==1850 and int(party.members[0].state.run.support.block)==1)
    coop_tabs=coop.find_child("ShopNPCSections",true,false);coop_tabs.current_tab=0;await settle()
    var bag_count: int=party.members[0].state.run.bag.size()
    find_button(coop_tabs.get_child(0),"280G").pressed.emit();await settle()
    check("coop buy authority cost",int(party.members[0].state.run.gold)==1570 and party.members[0].state.run.bag.size()==bag_count+1)
    check("coop peer economy untouched",other_before==JSON.stringify(party.members[1].state))
    await capture("coop_shop")
    var party_reload=CoopCampaignController.new();party_reload.save_path=party.save_path
    check("coop shop save reload",party_reload.load_saved() and int(party_reload.members[0].state.run.gold)==1570)
    coop.session.close()
    check("existing leave",ui.run.service("leave") and ui.run.state.phase=="route")
    main.queue_free();await settle()
    FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "gpu.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failures":failures},"  "))
    print("TARGET_SHOP: %d PASS / %d FAIL"%[passed,failures.size()]);get_tree().quit(0 if failures.is_empty() else 1)
