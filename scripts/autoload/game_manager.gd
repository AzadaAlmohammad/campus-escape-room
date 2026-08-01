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

func check_team_escape(team_id: int) -> void:
	var room_id: String = TeamManager.teams[team_id]["room_id"]
	var room := get_tree().get_first_node_in_group("room_%s" % room_id)
	if room and room.all_puzzles_solved():
		TeamManager.mark_team_escaped(team_id, game_timer.get_elapsed())
		if _all_teams_escaped():
			_change_state.rpc(GameState.FINISHED)

func _all_teams_escaped() -> bool:
	return TeamManager.teams.values().all(func(t): return t["escaped"])
