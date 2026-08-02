extends MultiplayerSpawner

const BOT_NAMES := ["Nils", "Mara", "Jonas", "Lea", "Ove", "Finja"]

func _ready() -> void:
	var players_node := get_parent().get_node("Players")
	spawn_path = players_node.get_path()
	spawn_function = _spawn_entity
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
	var spawn_points := room.get_node("SpawnPoints").get_children()
	for i in range(team_members.size()):
		var peer_id: int = team_members[i]
		var spawn_pos: Vector3 = spawn_points[i % spawn_points.size()].global_position
		spawn({"type": "player", "peer_id": peer_id, "position": spawn_pos})
	for i in range(room.bot_teammates):
		var slot := team_members.size() + i
		var spawn_pos: Vector3 = spawn_points[slot % spawn_points.size()].global_position
		spawn({
			"type": "bot",
			"index": i,
			"name": BOT_NAMES[i % BOT_NAMES.size()],
			"position": spawn_pos + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)),
		})

func _spawn_entity(data: Variant) -> Node:
	if data.get("type", "player") == "bot":
		return _spawn_bot(data)
	return _spawn_player(data)

func _spawn_player(data: Variant) -> Node:
	var player_scene := preload("res://scenes/player/player.tscn")
	var player := player_scene.instantiate()
	player.name = str(data["peer_id"])
	player.position = data["position"]
	player.set_multiplayer_authority(data["peer_id"])
	return player

func _spawn_bot(data: Variant) -> Node:
	var bot_scene := preload("res://scenes/ai/bot_player.tscn")
	var bot := bot_scene.instantiate()
	bot.name = "Bot%d" % int(data["index"])
	bot.position = data["position"]
	bot.bot_name = str(data["name"])
	return bot
