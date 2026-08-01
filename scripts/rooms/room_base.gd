class_name RoomBase
extends Node3D

@export var room_id: String = ""
@export var team_id: int = -1

var puzzles: Array[PuzzleBase] = []

func _ready() -> void:
	add_to_group("room")
	add_to_group("room_%s" % room_id)
	var puzzles_node := get_node_or_null("Puzzles")
	if puzzles_node:
		for child in puzzles_node.get_children():
			if child is PuzzleBase:
				puzzles.append(child)
				child.puzzle_solved.connect(_on_puzzle_solved)
	_ensure_player_spawner()

func _ensure_player_spawner() -> void:
	var spawner := get_node_or_null("PlayerSpawner")
	if not spawner:
		spawner = load("res://scripts/rooms/player_spawner.gd").new()
		spawner.name = "PlayerSpawner"
		add_child(spawner)

func _on_puzzle_solved(puzzle_id: String) -> void:
	if multiplayer.is_server():
		TeamManager.mark_puzzle_solved(team_id, puzzle_id)
		if all_puzzles_solved():
			_unlock_exit.rpc()
			GameManager.check_team_escape(team_id)

func all_puzzles_solved() -> bool:
	return puzzles.all(func(p): return p.is_solved)

@rpc("authority", "reliable", "call_local")
func _unlock_exit() -> void:
	var exit_door := get_node_or_null("Doors/ExitDoor") as InteractableDoor
	if exit_door:
		exit_door.is_locked = false
