extends MultiplayerSpawner

func _ready() -> void:
	var players_node := get_parent().get_node("Players")
	spawn_path = players_node.get_path()
	spawn_function = _spawn_player
	if multiplayer.is_server():
		GameManager.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PLAYING:
		_spawn_all_team_players()

func _spawn_all_team_players() -> void:
	var room := get_parent() as RoomBase
	if not room:
		return
	var team_members := TeamManager.get_team_members(room.team_id)
	if team_members.is_empty():
		return
	var spawn_points := get_parent().get_node("SpawnPoints").get_children()
	for i in range(team_members.size()):
		var peer_id: int = team_members[i]
		var spawn_pos: Vector3 = spawn_points[i % spawn_points.size()].global_position
		spawn({"peer_id": peer_id, "position": spawn_pos})

func _spawn_player(data: Variant) -> Node:
	var player_scene := preload("res://scenes/player/player.tscn")
	var player := player_scene.instantiate()
	player.name = str(data["peer_id"])
	player.global_position = data["position"]
	player.set_multiplayer_authority(data["peer_id"])
	return player
