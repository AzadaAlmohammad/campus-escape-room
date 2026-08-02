extends Node

# Temporary integration test autoload for the guard/alarm/bot systems.
# Add as autoload "TestBot" to run; not part of the shipped game.

var failed := 0

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	NetworkManager.host_game("TestBot")
	await get_tree().create_timer(0.5).timeout
	TeamManager.setup_teams(4)
	TeamManager.assign_player_to_team(1, 0)
	GameManager.start_game()
	await get_tree().create_timer(6.0).timeout
	await _run()
	print("TESTBOT_RESULT: %d failures" % failed)
	get_tree().quit(1 if failed > 0 else 0)

func _check(condition: bool, ok_msg: String, fail_msg: String) -> void:
	if condition:
		print("TESTBOT_OK: ", ok_msg)
	else:
		print("TESTBOT_FAIL: ", fail_msg)
		failed += 1

func _run() -> void:
	var room: Node = get_tree().get_first_node_in_group("room_exterior")
	if room == null:
		print("TESTBOT_FAIL: exterior room missing")
		failed += 1
		return

	var player: Node3D = get_tree().get_first_node_in_group("local_player")
	_check(player != null, "player spawned", "player not spawned")
	if player == null:
		return
	_check(player.is_in_group("players"), "player is in 'players' group (guards can see it)", "player missing from 'players' group")

	# --- bot teammates ---
	var bots := get_tree().get_nodes_in_group("bots")
	_check(bots.size() == 2, "%d bot teammates spawned" % bots.size(), "expected 2 bots, got %d" % bots.size())
	if bots.size() > 0:
		var bot_start: Vector3 = bots[0].global_position
		await get_tree().create_timer(4.0).timeout
		_check(bots[0].global_position.distance_to(bot_start) > 0.5,
			"bot wanders (moved %.1fm)" % bots[0].global_position.distance_to(bot_start),
			"bot never moved")
		_check(bots[0].global_position.y > -3.0,
			"bot stays on ground (y=%.1f)" % bots[0].global_position.y,
			"bot fell through ground (y=%.1f)" % bots[0].global_position.y)

	# --- guards patrol while unseen ---
	var guards := get_tree().get_nodes_in_group("guards")
	_check(guards.size() == 2, "%d guards spawned" % guards.size(), "expected 2 guards, got %d" % guards.size())
	if guards.is_empty():
		return

	player.global_position = Vector3(100, 1.0, -56)
	await get_tree().create_timer(6.0).timeout

	var guard: Node3D = guards[1]
	var guard_start: Vector3 = guard.global_position
	await get_tree().create_timer(3.0).timeout
	_check(guard.global_position.distance_to(guard_start) > 1.0,
		"guard patrols (moved %.1fm)" % guard.global_position.distance_to(guard_start),
		"guard did not patrol")
	_check(guard.global_position.y > -3.0,
		"guard stays on ground (y=%.1f)" % guard.global_position.y,
		"guard fell through ground (y=%.1f)" % guard.global_position.y)
	_check(guard.state == GuardBot.State.PATROL,
		"guard is calm while unseen",
		"guard state should be PATROL, is %d" % guard.state)

	# --- guard spots player standing on its route, chases and catches ---
	var timer_before: float = GameManager.game_timer.get_elapsed()
	var alarm_before: int = AlarmSystem.alarm_level
	var ambush: Vector3 = guard._waypoints[guard._waypoint_index]
	player.global_position = ambush + Vector3(0, 0.9, 0)

	# CHASE can last a single frame when the player is standing right on the
	# route, so watch the transition signal instead of polling the state.
	var seen_states: Array[int] = []
	for g in guards:
		g.state_changed.connect(func(s: int): seen_states.append(s))

	var caught := false
	for i in 150:
		await get_tree().create_timer(0.1).timeout
		if AlarmSystem.alarm_level > alarm_before:
			caught = true
			break
	_check(GuardBot.State.CHASE in seen_states,
		"guard spotted the player and gave chase",
		"no guard ever entered CHASE (states seen: %s)" % [seen_states])
	_check(caught, "alarm level rose to %d after being caught" % AlarmSystem.alarm_level,
		"player was never caught (alarm still %d)" % AlarmSystem.alarm_level)
	var penalty: float = GameManager.game_timer.get_elapsed() - timer_before
	_check(penalty >= AlarmSystem.CATCH_TIME_PENALTY,
		"catch cost %.0fs of the clock" % penalty,
		"expected >=%.0fs penalty, got %.1fs" % [AlarmSystem.CATCH_TIME_PENALTY, penalty])
	var spawn_point: Vector3 = room.get_node("SpawnPoints").get_child(0).global_position
	_check(player.global_position.distance_to(spawn_point) < 3.0,
		"caught player was sent back to spawn",
		"player not returned to spawn (at %s)" % player.global_position)

	# --- keypad lockout ---
	var keypad: Node = room.get_node_or_null("Puzzles/GateKeypad")
	if keypad == null:
		print("TESTBOT_FAIL: GateKeypad missing")
		failed += 1
		return
	var alarm_pre_code: int = AlarmSystem.alarm_level
	for attempt in 3:
		for digit in ["1", "1", "1"]:
			keypad.enter_digit(digit)
		await get_tree().create_timer(0.2).timeout
	_check(keypad.is_locked_out, "keypad locks out after 3 wrong codes", "keypad did not lock out")
	_check(AlarmSystem.alarm_level > alarm_pre_code,
		"wrong codes raised the alarm to %d" % AlarmSystem.alarm_level,
		"wrong codes did not raise alarm")
	keypad.enter_digit("5")
	_check(keypad.entered_code == "", "input ignored while locked out", "keypad accepted input while locked out")

	# --- higher alarm makes guards faster ---
	_check(AlarmSystem.get_guard_speed_scale() > 1.0,
		"guards speed up at alarm level %d (x%.1f)" % [AlarmSystem.alarm_level, AlarmSystem.get_guard_speed_scale()],
		"guard speed scale did not increase")

	# --- correct code still works once the lockout ends ---
	keypad.is_locked_out = false
	for digit in ["5", "9", "2"]:
		keypad.enter_digit(digit)
	await get_tree().create_timer(0.5).timeout
	_check(keypad.is_solved, "correct code 592 still solves the keypad", "keypad not solved by correct code")
