extends Control

@onready var grid: GridContainer = $Panel/GridContainer

func _ready() -> void:
	visible = false
	_connect_inventory()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		visible = !visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_refresh_slots()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _connect_inventory() -> void:
	await get_tree().create_timer(1.0).timeout
	var players := get_tree().get_nodes_in_group("local_player")
	if players.size() > 0:
		var inv := players[0].get_node_or_null("Inventory") as Inventory
		if inv:
			inv.inventory_changed.connect(_refresh_slots)

func _refresh_slots() -> void:
	for child in grid.get_children():
		child.queue_free()

	var players := get_tree().get_nodes_in_group("local_player")
	if players.is_empty():
		return
	var inv := players[0].get_node_or_null("Inventory") as Inventory
	if not inv:
		return

	for item in inv.items:
		var slot := Button.new()
		slot.text = item.item_name
		slot.tooltip_text = item.description
		slot.custom_minimum_size = Vector2(80, 80)
		grid.add_child(slot)

	for i in range(inv.items.size(), inv.max_slots):
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(80, 80)
		grid.add_child(empty)
