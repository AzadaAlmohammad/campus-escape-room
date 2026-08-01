extends Node

signal timer_updated(remaining_seconds: float)
signal timer_expired()

@export var total_time_seconds: float = 3600.0

var elapsed: float = 0.0
var is_running: bool = false
var _sync_timer: Timer

func _ready() -> void:
	_sync_timer = Timer.new()
	_sync_timer.wait_time = 5.0
	_sync_timer.timeout.connect(_on_sync_timer)
	add_child(_sync_timer)

func start_timer() -> void:
	if not multiplayer.is_server():
		return
	_start_all.rpc(total_time_seconds)

@rpc("authority", "reliable", "call_local")
func _start_all(duration: float) -> void:
	total_time_seconds = duration
	elapsed = 0.0
	is_running = true
	_sync_timer.start()

func _process(delta: float) -> void:
	if not is_running:
		return
	elapsed += delta
	var remaining := total_time_seconds - elapsed
	timer_updated.emit(remaining)
	if remaining <= 0.0:
		is_running = false
		_sync_timer.stop()
		timer_expired.emit()

func _on_sync_timer() -> void:
	if multiplayer.is_server() and is_running:
		_correct_time.rpc(elapsed)

@rpc("authority", "unreliable")
func _correct_time(server_elapsed: float) -> void:
	var diff := server_elapsed - elapsed
	if abs(diff) > 0.5:
		elapsed = server_elapsed

func get_elapsed() -> float:
	return elapsed

func get_remaining() -> float:
	return max(0.0, total_time_seconds - elapsed)
