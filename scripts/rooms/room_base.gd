class_name RoomBase
extends Node3D

@export var room_id: String = ""
@export var team_id: int = -1
## Stand-in team members the server spawns so small groups aren't alone.
@export var bot_teammates: int = 0

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
	_generate_building_collision()
	_generate_furniture_collision()
	_ensure_player_spawner()

func _generate_building_collision() -> void:
	var collision_model := get_node_or_null("BuildingGeometry/CollisionModel")
	if collision_model:
		for mesh_instance in _find_mesh_instances(collision_model):
			mesh_instance.create_trimesh_collision()
			mesh_instance.visible = false
		return
	var building_model := get_node_or_null("BuildingGeometry/BuildingModel")
	if building_model:
		for mesh_instance in _find_mesh_instances(building_model):
			mesh_instance.create_trimesh_collision()

func _generate_furniture_collision() -> void:
	var furniture := get_node_or_null("Furniture")
	if furniture:
		for mesh_instance in _find_mesh_instances(furniture):
			mesh_instance.create_trimesh_collision()

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result

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
