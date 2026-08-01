extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal server_started()
signal server_disconnected()

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 20
const CONNECTION_TIMEOUT := 10.0

var peer: ENetMultiplayerPeer
var players: Dictionary = {} # peer_id -> { name, team_id }

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_register_player(1, player_name)
	server_started.emit()
	return OK

func join_game(player_name: String, address: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server.bind(player_name), CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_start_connection_timeout()
	return OK

func _start_connection_timeout() -> void:
	await get_tree().create_timer(CONNECTION_TIMEOUT).timeout
	if peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		_on_connection_failed()

func _on_connection_failed() -> void:
	disconnect_game()
	connection_failed.emit()

func _on_connected_to_server(player_name: String) -> void:
	_register_player_on_server.rpc_id(1, player_name)

@rpc("any_peer", "reliable")
func _register_player_on_server(player_name: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_register_player(sender_id, player_name)
	_sync_player_list.rpc(players)

@rpc("authority", "reliable", "call_local")
func _sync_player_list(player_data: Dictionary) -> void:
	players = player_data

func _register_player(peer_id: int, player_name: String) -> void:
	players[peer_id] = { "name": player_name, "team_id": -1 }
	player_connected.emit(peer_id)

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	_remove_player_node(id)
	player_disconnected.emit(id)
	_sync_player_list.rpc(players)

func _remove_player_node(id: int) -> void:
	for node in get_tree().get_nodes_in_group("players"):
		if node.name == str(id):
			node.queue_free()

func _on_server_disconnected() -> void:
	_show_disconnect_popup("Verbindung zum Host wurde getrennt.")
	disconnect_game()
	server_disconnected.emit()

func _show_disconnect_popup(message: String) -> void:
	var popup := AcceptDialog.new()
	popup.set_script(load("res://scripts/ui/disconnect_popup.gd"))
	get_tree().root.add_child(popup)
	popup.show_disconnect(message)

func is_host() -> bool:
	return multiplayer.is_server()

func disconnect_game() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
