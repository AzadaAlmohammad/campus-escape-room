class_name PuzzleBase
extends Node3D

signal puzzle_solved(puzzle_id: String)
signal puzzle_reset(puzzle_id: String)

@export var puzzle_id: String = ""
@export var team_id: int = -1
@export var sends_cross_team_hint: bool = false
@export var hint_target_team: int = -1
@export var hint_message: String = ""

var is_solved: bool = false

func check_solution() -> bool:
	return false

func attempt_solve(data: Variant = null) -> void:
	if is_solved:
		return
	if not multiplayer.is_server():
		_request_solve.rpc_id(1, data)
		return
	_server_attempt_solve(data)

func _server_attempt_solve(data: Variant) -> void:
	if _validate_solution(data):
		_mark_solved.rpc()
	else:
		_on_failed_attempt(data)

func _on_failed_attempt(_data: Variant) -> void:
	pass

func _validate_solution(data: Variant) -> bool:
	return check_solution()

@rpc("authority", "reliable", "call_local")
func _mark_solved() -> void:
	is_solved = true
	SfxManager.play("puzzle_solved")
	_on_solved()
	puzzle_solved.emit(puzzle_id)
	if sends_cross_team_hint and multiplayer.is_server():
		TeamManager.send_cross_team_hint(hint_target_team, hint_message)

func _on_solved() -> void:
	pass

@rpc("any_peer", "reliable")
func _request_solve(data: Variant) -> void:
	if multiplayer.is_server():
		_server_attempt_solve(data)
