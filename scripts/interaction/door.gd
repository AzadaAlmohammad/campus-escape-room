class_name InteractableDoor
extends Interactable

@export var is_locked: bool = true
@export var open_angle: float = 90.0

var is_open: bool = false

func interact(player: CharacterBody3D) -> void:
	if is_locked and required_item:
		var inv := player.get_node_or_null("Inventory")
		if inv:
			inv.remove_item(required_item)
		is_locked = false
	is_open = !is_open
	_sync_door_state.rpc(is_open, is_locked)
	super.interact(player)

@rpc("authority", "reliable", "call_local")
func _sync_door_state(open: bool, locked: bool) -> void:
	is_open = open
	is_locked = locked
	if is_open:
		SfxManager.play("door_open")
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees:y",
		open_angle if is_open else 0.0, 0.5)
