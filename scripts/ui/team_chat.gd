extends Control

@onready var message_list: RichTextLabel = $MessageList
@onready var input_field: LineEdit = $InputField

func _ready() -> void:
	input_field.text_submitted.connect(_on_text_submitted)
	TeamManager.cross_team_hint_received.connect(_on_hint_received)

func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	input_field.clear()
	var my_team := TeamManager.get_player_team(multiplayer.get_unique_id())
	_send_team_message.rpc_id(1, text, my_team)

@rpc("any_peer", "reliable")
func _send_team_message(text: String, _team_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var sender_team := TeamManager.get_player_team(sender_id)
	var sender_name: String = NetworkManager.players[sender_id]["name"]
	for peer_id in TeamManager.get_team_members(sender_team):
		_display_message.rpc_id(peer_id, sender_name, text, false)

@rpc("authority", "reliable")
func _display_message(sender: String, text: String, is_hint: bool) -> void:
	if is_hint:
		message_list.append_text("[color=gold][HINT] %s[/color]\n" % text)
	else:
		message_list.append_text("[b]%s:[/b] %s\n" % [sender, text])

func _on_hint_received(_from_team: int, message: String) -> void:
	_display_message("CROSS-TEAM", message, true)
