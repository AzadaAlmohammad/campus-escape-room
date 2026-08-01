class_name MensaRoom
extends RoomBase

func _on_puzzle_solved(puzzle_id: String) -> void:
	if multiplayer.is_server() and puzzle_id == "mensa_combination_01":
		_unlock_internal_door.rpc()
	super._on_puzzle_solved(puzzle_id)

@rpc("authority", "reliable", "call_local")
func _unlock_internal_door() -> void:
	var internal_door := get_node_or_null("Doors/InternalDoor") as InteractableDoor
	if internal_door:
		internal_door.is_locked = false
