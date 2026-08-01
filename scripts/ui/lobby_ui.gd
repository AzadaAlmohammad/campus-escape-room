extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var player_list: ItemList = $VBoxContainer/PlayerList
@onready var server_list: ItemList = $VBoxContainer/ServerList
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var team_assignment: Control = $TeamAssignment

func _ready() -> void:
	add_to_group("lobby")
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	start_button.visible = false
	start_button.disabled = true
	team_assignment.visible = false
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	server_list.item_activated.connect(_on_server_activated)
	LanDiscovery.server_found.connect(_on_server_found)
	LanDiscovery.server_lost.connect(_on_server_lost)
	LanDiscovery.start_listening()
	TeamManager.teams_updated.connect(_update_start_button)

func _on_host_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Host"
	var error := NetworkManager.host_game(player_name)
	if error == OK:
		status_label.text = "Hosting on port %d..." % NetworkManager.DEFAULT_PORT
		host_button.disabled = true
		join_button.disabled = true
		start_button.visible = true
		team_assignment.visible = true
		_refresh_player_list()
		LanDiscovery.start_broadcasting(player_name)
		_update_start_button()
	else:
		status_label.text = "Failed to host: %s" % error_string(error)

func _on_join_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player"
	var address := ip_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var error := NetworkManager.join_game(player_name, address)
	if error == OK:
		status_label.text = "Connecting to %s..." % address
		host_button.disabled = true
		join_button.disabled = true
		team_assignment.visible = true
	else:
		status_label.text = "Failed to join: %s" % error_string(error)

func _on_start_pressed() -> void:
	if NetworkManager.is_host():
		GameManager.start_game()

func _on_player_connected(_peer_id: int) -> void:
	_refresh_player_list()
	_update_start_button()

func _on_player_disconnected(_peer_id: int) -> void:
	_refresh_player_list()
	_update_start_button()

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"
	host_button.disabled = false
	join_button.disabled = false

func _refresh_player_list() -> void:
	player_list.clear()
	for peer_id in NetworkManager.players:
		var info: Dictionary = NetworkManager.players[peer_id]
		player_list.add_item("%s (ID: %d)" % [info["name"], peer_id])

func _on_server_found(ip: String, server_name: String, player_count: int) -> void:
	var label := "%s (%s) - %d Spieler" % [server_name, ip, player_count]
	var index := _find_server_index(ip)
	if index == -1:
		server_list.add_item(label)
		server_list.set_item_metadata(server_list.item_count - 1, ip)
	else:
		server_list.set_item_text(index, label)

func _on_server_lost(ip: String) -> void:
	var index := _find_server_index(ip)
	if index != -1:
		server_list.remove_item(index)

func _on_server_activated(index: int) -> void:
	var ip: String = server_list.get_item_metadata(index)
	ip_input.text = ip
	_on_join_pressed()

func _find_server_index(ip: String) -> int:
	for i in server_list.item_count:
		if server_list.get_item_metadata(i) == ip:
			return i
	return -1

func _update_start_button() -> void:
	if not NetworkManager.is_host():
		return
	var all_assigned := NetworkManager.players.size() > 0
	for peer_id in NetworkManager.players:
		if TeamManager.get_player_team(peer_id) == -1:
			all_assigned = false
			break
	var all_teams_staffed := not TeamManager.teams.is_empty()
	for team_id in TeamManager.teams:
		if TeamManager.teams[team_id]["members"].is_empty():
			all_teams_staffed = false
			break
	start_button.disabled = not (all_assigned and all_teams_staffed)
