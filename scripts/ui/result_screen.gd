class_name ResultScreen
extends Control

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var result_list: RichTextLabel = $Panel/VBoxContainer/ResultList
@onready var restart_button: Button = $Panel/VBoxContainer/HBoxContainer/RestartButton
@onready var quit_button: Button = $Panel/VBoxContainer/HBoxContainer/QuitButton

func _ready() -> void:
	add_to_group("result_screen")
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_victory(teams: Dictionary) -> void:
	title_label.text = "Geschafft!"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	var escaped_team_ids := teams.keys().filter(func(tid): return teams[tid]["escaped"])
	escaped_team_ids.sort_custom(func(a, b): return teams[a]["escape_time"] < teams[b]["escape_time"])
	var text := ""
	var rank := 1
	for team_id in escaped_team_ids:
		var team: Dictionary = teams[team_id]
		text += "[color=#3ddc84][b]%d. %s[/b][/color] — %s\n" % [rank, team["name"], _format_time(team["escape_time"])]
		rank += 1
	result_list.text = text

func show_defeat() -> void:
	title_label.text = "Zeit abgelaufen!"
	title_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	var text := ""
	for team_id in TeamManager.teams:
		var team: Dictionary = TeamManager.teams[team_id]
		var total := _get_total_puzzles(team_id)
		text += "%s — %d/%d Rätsel gelöst\n" % [team["name"], team["solved_puzzles"].size(), total]
	result_list.text = text

func _get_total_puzzles(team_id: int) -> int:
	var room_id: String = TeamManager.teams[team_id]["room_id"]
	var room := get_tree().get_first_node_in_group("room_%s" % room_id)
	if room:
		return room.puzzles.size()
	return TeamManager.teams[team_id]["solved_puzzles"].size()

func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func _on_restart_pressed() -> void:
	GameManager.restart_game()

func _on_quit_pressed() -> void:
	NetworkManager.disconnect_game()
	get_tree().quit()
