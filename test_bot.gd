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
	await get_tree().create_timer(6.0).timeout
	var room_id: String = TeamManager.TEAM_ROOMS[0]
	if room_id == "exterior":
		await _verify_exterior()
	else:
		print("TESTBOT_FAIL: unexpected room for team 0: %s" % room_id)
		get_tree().quit(1)

func _verify_exterior() -> void:
	if checks_done:
		return
	checks_done = true
	var failed := 0

	var room: Node = get_tree().get_first_node_in_group("room_exterior")
	if room:
		print("TESTBOT_OK: exterior room loaded")
	else:
		print("TESTBOT_FAIL: exterior room not found")
		get_tree().quit(1)
		return

	var player: Node3D = get_tree().get_first_node_in_group("local_player")
	if player:
		print("TESTBOT_OK: player spawned at %s" % player.global_position)
		if player.global_position.y < -3.0:
			print("TESTBOT_FAIL: player fell through ground (y=%s)" % player.global_position.y)
			failed += 1
	else:
		print("TESTBOT_FAIL: player not spawned")
		failed += 1

	if player:
		var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
		for probe in [Vector2(114, -41), Vector2(116, -41), Vector2(114, -43), Vector2(116, -43), Vector2(112, -38), Vector2(120, -38), Vector2(116, -44), Vector2(116, -36), Vector2(110, -40), Vector2(122, -40)]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(probe.x, 30, probe.y), Vector3(probe.x, -20, probe.y))
			var h: Dictionary = space.intersect_ray(q)
			if h.is_empty():
				print("TESTBOT_PROBE: (%s, %s) -> NO GROUND" % [probe.x, probe.y])
			else:
				print("TESTBOT_PROBE: (%s, %s) -> y=%.2f (%s)" % [probe.x, probe.y, h.position.y, h.collider.name])

	var puzzles: Array = room.puzzles
	print("TESTBOT_OK: %d puzzles registered" % puzzles.size())
	if puzzles.size() != 2:
		print("TESTBOT_FAIL: expected 2 puzzles, got %d" % puzzles.size())
		failed += 1

	var switches: Node = room.get_node_or_null("Puzzles/SwitchPuzzle")
	if switches:
		print("TESTBOT: pressing switches green-red-blue...")
		for idx in [1, 0, 2]:
			switches.add_to_sequence(idx)
		await get_tree().create_timer(0.5).timeout
		if switches.is_solved:
			print("TESTBOT_OK: switch sequence solved")
		else:
			print("TESTBOT_FAIL: switch sequence not solved")
			failed += 1
	else:
		print("TESTBOT_FAIL: SwitchPuzzle not found")
		failed += 1

	var keypad: Node = room.get_node_or_null("Puzzles/GateKeypad")
	if keypad:
		print("TESTBOT: entering gate code 592...")
		for digit in ["5", "9", "2"]:
			keypad.enter_digit(digit)
		await get_tree().create_timer(0.5).timeout
		if keypad.is_solved:
			print("TESTBOT_OK: gate keypad solved with 592")
		else:
			print("TESTBOT_FAIL: gate keypad not solved")
			failed += 1
	else:
		print("TESTBOT_FAIL: GateKeypad not found")
		failed += 1

	var exit_door: Node = room.get_node_or_null("Doors/ExitDoor")
	if exit_door:
		await get_tree().create_timer(0.5).timeout
		if exit_door.is_locked == false:
			print("TESTBOT_OK: campus gate unlocked after all puzzles")
		else:
			print("TESTBOT_FAIL: campus gate still locked")
			failed += 1

	print("TESTBOT_RESULT: %d failures" % failed)
	get_tree().quit(1 if failed > 0 else 0)
