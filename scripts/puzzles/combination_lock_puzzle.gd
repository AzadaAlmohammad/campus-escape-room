class_name CombinationLockPuzzle
extends PuzzleBase

@export var correct_combination: Array[int] = [0, 0, 0]
@export var num_dials: int = 3
@export var max_value_per_dial: int = 9

var current_values: Array[int] = []

func _ready() -> void:
	super._ready()
	current_values.resize(num_dials)
	current_values.fill(0)

func rotate_dial(dial_index: int, direction: int) -> void:
	if is_solved or dial_index < 0 or dial_index >= num_dials:
		return
	current_values[dial_index] = wrapi(current_values[dial_index] + direction, 0, max_value_per_dial + 1)
	_sync_dials.rpc(current_values)

func submit() -> void:
	attempt_solve(current_values)

func _validate_solution(data: Variant) -> bool:
	var vals := data as Array
	if vals.size() != correct_combination.size():
		return false
	for i in range(vals.size()):
		if vals[i] != correct_combination[i]:
			return false
	return true

@rpc("authority", "reliable", "call_local")
func _sync_dials(values: Array) -> void:
	current_values.assign(values)
