class_name CoopCodeSession
extends CoopSession

var socket: WebSocketPeer=null
var room_code: String=""
var registration: Dictionary={}
var registration_sent: bool=false
var relay_registered: bool=false
const GUEST_PROGRESS_SAVE="user://coop_guest_progress_v1.json"

static func configured_url() -> String:
    var config=ConfigFile.new()
    if config.load("res://online_relay.cfg")!=OK:return ""
    return str(config.get_value("relay","url",""))

static func normalize_code(code: String) -> String:
    return code.strip_edges().to_upper().replace("-","").replace(" ","")

static func valid_code(code: String) -> bool:
    var cleaned=normalize_code(code)
    if cleaned.length() not in [6,8]:return false
    for character in cleaned:
        if not "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains(character):return false
    return true

static func valid_url(url: String) -> bool:
    if url.begins_with("wss://") and url.length()>6:return true
    # Plaintext is only available for isolated local test servers.
    return url.begins_with("ws://127.0.0.1:") or url.begins_with("ws://localhost:") or url.begins_with("ws://[::1]:")

func close() -> void:
    if socket!=null:socket.close()
    socket=null;registration={};registration_sent=false;relay_registered=false;room_code=""
    super.close()

func open_relay(url: String) -> bool:
    if url=="":
        status="オンライン接続の準備中です。公開サーバー設定後に利用できます。";changed.emit();return false
    if not valid_url(url):
        status="オンライン接続の設定が不正です。";changed.emit();return false
    socket=WebSocketPeer.new()
    socket.inbound_buffer_size=MAX_PACKET*4;socket.outbound_buffer_size=MAX_PACKET*4;socket.max_queued_packets=32;socket.heartbeat_interval=15
    if socket.connect_to_url(url)!=OK:
        socket=null;status="オンライン接続を開始できません。";changed.emit();return false
    connect_deadline=Time.get_ticks_msec()+20000
    status="オンラインへ接続中…";changed.emit()
    return true

func host_code(items: Dictionary,url: String="",nickname: String="") -> bool:
    close();hosting=true;seat=0;view={}
    player_names=[clean_player_name(nickname,"ホスト"),"参加者"]
    var endpoint=url if url!="" else configured_url()
    if endpoint=="" or not valid_url(endpoint):return open_relay(endpoint)
    party=CoopCampaignController.new()
    if FileAccess.file_exists(party.save_path):
        if not party.load_saved() or not party.identity.has("secret"):
            status="協力用保存が不正です。原本を保持しました。";changed.emit();return false
    else:
        party.identity={"secret":random_key().substr(0,16),"room":random_key(),"guest_token":"","revision":0}
        if not party.initialize_member(0,items):
            status="拠点の6装備、または協力用保存を確認してください。";changed.emit();return false
    revision=int(party.identity.get("revision",0));last_request=0;build_hash=fingerprint()
    registration={"op":"host","build":build_hash,"key":(str(party.identity.room)+str(party.identity.secret)).sha256_text(),"previous_code":str(party.identity.get("relay_code",""))}
    return open_relay(endpoint)

func join_code(code: String,items: Dictionary,url: String="",nickname: String="") -> bool:
    close();hosting=false;seat=1;revision=0;view={};request=0
    if not valid_code(code):status="参加コードは6文字です。コードを確認してください。";changed.emit();return false
    if not CoopCampaignController.valid_items(items):status="参加には拠点の6装備が必要です。";changed.emit();return false
    room_code=normalize_code(code)
    build_hash=fingerprint()
    registration={"op":"join","code":room_code,"build":build_hash}
    var identity=Region1Save.read(IDENTITY_SAVE)
    hello={"kind":"hello","code":room_code,"token":str(identity.get("token","")),"items":items.duplicate(true),"nickname":clean_player_name(nickname,"参加者")}
    return open_relay(url if url!="" else configured_url())

func save_guest_progress(incoming: Dictionary) -> bool:
    var identity=Region1Save.read(IDENTITY_SAVE)
    var members=incoming.get("members",[])
    if str(identity.get("room",""))=="" or not members is Array or members.size()!=2 or not members[1] is Dictionary:return false
    var receipt={"schema":1,"room":str(identity.room),"revision":int(incoming.get("revision",-1)),"member":members[1].duplicate(true)}
    if receipt.revision<0:return false
    var previous=Region1Save.read(GUEST_PROGRESS_SAVE)
    if str(previous.get("room",""))==receipt.room and int(previous.get("revision",-1))>=receipt.revision:return true
    # Store a confirmed snapshot; repeated messages never add rewards a second time.
    return Region1Save.write(GUEST_PROGRESS_SAVE,receipt)

func receive(sender: int,data: Dictionary) -> void:
    if not hosting and sender==1 and connected_ok and str(data.get("kind",""))=="state" and data.get("view") is Dictionary and str(data.get("build",""))==build_hash and int(data.get("protocol",0))==PROTOCOL:
        if int(data.view.get("revision",-1))>=revision and not save_guest_progress(data.view):
            pause_relay("協力の受取記録を保存できません。停止しました。ホストの確定保存は保持しています。");return
    super.receive(sender,data)

func send(_target: int,payload: Dictionary) -> bool:
    if socket==null or socket.get_ready_state()!=WebSocketPeer.STATE_OPEN or not relay_registered:return false
    payload=payload.duplicate(true);payload["protocol"]=PROTOCOL;payload["build"]=build_hash
    if JSON.stringify(payload).to_utf8_buffer().size()>MAX_PACKET:return false
    return socket.send_text(JSON.stringify({"op":"data","payload":payload}))==OK

func pause_relay(message: String) -> void:
    connected_ok=false;remote=0;auto_flags=[false,false];confirmed=[false,false]
    if socket!=null:socket.close()
    socket=null;relay_registered=false
    status=message;changed.emit()

func relay_message(data: Dictionary) -> void:
    match str(data.get("event","")):
        "created":
            if not hosting or party==null or not valid_code(str(data.get("code",""))):return
            var old=party.export_state()
            room_code=normalize_code(str(data.code));party.identity["relay_code"]=room_code
            if not party.commit_or_restore(old):
                pause_relay("部屋情報を保存できません。元の協力保存を保持しました。");return
            relay_registered=true
            status="参加待ち — コード "+room_code
            publish()
        "joined":
            if hosting:return
            relay_registered=true
            status="ホストを確認中…";changed.emit()
            if not send(1,hello):pause_relay("ホストへ接続できません。もう一度参加してください。")
        "peer_joined":
            if not hosting:return
            remote=2;last_request=0;connected_ok=false;auto_flags=[false,false];confirmed=[false,false]
        "peer_left":
            disconnected(2 if hosting else 1)
            if not hosting:
                pause_relay("ホストが切断しました。戦闘を停止しています。同じコードで再接続してください。")
        "data":
            if not data.get("payload") is Dictionary:return
            var payload: Dictionary=data.payload.duplicate(true)
            if hosting and str(payload.get("kind",""))=="hello":
                if remote!=2 or normalize_code(str(payload.get("code","")))!=room_code:return
                # Routing proves the public code; Core still checks the saved guest identity.
                payload["code"]=str(party.identity.secret)
            receive(2 if hosting else 1,payload)
        "error":
            pause_relay(str(data.get("message","部屋へ接続できません。")))

func _process(_delta: float) -> void:
    if socket==null:return
    socket.poll()
    if socket.get_ready_state()==WebSocketPeer.STATE_OPEN:
        if not registration_sent:
            registration_sent=true
            if socket.send_text(JSON.stringify(registration))!=OK:
                pause_relay("オンラインへ接続できません。");return
        var packets=0
        while socket!=null and socket.get_available_packet_count()>0 and packets<32:
            var bytes=socket.get_packet();packets+=1
            if bytes.size()>MAX_PACKET+8192:
                pause_relay("通信上限を超えたため停止しました。保存は保持しています。");return
            var data=JSON.parse_string(bytes.get_string_from_utf8())
            if data is Dictionary:relay_message(data)
    elif socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:
        pause_relay("オンライン接続が切れました。戦闘とAIを停止しています。再接続してください。");return
    if socket==null:return
    if Time.get_ticks_msec()>connect_deadline and ((hosting and not relay_registered) or (not hosting and not connected_ok)):
        pause_relay("接続がタイムアウトしました。部屋コードとホストの接続を確認してください。");return
    process_auto()
