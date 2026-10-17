extends SceneTree

# UI-only fixture. Does not open a network connection or read/write player saves.
var passes: int=0
var failures: Array=[]

func check(label: String,ok: bool) -> void:
    if ok:passes+=1
    else:failures.append(label);print("FAIL "+label)

func _initialize() -> void:
    call_deferred("run_tests")

func make_member() -> Dictionary:
    var inventory: Dictionary={}
    var loadout: Dictionary={}
    for slot in Region1RunController.SLOTS:
        var uid: String="test_"+slot
        inventory[uid]={"slot":slot,"rarity":"Rare","cards":["C001","C002","C003","C004"]}
        loadout[slot]=uid
    return {"inventory":inventory,"loadout":loadout,"region_progress":[0,0,0,0,0,0],"active_region":0,"forge_pending":{},"phase":"hub"}

func run_tests() -> void:
    if OS.get_environment("SCE_HUB_ISOLATED_TEST")!="1":
        printerr("Only run with isolated APPDATA and SCE_HUB_ISOLATED_TEST=1")
        quit(2)
        return
    root.size=Vector2i(1280,900)
    var ui=CoopLobbyUI.new()
    ui.content=VBoxContainer.new()
    ui.content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    ui.add_child(ui.content)
    ui.state_box=VBoxContainer.new()
    ui.content.add_child(ui.state_box)
    ui.seed=SpinBox.new()
    ui.content.add_child(ui.seed)
    var transport=CoopCodeSession.new()
    ui.session=transport
    ui.add_child(transport)
    root.add_child(ui)
    transport.connected_ok=true
    var view: Dictionary={"phase":"hub","player_names":["Host","Guest"],"members":[make_member(),make_member()],"proposal":{}}
    ui._cooperation_ready_panel(view,0,[false,false])
    check("P1 member card exists",ui.find_child("CoopPlayerCardP1",true,false)!=null)
    check("P2 member card exists",ui.find_child("CoopPlayerCardP2",true,false)!=null)
    check("ready button before confirmed",ui.find_child("CoopReadyButton",true,false)!=null)
    check("equipment details collapsed by default",ui.find_child("CoopPlayerDetailsToggle",true,false)!=null and not ui.coop_player_details_open)
    var waiting=VBoxContainer.new()
    ui.state_box=waiting
    ui.content.add_child(waiting)
    ui._cooperation_departure_waiting(false,[false,false])
    var waiting_launch=waiting.find_child("CoopLaunchWaitingButton",true,false)
    check("departure area visible while waiting for P2",waiting.find_child("CoopDeparturePanel",true,false)!=null)
    check("departure blocked while waiting for P2",waiting_launch!=null and waiting_launch.disabled)
    ui._cooperation_departure_panel(view,0,view.members[0])
    check("host region selection",ui.find_child("CoopRegionSelector",true,false)!=null)
    check("host launch request",ui.find_child("CoopLaunchProposalButton",true,false)!=null)
    check("host no premature guest confirmation",ui.find_child("CoopConfirmProposalButton",true,false)==null)
    var guest=VBoxContainer.new()
    ui.state_box=guest
    ui.content.add_child(guest)
    view.proposal={"kind":"begin","value":456789}
    ui._cooperation_departure_panel(view,1,view.members[1])
    check("guest confirms launch",guest.find_child("CoopConfirmProposalButton",true,false)!=null)
    check("guest cannot launch",guest.find_child("CoopLaunchProposalButton",true,false)==null)
    var gear=VBoxContainer.new()
    ui.state_box=gear
    ui.content.add_child(gear)
    ui._cooperation_management(view.members[0])
    check("management hidden by default",gear.find_child("CoopManageToggle",true,false)!=null and gear.get_child_count()==1)
    # Regression: after the EOS host opens a room, party.phase() is "lobby"
    # until the guest's inventory has been registered. Section 03 must persist.
    var host_ui=CoopLobbyUI.new()
    host_ui.content=VBoxContainer.new()
    host_ui.content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    host_ui.add_child(host_ui.content)
    host_ui.state_box=VBoxContainer.new()
    host_ui.content.add_child(host_ui.state_box)
    host_ui.status_label=Label.new()
    host_ui.content.add_child(host_ui.status_label)
    host_ui.seed=SpinBox.new()
    host_ui.content.add_child(host_ui.seed)
    host_ui.presentation=BattlePresentation.new()
    host_ui.add_child(host_ui.presentation)
    var host_session=CoopCodeSession.new()
    host_ui.session=host_session
    host_ui.add_child(host_session)
    root.add_child(host_ui)
    host_session.hosting=true
    host_session.room_code="ABC123"
    host_session.status="EOS参加待ち — コード ABC123"
    host_session.connected_ok=false
    host_session.view={"phase":"lobby","seat":0,"player_names":["ホスト","参加者"],"members":[make_member(),{}],"confirmed":[false,false],"proposal":{}}
    host_ui.render()
    check("host room / lobby phase retains departure section 03",host_ui.find_child("CoopDeparturePanel",true,false)!=null)
    var host_wait=host_ui.find_child("CoopLaunchWaitingButton",true,false)
    check("host room / lobby phase keeps launch disabled",host_wait!=null and host_wait.disabled)
    var host_copy=host_ui.find_child("CoopCopyRoomCodeButton",true,false)
    check("host room / lobby phase keeps room code copy",host_copy!=null)
    ui.queue_free()
    host_ui.queue_free()
    await process_frame
    print("COOP_LOBBY_UI PASS=%d FAIL=%d"%[passes,failures.size()])
    quit(0 if failures.is_empty() else 1)
