extends Node

signal teams_updated()
signal cross_team_hint_received(from_team: int, message: String)
signal team_escaped(team_id: int, time_seconds: float)

var teams: Dictionary = {}

const TEAM_NAMES := ["Alpha", "Beta", "Gamma", "Delta"]
const TEAM_ROOMS := {
	0: "exterior",
	1: "mensa",
	2: "t002",
	3: "cafeteria"
}

func _ready() -> void:
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _on_player_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var changed := false
	for tid in teams:
		if peer_id in teams[tid]["members"]:
			teams[tid]["members"].erase(peer_id)
			changed = true
	if changed:
		_sync_teams.rpc(teams)

func setup_teams(num_teams: int) -> void:
	teams.clear()
	for i in range(num_teams):
		teams[i] = {
			"name": TEAM_NAMES[i],
			"room_id": TEAM_ROOMS[i],
			"members": [],
			"solved_puzzles": [],
			"escaped": false,
			"escape_time": 0.0
		}

func assign_player_to_team(peer_id: int, team_id: int) -> void:
	for tid in teams:
		teams[tid]["members"].erase(peer_id)
	teams[team_id]["members"].append(peer_id)
	NetworkManager.players[peer_id]["team_id"] = team_id
	_sync_teams.rpc(teams)

func get_team_members(team_id: int) -> Array:
	return teams.get(team_id, {}).get("members", [])

func get_player_team(peer_id: int) -> int:
	for tid in teams:
		if peer_id in teams[tid]["members"]:
			return tid
	return -1

func mark_puzzle_solved(team_id: int, puzzle_id: String) -> void:
	if puzzle_id not in teams[team_id]["solved_puzzles"]:
		teams[team_id]["solved_puzzles"].append(puzzle_id)
		_sync_teams.rpc(teams)

func mark_team_escaped(team_id: int, time: float) -> void:
	teams[team_id]["escaped"] = true
	teams[team_id]["escape_time"] = time
	team_escaped.emit(team_id, time)
	_sync_teams.rpc(teams)

func send_cross_team_hint(target_team: int, message: String) -> void:
	var from_team := get_player_team(multiplayer.get_unique_id())
	for peer_id in teams[target_team]["members"]:
		_receive_hint.rpc_id(peer_id, from_team, message)

@rpc("authority", "reliable")
func _receive_hint(from_team: int, message: String) -> void:
	cross_team_hint_received.emit(from_team, message)

@rpc("authority", "reliable", "call_local")
func _sync_teams(data: Dictionary) -> void:
	teams = data
	teams_updated.emit()
