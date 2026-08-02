extends Node

signal alarm_level_changed(level: int)
signal player_caught(peer_id: int)
signal alert_message(text: String)

const MAX_LEVEL := 3
const CATCH_TIME_PENALTY := 60.0
const MISTAKE_TIME_PENALTY := 15.0

var alarm_level: int = 0

func reset() -> void:
	if not multiplayer.is_server():
		return
	_sync_level.rpc(0)

func raise_alarm(amount: int, reason: String) -> void:
	if not multiplayer.is_server():
		return
	_sync_level.rpc(mini(alarm_level + amount, MAX_LEVEL))
	_broadcast_alert.rpc(reason)

func report_wrong_code(puzzle_name: String) -> void:
	if not multiplayer.is_server():
		return
	GameManager.game_timer.apply_penalty(MISTAKE_TIME_PENALTY)
	raise_alarm(1, "%s gesperrt! -%d Sekunden" % [puzzle_name, int(MISTAKE_TIME_PENALTY)])

func catch_player(player: Node3D) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := player.get_multiplayer_authority()
	GameManager.game_timer.apply_penalty(CATCH_TIME_PENALTY)
	raise_alarm(1, "Erwischt! -%d Sekunden" % int(CATCH_TIME_PENALTY))
	var spawn := _pick_spawn_for(player)
	_teleport.rpc_id(peer_id, spawn)
	player.global_position = spawn
	player_caught.emit(peer_id)

func _pick_spawn_for(player: Node3D) -> Vector3:
	var room := player.get_tree().get_first_node_in_group("room")
	if room:
		var spawn_points := room.get_node_or_null("SpawnPoints")
		if spawn_points and spawn_points.get_child_count() > 0:
			var marker: Node3D = spawn_points.get_child(0)
			return marker.global_position
	return player.global_position + Vector3(0, 1, 0)

# Speed multiplier guards use, so mistakes make the campus genuinely harder.
func get_guard_speed_scale() -> float:
	return 1.0 + 0.2 * float(alarm_level)

@rpc("authority", "reliable", "call_local")
func _sync_level(level: int) -> void:
	alarm_level = level
	alarm_level_changed.emit(alarm_level)

@rpc("authority", "reliable", "call_local")
func _teleport(position: Vector3) -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	if player:
		player.global_position = position

@rpc("authority", "reliable", "call_local")
func _broadcast_alert(text: String) -> void:
	SfxManager.play("error")
	alert_message.emit(text)
