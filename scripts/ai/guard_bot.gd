class_name GuardBot
extends CharacterBody3D

## Server-authoritative patrolling guard. Only the server runs the AI;
## clients receive position/rotation through the MultiplayerSynchronizer
## and the visible state through _sync_state.

signal state_changed(new_state: int)

enum State { PATROL, SUSPICIOUS, CHASE, RETURNING }

const EYE_HEIGHT := 1.6

@export var patrol_speed: float = 2.5
@export var chase_speed: float = 5.2
@export var turn_speed: float = 6.0
@export var vision_range: float = 16.0
@export var vision_angle_deg: float = 65.0
## Within this radius the guard notices you from any angle, so you cannot
## hide by hugging their back.
@export var awareness_radius: float = 3.5
@export var catch_distance: float = 1.8
@export var suspicion_seconds: float = 1.0
@export var lose_target_seconds: float = 4.0
@export var waypoint_reach_distance: float = 1.5
@export var waypoints_path: NodePath

var state: State = State.PATROL
var _waypoints: Array[Vector3] = []
var _waypoint_index: int = 0
var _target: Node3D = null
var _last_known_position: Vector3 = Vector3.ZERO
var _seen_timer: float = 0.0
var _lost_timer: float = 0.0
var _catch_cooldown: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _status_light: OmniLight3D = get_node_or_null("StatusLight")

func _ready() -> void:
	add_to_group("guards")
	_collect_waypoints()
	set_physics_process(multiplayer.is_server())

func _collect_waypoints() -> void:
	_waypoints.clear()
	if waypoints_path.is_empty():
		return
	var node := get_node_or_null(waypoints_path)
	if node == null:
		return
	for child in node.get_children():
		if child is Node3D:
			_waypoints.append((child as Node3D).global_position)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)

	var visible_player := _find_visible_player()
	_update_state(visible_player, delta)

	match state:
		State.PATROL, State.RETURNING:
			_move_along_patrol(delta)
		State.SUSPICIOUS:
			# Walk over to whatever caught their eye. Standing still and
			# staring lets a player slip behind the guard and wait it out.
			_move_towards(_last_known_position, patrol_speed * 0.8, delta)
		State.CHASE:
			var goal := _target.global_position if _target else _last_known_position
			_move_towards(goal, chase_speed * AlarmSystem.get_guard_speed_scale(), delta)
			_try_catch()

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _update_state(visible_player: Node3D, delta: float) -> void:
	var previous := state
	if visible_player:
		_target = visible_player
		_last_known_position = visible_player.global_position
		_lost_timer = 0.0
		_seen_timer += delta
		if _seen_timer >= suspicion_seconds:
			state = State.CHASE
		elif state != State.CHASE:
			state = State.SUSPICIOUS
	else:
		# Suspicion fades instead of resetting, so a guard that caught a
		# glimpse still closes in rather than shrugging it off instantly.
		_seen_timer = maxf(0.0, _seen_timer - delta * 0.5)
		if state == State.CHASE or state == State.SUSPICIOUS:
			_lost_timer += delta
			if _lost_timer >= lose_target_seconds:
				_target = null
				state = State.RETURNING
	if state == State.RETURNING and _is_at_waypoint():
		state = State.PATROL
	if state != previous:
		_sync_state.rpc(int(state))

func _find_visible_player() -> Node3D:
	var best: Node3D = null
	var best_distance := vision_range
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var forward := -global_transform.basis.z
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Node3D
		if player == null:
			continue
		var target_point := player.global_position + Vector3(0, 1.0, 0)
		var to_player := target_point - eye
		var distance := to_player.length()
		if distance > best_distance or distance < 0.01:
			continue
		var flat_dir := Vector3(to_player.x, 0.0, to_player.z).normalized()
		var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
		if flat_dir.length() > 0.0 and flat_forward.length() > 0.0:
			var angle := rad_to_deg(flat_forward.angle_to(flat_dir))
			# A chased player, or one standing right next to the guard,
			# stays noticed even outside the cone -- otherwise you could
			# escape by simply stepping behind them.
			var cone_exempt := state == State.CHASE or distance <= awareness_radius
			if angle > vision_angle_deg * 0.5 and not cone_exempt:
				continue
		if not _has_line_of_sight(eye, target_point, player):
			continue
		best = player
		best_distance = distance
	return best

func _has_line_of_sight(from: Vector3, to: Vector3, player: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [get_rid(), player.get_rid()]
	return space.intersect_ray(query).is_empty()

func _move_along_patrol(delta: float) -> void:
	if _waypoints.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target_point := _waypoints[_waypoint_index]
	if _is_at_waypoint():
		_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
		target_point = _waypoints[_waypoint_index]
	_move_towards(target_point, patrol_speed, delta)

func _is_at_waypoint() -> bool:
	if _waypoints.is_empty():
		return true
	var target_point := _waypoints[_waypoint_index]
	return Vector2(target_point.x - global_position.x, target_point.z - global_position.z).length() <= waypoint_reach_distance

func _move_towards(target_point: Vector3, speed: float, delta: float) -> void:
	var direction := target_point - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face_towards(target_point, delta)

func _face_towards(target_point: Vector3, delta: float) -> void:
	var direction := target_point - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		return
	var desired := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, desired, turn_speed * delta)

func _try_catch() -> void:
	if _target == null or _catch_cooldown > 0.0:
		return
	if global_position.distance_to(_target.global_position) <= catch_distance:
		_catch_cooldown = 5.0
		AlarmSystem.catch_player(_target)
		_target = null
		state = State.RETURNING
		_sync_state.rpc(int(state))

@rpc("authority", "reliable", "call_local")
func _sync_state(new_state: int) -> void:
	state = new_state as State
	state_changed.emit(new_state)
	if _status_light:
		match state:
			State.PATROL, State.RETURNING:
				_status_light.light_color = Color(0.2, 0.8, 0.3)
			State.SUSPICIOUS:
				_status_light.light_color = Color(1.0, 0.75, 0.1)
			State.CHASE:
				_status_light.light_color = Color(1.0, 0.15, 0.1)
