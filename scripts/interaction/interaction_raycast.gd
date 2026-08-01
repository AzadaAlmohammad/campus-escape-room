extends RayCast3D

const HIGHLIGHT_MATERIAL := preload("res://assets/materials/highlight_material.tres")

@export var interact_distance := 3.0

var current_target: Interactable = null

func _ready() -> void:
	target_position = Vector3(0, 0, -interact_distance)
	collision_mask = 2
	enabled = true

func _physics_process(_delta: float) -> void:
	if not get_parent().is_multiplayer_authority():
		return

	var new_target: Interactable = null
	if is_colliding():
		var collider := get_collider()
		if collider is Interactable and collider.is_active:
			new_target = collider

	if new_target != current_target:
		_set_highlight(current_target, false)
		current_target = new_target
		_set_highlight(current_target, true)
		_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_target:
		if current_target.can_interact(get_parent()):
			_request_interact.rpc_id(1, get_parent().get_path(), current_target.get_path())

@rpc("any_peer", "reliable")
func _request_interact(player_path: NodePath, interactable_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var player := get_node_or_null(player_path) as CharacterBody3D
	var interactable := get_node_or_null(interactable_path) as Interactable
	if interactable and player and interactable.can_interact(player):
		interactable.interact(player)

func _set_highlight(target: Interactable, enabled: bool) -> void:
	if not target:
		return
	for mesh_instance in _find_mesh_instances(target):
		mesh_instance.material_overlay = HIGHLIGHT_MATERIAL if enabled else null

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		result.append_array(_find_mesh_instances(child))
	return result

func _update_prompt() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_interaction_prompt") and hud.has_method("hide_interaction_prompt"):
		if current_target:
			hud.show_interaction_prompt(current_target.get_prompt_text())
		else:
			hud.hide_interaction_prompt()
