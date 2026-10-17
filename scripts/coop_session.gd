class_name CoopSession
extends Node

signal changed
const PROTOCOL=1
const MAX_PACKET=262144
const IDENTITY_SAVE="user://coop_guest_identity_v1.json"
var peer: MultiplayerPeer=null
var hosting: bool=false
var connected_ok: bool=false
var seat: int=0
var remote: int=0
var revision: int=0
var request: int=0
var last_request: int=0
var status: String="未接続"
var view: Dictionary={}
var party: CoopCampaignController=null
var auto_flags: Array=[false,false]
var confirmed: Array=[false,false]
var auto_next: int=0
var connect_deadline: int=0
var hello_sent: bool=false
var hello: Dictionary={}
var build_hash: String=""
var player_names: Array=["ホスト","参加者"]

static func clean_player_name(value: String,fallback: String) -> String:
    var cleaned=value.replace("\n"," ").replace("\r"," ").replace("\t"," ").strip_edges().substr(0,20)
    return fallback if cleaned=="" else cleaned

static func fingerprint() -> String:
    var names: PackedStringArray=DirAccess.get_files_at("res://scripts")
    names.sort()
    var text: String="sce-independent-coop-v1\n"
    for file in names:
        if file.ends_with(".gd"): text+=file+"|"+FileAccess.get_file_as_string("res://scripts/"+file).sha256_text()+"\n"
    var data: PackedStringArray=DirAccess.get_files_at("res://data")
    data.sort()
    for file in data:
        if file.ends_with(".json"): text+=file+"|"+FileAccess.get_file_as_string("res://data/"+file).sha256_text()+"\n"
    return text.sha256_text()

func random_key() -> String:
    return Crypto.new().generate_random_bytes(16).hex_encode()

func close() -> void:
    if peer!=null: peer.close()
    peer=null; connected_ok=false; remote=0; hello_sent=false; auto_flags=[false,false]; confirmed=[false,false]
    if party!=null and party.combat!=null: party.combat.dispose()
    party=null

func _exit_tree() -> void: close()

func host_room(items: Dictionary,port: int=28740,bind_ip: String="*") -> bool:
    close()
    if port<1024 or port>65535: status="ポートは1024〜65535です。"; changed.emit(); return false
    party=CoopCampaignController.new()
    if FileAccess.file_exists(party.save_path):
        if not party.load_saved() or not party.identity.has("secret"):
            status="協力用保存が不正です。原本を保持しました。"; changed.emit(); return false
    else:
        party.identity={"secret":random_key().substr(0,16),"room":random_key(),"guest_token":"","revision":0}
        if not party.initialize_member(0,items): status="合法な6装備、または書込み可能な保存先が必要です。"; changed.emit(); return false
    revision=int(party.identity.get("revision",0))
    peer=ENetMultiplayerPeer.new(); peer.set_bind_ip(bind_ip)
    if peer.create_server(port,1)!=OK:
        peer=null; status="部屋を作成できません。ポートが使用中か確認してください。"; changed.emit(); return false
    hosting=true; seat=0; build_hash=fingerprint(); last_request=0
    peer.peer_disconnected.connect(disconnected)
    status="参加待ち — UDP %d / 参加コード %s"%[port,str(party.identity.secret)]
    publish()
    return true

func join_room(address: String,port: int,code: String,items: Dictionary) -> bool:
    close()
    revision=0; view={}
    if address.strip_edges()=="" or port<1024 or port>65535 or code.strip_edges()=="": return false
    if not CoopCampaignController.valid_items(items): status="参加には合法な6装備が必要です。"; changed.emit(); return false
    var identity: Dictionary=Region1Save.read(IDENTITY_SAVE)
    hello={"kind":"hello","code":code.strip_edges(),"token":str(identity.get("token","")),"items":items.duplicate(true)}
    peer=ENetMultiplayerPeer.new()
    if peer.create_client(address.strip_edges(),port)!=OK:
        peer=null; status="接続を開始できません。"; changed.emit(); return false
    hosting=false; seat=1; build_hash=fingerprint(); request=0
    peer.peer_disconnected.connect(disconnected)
    connect_deadline=Time.get_ticks_msec()+15000
    status="ホストへ接続中…"; changed.emit()
    return true

func disconnected(_id: int) -> void:
    connected_ok=false; remote=0; auto_flags=[false,false]; confirmed=[false,false]
    status="切断されました。協力戦闘とAIは停止中です。同じ参加者で部屋に再接続してください。"
    changed.emit()

func send(target: int,payload: Dictionary) -> bool:
    if peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return false
    payload=payload.duplicate(true)
    payload["protocol"]=PROTOCOL; payload["build"]=build_hash
    var bytes: PackedByteArray=JSON.stringify(payload).to_utf8_buffer()
    if bytes.size()>MAX_PACKET: return false
    peer.set_target_peer(target); peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
    return peer.put_packet(bytes)==OK

func command(cmd: Dictionary) -> bool:
    if not connected_ok: return false
    if hosting: return execute_command(0,cmd)
    request+=1
    return send(1,{"kind":"command","request":request,"revision":revision,"cmd":cmd})

func valid_command(cmd: Dictionary) -> bool:
    var op: String=str(cmd.get("op",""))
    if op not in ["ready","propose","cancel_proposal","confirm","combat","reward","defeat","service","equip","forge","forge_select","retreat","auto"]: return false
    for key in ["value","index","slot"]:
        if cmd.has(key) and not (cmd[key] is int or cmd[key] is float): return false
    for key in ["kind","action","uid"]:
        if key=="action" and op=="combat": continue
        if cmd.has(key) and (not cmd[key] is String or str(cmd[key]).length()>256): return false
    if op=="auto": return cmd.get("enabled") is bool
    if op=="defeat":
        if not cmd.get("indices") is Array or cmd.indices.size()>4: return false
        for value in cmd.indices:
            if not (value is int or value is float): return false
    if op=="combat":
        if not cmd.get("action") is Dictionary: return false
        var a: Dictionary=cmd.action
        if str(a.get("kind","")) not in ["card","select","salvage","end"]: return false
        if not a.get("id","") is String or str(a.get("id","")).length()>64: return false
        if str(a.kind)!="end":
            if not a.has("id") or str(a.id)=="" or not a.has("index"): return false
            if str(a.kind)=="card" and not a.has("target"): return false
        for key in ["index","target"]:
            if a.has(key) and not (a[key] is int or a[key] is float): return false
    return true

func execute_command(sender_seat: int,cmd: Dictionary) -> bool:
    if not hosting or not connected_ok or not valid_command(cmd): return false
    if str(cmd.op)=="ready" and bool(confirmed[sender_seat]):
        publish();return true
    if str(cmd.op)!="ready" and not confirmed.all(func(v):return bool(v)): return false
    var before: Dictionary=party.export_state()
    party.identity["revision"]=revision+1
    var ok: bool=false
    if str(cmd.op) in ["auto","ready"]:
        ok=Region1Save.write(party.save_path,party.export_state())
        if ok:
            if str(cmd.op)=="auto": auto_flags[sender_seat]=bool(cmd.enabled)
            else: confirmed[sender_seat]=true
    else: ok=party.apply(sender_seat,cmd)
    if ok:
        revision+=1
        status="接続中 — P1 / P2"
    else:
        party.import_state(before)
        status="操作を拒否しました。操作番・Mana・選択・保存状態を確認してください。"
    publish()
    return ok

func publish() -> void:
    if party==null: return
    view=party.public_view(0)
    view["revision"]=revision; view["auto"]=auto_flags.duplicate(); view["confirmed"]=confirmed.duplicate(); view["player_names"]=player_names.duplicate()
    changed.emit()
    if remote>1 and connected_ok:
        var other: Dictionary=party.public_view(1)
        other["revision"]=revision; other["auto"]=auto_flags.duplicate(); other["confirmed"]=confirmed.duplicate(); other["player_names"]=player_names.duplicate()
        if not send(remote,{"kind":"state","view":other,"status":status}):
            connected_ok=false; auto_flags=[false,false]; confirmed=[false,false]
            status="状態を送信できません。協力処理を停止し、確定保存を保持しました。再接続してください。"
            changed.emit()

func receive(sender: int,data: Dictionary) -> void:
    if not (data.get("protocol") is int or data.get("protocol") is float) or not data.get("build") is String: return
    if int(data.get("protocol",0))!=PROTOCOL or str(data.get("build",""))!=build_hash:
        if hosting: send(sender,{"kind":"reject","reason":"ゲーム/正式データ版が一致しません。"})
        else: status="ゲーム/正式データ版が一致しません。"; connected_ok=false; changed.emit()
        return
    var kind: String=str(data.get("kind",""))
    if hosting:
        if kind=="hello" and not connected_ok:
            if str(data.get("code",""))!=str(party.identity.secret):
                send(sender,{"kind":"reject","reason":"参加コードが一致しません。"}); return
            if initialized_guest():
                if str(data.get("token",""))=="" or str(data.get("token",""))!=str(party.identity.guest_token):
                    send(sender,{"kind":"reject","reason":"この協力保存は元の参加者だけが再開できます。"}); return
            else:
                if not data.get("items") is Dictionary: return
                var old_token: String=str(party.identity.guest_token)
                party.identity.guest_token=random_key()
                if not party.initialize_member(1,data.items):
                    party.identity.guest_token=old_token
                    send(sender,{"kind":"reject","reason":"装備/協力用保存を検証できません。"}); return
            player_names[1]=clean_player_name(str(data.get("nickname","")),"参加者")
            remote=sender; last_request=0; connected_ok=true
            send(sender,{"kind":"accepted","token":party.identity.guest_token,"room":party.identity.room})
            status="接続中 — P1 / P2"; publish()
        elif kind=="command" and connected_ok and sender==remote:
            if not (data.get("request") is int or data.get("request") is float) or not (data.get("revision") is int or data.get("revision") is float): return
            var number: int=int(data.request)
            var simultaneous_ready: bool=data.get("cmd") is Dictionary and str(data.cmd.get("op",""))=="ready" and int(data.revision)<=revision
            if number<=last_request or (int(data.revision)!=revision and not simultaneous_ready):
                status="重複/古い操作要求を拒否しました。"; publish(); return
            last_request=number
            if data.get("cmd") is Dictionary: execute_command(1,data.cmd)
    elif sender==1:
        if kind=="accepted":
            if not data.get("token") is String: return
            if not Region1Save.write(IDENTITY_SAVE,{"token":data.token,"room":str(data.get("room",""))}):
                status="再参加情報を保存できません。接続を終了します。"; close(); changed.emit(); return
            connected_ok=true; status="接続中 — P1 / P2"; changed.emit()
        elif kind=="state" and connected_ok and data.get("view") is Dictionary:
            var incoming: Dictionary=data.view
            if int(incoming.get("revision",-1))<revision: return
            view=incoming.duplicate(true); revision=int(view.revision)
            status=str(data.get("status","接続中")); changed.emit()
        elif kind=="reject":
            status=str(data.get("reason","参加を拒否されました。"))
            close(); changed.emit()

func initialized_guest() -> bool:
    return party!=null and bool(party.initialized[1])

func _process(_delta: float) -> void:
    if peer==null: return
    peer.poll()
    if not hosting and not hello_sent and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
        hello_sent=true; send(1,hello)
    var packets: int=0
    while peer!=null and peer.get_available_packet_count()>0 and packets<32:
        var sender: int=peer.get_packet_peer()
        var bytes: PackedByteArray=peer.get_packet()
        packets+=1
        if bytes.size()>MAX_PACKET: continue
        var data=JSON.parse_string(bytes.get_string_from_utf8())
        if data is Dictionary: receive(sender,data)
    if not hosting and not connected_ok and Time.get_ticks_msec()>connect_deadline:
        status="接続がタイムアウトしました。IP/UDPポートとホストの部屋を確認してください。"
        close(); changed.emit()
    process_auto()

func process_auto() -> void:
    if hosting and connected_ok and confirmed.all(func(v):return bool(v)) and party.combat!=null and party.phase()=="battle" and Time.get_ticks_msec()>=auto_next:
        var active_seat: int=party.combat.active
        if bool(auto_flags[active_seat]):
            var policy=AutoBattlePolicy.new()
            var action: Dictionary=policy.choose(party.combat.players[active_seat])
            if action.is_empty() or not execute_command(active_seat,{"op":"combat","action":action}): auto_flags[active_seat]=false; publish()
            auto_next=Time.get_ticks_msec()+180

