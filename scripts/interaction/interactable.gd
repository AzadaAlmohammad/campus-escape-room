class_name Interactable
extends StaticBody3D

@export var display_name: String = "Object"
@export var interaction_prompt: String = "Interact"
@export var is_active: bool = true
@export var required_item: Resource = null

signal interacted(player_peer_id: int)

func get_prompt_text() -> String:
	if required_item and required_item.has_method("get") and required_item.get("item_name"):
		return "%s (Requires: %s)" % [interaction_prompt, required_item.item_name]
	return interaction_prompt

func can_interact(player: CharacterBody3D) -> bool:
	if not is_active:
		return false
	if required_item:
		var inventory := player.get_node_or_null("Inventory")
		if inventory:
			return inventory.has_item(required_item)
		return false
	return true

func interact(player: CharacterBody3D) -> void:
	if player:
		interacted.emit(player.get_multiplayer_authority())
	else:
		interacted.emit(0)

@rpc("authority", "reliable", "call_local")
func _sync_interaction_state(active: bool) -> void:
	is_active = active
