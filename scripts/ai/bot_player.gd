class_name BotPlayer
extends CharacterBody3D

## A stand-in team member so small groups (or a solo host) still have
## company in the room. Server-authoritative: only the server steers it,
## clients see it through the MultiplayerSynchronizer.

@export var move_speed: float = 3.0
@export var wander_radius: float = 8.0
@export var idle_seconds_min: float = 1.5
@export var idle_seconds_max: float = 4.0

var bot_name: String = "Bot"

var _home: Vector3 = Vector3.ZERO
var _destination: Vector3 = Vector3.ZERO
var _idle_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _name_label: Label3D = get_node_or_null("NameLabel")

func _ready() -> void:
	add_to_group("bots")
	_home = global_position
	_destination = _home
	if _name_label:
		_name_label.text = bot_name
	set_physics_process(multiplayer.is_server())

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if _idle_timer > 0.0:
		_idle_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var to_target := _destination - global_position
		to_target.y = 0.0
		if to_target.length() < 0.6:
			_pick_new_destination()
		else:
			var direction := to_target.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 6.0 * delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _pick_new_destination() -> void:
	_idle_timer = randf_range(idle_seconds_min, idle_seconds_max)
	var angle := randf() * TAU
	var distance := randf_range(2.0, wander_radius)
	_destination = _home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

@rpc("authority", "reliable", "call_local")
func set_bot_name(new_name: String) -> void:
	bot_name = new_name
	if _name_label:
		_name_label.text = new_name
