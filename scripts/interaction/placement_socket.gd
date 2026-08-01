class_name PlacementSocket
extends Interactable

@onready var placement_puzzle: ObjectPlacementPuzzle = get_parent() as ObjectPlacementPuzzle

func interact(player: CharacterBody3D) -> void:
	if placement_puzzle and not placement_puzzle.is_solved and required_item is ItemData:
		placement_puzzle.place_item(required_item, player)
	super.interact(player)
