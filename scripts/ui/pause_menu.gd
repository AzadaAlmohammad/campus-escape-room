class_name PauseMenu
extends Control

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var sensitivity_slider: HSlider = $Panel/VBoxContainer/SettingsContainer/HBoxContainer/SensitivitySlider
@onready var volume_slider: HSlider = $Panel/VBoxContainer/SettingsContainer/HBoxContainer2/VolumeSlider
@onready var disconnect_button: Button = $Panel/VBoxContainer/DisconnectButton

var master_bus_idx: int = AudioServer.get_bus_index("Master")

func _ready() -> void:
	add_to_group("pause_menu")
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_idx))

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("escape_menu"):
		return
	if not visible and _is_blocking_ui_open():
		return
	toggle_menu()

func toggle_menu() -> void:
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED

func _is_blocking_ui_open() -> bool:
	for group_name in ["inventory_ui", "chat_ui"]:
		var node := get_tree().get_first_node_in_group(group_name)
		if node and node.visible:
			return true
	return false

func _on_resume_pressed() -> void:
	toggle_menu()

func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _on_sensitivity_changed(value: float) -> void:
	var player := get_tree().get_first_node_in_group("local_player")
	if player:
		var camera_rig := player.get_node_or_null("CameraRig")
		if camera_rig:
			camera_rig.mouse_sensitivity = value

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))
