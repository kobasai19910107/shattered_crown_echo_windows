class_name Region1Save
extends RefCounted

static func read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var parser=JSON.new()
    if parser.parse(FileAccess.get_file_as_string(path))!=OK: return {}
    var envelope = parser.data
    if not envelope is Dictionary: return {}
    var payload: String = str(envelope.get("payload",""))
    if payload.sha256_text()!=str(envelope.get("sha256","")): return {}
    if parser.parse(payload)!=OK: return {}
    var state = parser.data
    return state if state is Dictionary else {}

static func write(path: String, state: Dictionary) -> bool:
    var payload: String = JSON.stringify(state)
    var temporary: String = path+".tmp"
    var file = FileAccess.open(temporary,FileAccess.WRITE)
    if file == null: return false
    file.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
    file.flush()
    var error: Error = file.get_error()
    file.close()
    if error!=OK: return false
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))==OK
