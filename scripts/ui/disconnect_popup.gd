extends AcceptDialog

func show_disconnect(message: String) -> void:
	dialog_text = message
	popup_centered()
	confirmed.connect(_on_confirmed)

func _on_confirmed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
