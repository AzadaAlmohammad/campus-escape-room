class_name PickupItem
extends Interactable

@export var item_data: Resource

func interact(player: CharacterBody3D) -> void:
	var inv := player.get_node_or_null("Inventory")
	if inv and inv.add_item(item_data):
		_despawn.rpc()
	super.interact(player)

@rpc("authority", "reliable", "call_local")
func _despawn() -> void:
	queue_free()
