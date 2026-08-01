class_name ObjectPlacementPuzzle
extends PuzzleBase

@export var required_item_id: StringName = &""

var placed_item: ItemData = null

func place_item(item: ItemData, player: CharacterBody3D) -> void:
	if is_solved or item.item_id != required_item_id:
		return
	var inv := player.get_node_or_null("Inventory")
	if inv:
		inv.remove_item(item)
	placed_item = item
	attempt_solve(item.item_id)

func _validate_solution(data: Variant) -> bool:
	return data == required_item_id

func _on_solved() -> void:
	pass
