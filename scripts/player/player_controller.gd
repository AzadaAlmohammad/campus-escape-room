extends CharacterBody3D

@export var move_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var rotation_speed := 10.0

@onready var camera_rig: Node3D = $CameraRig
@onready var player_model: Node3D = $PlayerModel
@onready var interaction_ray: RayCast3D = $InteractionRayCast

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	if not is_multiplayer_authority():
		set_process_input(false)
		set_physics_process(false)
		$CameraRig/SpringArm3D/Camera3D.current = false
		return
	$CameraRig/SpringArm3D/Camera3D.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("local_player")

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera_rig.global_basis
	var direction := (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0.0

	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		var target_rot := atan2(direction.x, direction.z)
		player_model.rotation.y = lerp_angle(player_model.rotation.y, target_rot, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape_menu"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
