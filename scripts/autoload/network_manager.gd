extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal server_started()

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 20

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
	multiplayer.connected_to_server.connect(_on_connected_to_server.bind(player_name))
	multiplayer.connection_failed.connect(func(): connection_failed.emit())
	return OK

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
	player_disconnected.emit(id)
	_sync_player_list.rpc(players)

func is_host() -> bool:
	return multiplayer.is_server()

func disconnect_game() -> void:
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
