class_name Inventory
extends Node

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal inventory_changed()

@export var max_slots: int = 12

var items: Array[ItemData] = []

func has_item(item: Resource) -> bool:
	if item is ItemData:
		return items.any(func(i): return i.item_id == item.item_id)
	return false

func has_item_by_id(item_id: StringName) -> bool:
	return items.any(func(i): return i.item_id == item_id)

func add_item(item: Resource) -> bool:
	if not item is ItemData:
		return false
	if items.size() >= max_slots:
		return false
	items.append(item as ItemData)
	item_added.emit(item)
	inventory_changed.emit()
	_sync_inventory.rpc(_serialize())
	return true

func remove_item(item: Resource) -> void:
	if not item is ItemData:
		return
	var idx := -1
	for i in range(items.size()):
		if items[i].item_id == (item as ItemData).item_id:
			idx = i
			break
	if idx >= 0:
		var removed := items[idx]
		items.remove_at(idx)
		item_removed.emit(removed)
		inventory_changed.emit()
		_sync_inventory.rpc(_serialize())

func try_combine(slot_a: int, slot_b: int) -> bool:
	if slot_a < 0 or slot_a >= items.size() or slot_b < 0 or slot_b >= items.size():
		return false
	var a := items[slot_a]
	var b := items[slot_b]
	if a.is_combinable and a.combine_partner_id == b.item_id:
		var result_path := "res://resources/items/%s.tres" % a.combine_result_id
		if ResourceLoader.exists(result_path):
			var result := load(result_path) as ItemData
			if result:
				items.remove_at(max(slot_a, slot_b))
				items.remove_at(min(slot_a, slot_b))
				items.append(result)
				inventory_changed.emit()
				return true
	return false

func _serialize() -> Array:
	return items.map(func(i): return i.resource_path)

@rpc("authority", "reliable", "call_local")
func _sync_inventory(paths: Array) -> void:
	items.clear()
	for p in paths:
		var loaded := load(p)
		if loaded is ItemData:
			items.append(loaded)
	inventory_changed.emit()
