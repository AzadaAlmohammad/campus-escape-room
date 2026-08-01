extends Node

enum GameState { LOBBY, LOADING, PLAYING, FINISHED }

signal state_changed(new_state: GameState)

var current_state: GameState = GameState.LOBBY
var game_timer: Node

func _ready() -> void:
	var timer_script := load("res://scripts/timer/game_timer.gd")
	game_timer = Node.new()
	game_timer.set_script(timer_script)
	game_timer.name = "GameTimer"
	add_child(game_timer)
	game_timer.timer_expired.connect(_on_timer_expired)

func start_game() -> void:
	if not multiplayer.is_server():
		return
	_change_state.rpc(GameState.LOADING)
	for team_id in TeamManager.teams:
		var room_id: String = TeamManager.teams[team_id]["room_id"]
		_load_room_for_team.rpc(team_id, room_id)
	await get_tree().create_timer(2.0).timeout
	_change_state.rpc(GameState.PLAYING)
	game_timer.start_timer()

@rpc("authority", "reliable", "call_local")
func _load_room_for_team(team_id: int, room_id: String) -> void:
	var my_team := TeamManager.get_player_team(multiplayer.get_unique_id())
	if my_team == team_id:
		var room_path := "res://scenes/rooms/%s.tscn" % room_id
		if ResourceLoader.exists(room_path):
			var room_scene := load(room_path) as PackedScene
			var room := room_scene.instantiate()
			get_tree().root.add_child(room)
		var lobby := get_tree().get_first_node_in_group("lobby")
		if lobby:
			lobby.queue_free()

@rpc("authority", "reliable", "call_local")
func _change_state(new_state: int) -> void:
	current_state = new_state as GameState
	state_changed.emit(current_state)
	if current_state == GameState.FINISHED:
		_show_result_screen()

func _on_timer_expired() -> void:
	if not multiplayer.is_server():
		return
	if current_state == GameState.PLAYING:
		_change_state.rpc(GameState.FINISHED)

func _show_result_screen() -> void:
	var result_scene := load("res://scenes/result_screen.tscn") as PackedScene
	var result := result_scene.instantiate()
	get_tree().root.add_child(result)
	if _all_teams_escaped():
		result.show_victory(TeamManager.teams)
	else:
		result.show_defeat()

func restart_game() -> void:
	if not multiplayer.is_server():
		return
	_restart_all.rpc()

@rpc("authority", "reliable", "call_local")
func _restart_all() -> void:
	current_state = GameState.LOBBY
	TeamManager.teams.clear()
	for peer_id in NetworkManager.players:
		NetworkManager.players[peer_id]["team_id"] = -1
	var result_screen := get_tree().get_first_node_in_group("result_screen")
	if result_screen:
		result_screen.queue_free()
	for room in get_tree().get_nodes_in_group("room"):
		room.queue_free()
	game_timer.is_running = false
	var lobby_scene := load("res://scenes/lobby/lobby.tscn") as PackedScene
	var lobby := lobby_scene.instantiate()
	get_tree().root.add_child(lobby)
	state_changed.emit(current_state)

func check_team_escape(team_id: int) -> void:
	var room_id: String = TeamManager.teams[team_id]["room_id"]
	var room := get_tree().get_first_node_in_group("room_%s" % room_id)
	if room and room.all_puzzles_solved():
		TeamManager.mark_team_escaped(team_id, game_timer.get_elapsed())
		if _all_teams_escaped():
			_change_state.rpc(GameState.FINISHED)

func _all_teams_escaped() -> bool:
	return TeamManager.teams.values().all(func(t): return t["escaped"])
