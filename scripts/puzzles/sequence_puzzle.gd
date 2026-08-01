class_name SequencePuzzle
extends PuzzleBase

@export var correct_sequence: Array[int] = []

var current_sequence: Array[int] = []

func add_to_sequence(element_index: int) -> void:
	current_sequence.append(element_index)
	_sync_sequence.rpc(current_sequence)
	if current_sequence.size() == correct_sequence.size():
		attempt_solve(current_sequence)
		if multiplayer.is_server() and not is_solved:
			reset_sequence()
	elif current_sequence.size() > correct_sequence.size():
		reset_sequence()

func reset_sequence() -> void:
	current_sequence.clear()
	_sync_sequence.rpc(current_sequence)

func _validate_solution(data: Variant) -> bool:
	var seq := data as Array
	return seq == correct_sequence

@rpc("authority", "reliable", "call_local")
func _sync_sequence(seq: Array) -> void:
	current_sequence.assign(seq)
