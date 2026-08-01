class_name ProjectorPuzzle
extends ObjectPlacementPuzzle

func _on_solved() -> void:
	var hint_label := get_node_or_null("HintLabel") as Label3D
	if hint_label:
		hint_label.visible = true
