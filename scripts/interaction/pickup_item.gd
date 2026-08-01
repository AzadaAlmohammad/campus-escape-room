class_name PickupItem
extends Interactable

@export var item_data: Resource
@export var start_hidden: bool = false

func _ready() -> void:
	if start_hidden:
		is_active = false
		visible = false

func activate(_puzzle_id: String = "") -> void:
	is_active = true
	visible = true

func interact(player: CharacterBody3D) -> void:
	var inv := player.get_node_or_null("Inventory")
	if inv and inv.add_item(item_data):
		_despawn.rpc()
	super.interact(player)

@rpc("authority", "reliable", "call_local")
func _despawn() -> void:
	SfxManager.play("pickup")
	queue_free()
