extends Node3D

@export var mouse_sensitivity := 0.002
@export var min_pitch := -80.0
@export var max_pitch := 60.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

func _ready() -> void:
	spring_arm.spring_length = 4.0
	spring_arm.add_excluded_object(get_parent())

func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x -= event.relative.y * mouse_sensitivity
		rotation.x = clamp(rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
