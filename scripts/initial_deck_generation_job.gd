class_name InitialDeckGenerationJob
extends RefCounted

const Generator = preload("res://scripts/ranked_initial_deck_generator.gd")
var thread = Thread.new()
var mutex = Mutex.new()
var _cancelled: bool = false
var _progress: String = "候補確認"
var _result: Dictionary = {}
var _joined: bool = false
var _web_done: bool = false

func start(template_ids: Dictionary, seed_value: int) -> Error:
    if thread.is_started():
        return ERR_BUSY
    if OS.has_feature("web"):
        _web_done = false
        call_deferred("_run_web", template_ids.duplicate(true), seed_value)
        return OK
    return thread.start(_run.bind(template_ids.duplicate(true),seed_value))

func _run_web(template_ids: Dictionary, seed_value: int) -> void:
    _run(template_ids, seed_value)
    _web_done = true

func _run(template_ids: Dictionary, seed_value: int) -> void:
    var generator = Generator.new()
    var result: Dictionary = generator.generate(template_ids,seed_value,is_cancelled,_notify)
    mutex.lock()
    _result = result
    mutex.unlock()

func _notify(label: String) -> void:
    mutex.lock()
    _progress = label
    mutex.unlock()

func is_cancelled() -> bool:
    mutex.lock()
    var value: bool = _cancelled
    mutex.unlock()
    return value

func cancel() -> void:
    mutex.lock()
    _cancelled = true
    mutex.unlock()

func join() -> void:
    if OS.has_feature("web"):
        return
    if thread.is_started() and not _joined:
        thread.wait_to_finish()
        _joined = true

func poll() -> Dictionary:
    # wait_to_finish clears Thread.is_started(); completion must remain observable.
    var done: bool = _web_done if OS.has_feature("web") else (_joined or (thread.is_started() and not thread.is_alive()))
    if done:
        join()
    mutex.lock()
    var response: Dictionary = {"done":done,"progress":_progress,"cancelled":_cancelled,"result":_result.duplicate(true) if done else {}}
    mutex.unlock()
    return response
