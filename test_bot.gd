extends Node

# Temporary integration test autoload. Hosts a game, assigns teams,
# starts the game and verifies the room + player spawn. Not shipped.

var checks_done := false

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	print("TESTBOT: hosting...")
	var err := NetworkManager.host_game("TestBot")
	if err != OK:
		print("TESTBOT_FAIL: host_game error %s" % err)
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.5).timeout
	TeamManager.setup_teams(4)
	TeamManager.assign_player_to_team(1, 0)
	print("TESTBOT: starting game...")
	GameManager.start_game()
	await get_tree().create_timer(5.0).timeout
	await _verify()

func _verify() -> void:
	if checks_done:
		return
	checks_done = true
	var failed := 0

	var room: Node = get_tree().get_first_node_in_group("room_cafeteria")
	if room:
		print("TESTBOT_OK: cafeteria room loaded")
	else:
		print("TESTBOT_FAIL: cafeteria room not found")
		failed += 1

	var player: Node3D = get_tree().get_first_node_in_group("local_player")
	if player:
		print("TESTBOT_OK: player spawned at %s" % player.global_position)
		if player.global_position.y < -2.0:
			print("TESTBOT_FAIL: player fell through floor (y=%s)" % player.global_position.y)
			failed += 1
	else:
		print("TESTBOT_FAIL: player not spawned")
		failed += 1

	if player:
		var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(Vector3(1, 3, 0), Vector3(1, -10, 0))
		query.collision_mask = 0xFFFFFFFF
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			print("TESTBOT_FAIL: NO floor collision under spawn point!")
			failed += 1
		else:
			print("TESTBOT_OK: floor found at y=%s (collider=%s, layer=%s)" % [hit.position.y, hit.collider.name, hit.collider.collision_layer])
		for probe in [Vector2(-13, 0), Vector2(-12, 0), Vector2(-11, 0), Vector2(10, 0), Vector2(11, 0), Vector2(12, 0), Vector2(0, 4), Vector2(0, 5), Vector2(0, 5.5), Vector2(0, 6), Vector2(0, -5), Vector2(0, -6), Vector2(0, -6.5), Vector2(9.8, -5.5), Vector2(10.3, 5.8)]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(probe.x, 6, probe.y), Vector3(probe.x, -10, probe.y))
			var h: Dictionary = space.intersect_ray(q)
			if h.is_empty():
				print("TESTBOT_PROBE: (%s, %s) -> NO FLOOR" % [probe.x, probe.y])
			else:
				print("TESTBOT_PROBE: (%s, %s) -> y=%.2f (%s)" % [probe.x, probe.y, h.position.y, h.collider.name])
		print("TESTBOT_INFO: %d StaticBody3D nodes in tree" % _count_static_bodies(get_tree().root))

	if room:
		var puzzles: Array = room.puzzles
		print("TESTBOT_OK: %d puzzles registered" % puzzles.size())
		if puzzles.size() != 3:
			print("TESTBOT_FAIL: expected 3 puzzles, got %d" % puzzles.size())
			failed += 1
		var keypad: Node = room.get_node_or_null("Puzzles/KeypadPuzzle01")
		if keypad and keypad.get_node_or_null("Display/DisplayLabel"):
			print("TESTBOT_OK: keypad has display")
		else:
			print("TESTBOT_FAIL: keypad display missing")
			failed += 1
		var fuse: Node = room.get_node_or_null("PickupItems/Sicherung")
		if fuse and fuse.is_active == false and fuse.visible == false:
			print("TESTBOT_OK: fuse hidden at start")
		else:
			print("TESTBOT_FAIL: fuse should start hidden")
			failed += 1
		if keypad:
			print("TESTBOT: solving keypad...")
			for digit in ["4", "7", "1", "9"]:
				keypad.enter_digit(digit)
			await get_tree().create_timer(0.5).timeout
			if keypad.is_solved:
				print("TESTBOT_OK: keypad solved with 4719")
			else:
				print("TESTBOT_FAIL: keypad not solved after entering 4719")
				failed += 1
			if fuse and fuse.is_active and fuse.visible:
				print("TESTBOT_OK: fuse activated after keypad solved")
			else:
				print("TESTBOT_FAIL: fuse not activated after keypad solved")
				failed += 1
		var piano: Node = room.get_node_or_null("Puzzles/PianoPuzzle")
		if piano:
			print("TESTBOT: solving piano sequence...")
			for idx in [0, 2, 1, 3]:
				piano.add_to_sequence(idx)
			await get_tree().create_timer(0.5).timeout
			if piano.is_solved:
				print("TESTBOT_OK: piano sequence solved")
			else:
				print("TESTBOT_FAIL: piano sequence not solved")
				failed += 1
		var automat: Node = room.get_node_or_null("Puzzles/AutomatPuzzle")
		if automat and player:
			var fuse_item: Resource = load("res://resources/items/fuse_cafeteria.tres")
			var inv: Node = player.get_node_or_null("Inventory")
			if inv:
				inv.add_item(fuse_item)
				automat.place_item(fuse_item, player)
				await get_tree().create_timer(0.5).timeout
				if automat.is_solved:
					print("TESTBOT_OK: automat fuse puzzle solved")
				else:
					print("TESTBOT_FAIL: automat puzzle not solved")
					failed += 1
		var exit_door: Node = room.get_node_or_null("Doors/ExitDoor")
		if exit_door:
			await get_tree().create_timer(0.5).timeout
			if exit_door.is_locked == false:
				print("TESTBOT_OK: exit door unlocked after all puzzles")
			else:
				print("TESTBOT_FAIL: exit door still locked after all puzzles solved")
				failed += 1

	print("TESTBOT_RESULT: %d failures" % failed)
	get_tree().quit(1 if failed > 0 else 0)

func _count_static_bodies(node: Node) -> int:
	var count := 1 if node is StaticBody3D else 0
	for child in node.get_children():
		count += _count_static_bodies(child)
	return count
