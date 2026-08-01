extends Node

signal server_found(ip: String, server_name: String, player_count: int)
signal server_lost(ip: String)

const BROADCAST_PORT := 7776
const BROADCAST_INTERVAL := 2.0
const SERVER_TIMEOUT := 10.0
const MAGIC := "CAMPUS_ESC"

var udp_peer: PacketPeerUDP
var broadcast_timer: Timer
var is_broadcasting: bool = false
var is_listening: bool = false

var _broadcast_server_name: String = ""
var _discovered_servers: Dictionary = {} # ip -> { "name": String, "player_count": int, "last_seen": float }

func _ready() -> void:
	set_process(false)

func start_broadcasting(server_name: String) -> void:
	stop()
	_broadcast_server_name = server_name
	udp_peer = PacketPeerUDP.new()
	udp_peer.set_broadcast_enabled(true)
	udp_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = BROADCAST_INTERVAL
	broadcast_timer.autostart = true
	broadcast_timer.timeout.connect(_on_broadcast_timeout)
	add_child(broadcast_timer)
	is_broadcasting = true
	_on_broadcast_timeout()

func start_listening() -> void:
	stop()
	udp_peer = PacketPeerUDP.new()
	var error := udp_peer.bind(BROADCAST_PORT)
	if error != OK:
		push_warning("LanDiscovery: Konnte nicht auf Port %d binden (%s)" % [BROADCAST_PORT, error_string(error)])
		udp_peer = null
		return
	is_listening = true
	_discovered_servers.clear()
	set_process(true)

func stop() -> void:
	set_process(false)
	if broadcast_timer:
		broadcast_timer.queue_free()
		broadcast_timer = null
	if udp_peer:
		udp_peer.close()
		udp_peer = null
	is_broadcasting = false
	is_listening = false
	_discovered_servers.clear()

func _process(_delta: float) -> void:
	if not is_listening or udp_peer == null:
		return
	while udp_peer.get_available_packet_count() > 0:
		var packet := udp_peer.get_packet()
		var ip := udp_peer.get_packet_ip()
		_handle_packet(packet, ip)
	_check_timeouts()

func _on_broadcast_timeout() -> void:
	if udp_peer == null:
		return
	var player_count: int = NetworkManager.players.size()
	var packet := "%s|%s|%d" % [MAGIC, _broadcast_server_name, player_count]
	udp_peer.put_packet(packet.to_utf8_buffer())

func _handle_packet(packet: PackedByteArray, ip: String) -> void:
	var text := packet.get_string_from_utf8()
	var parts := text.split("|")
	if parts.size() != 3 or parts[0] != MAGIC:
		return
	var server_name := parts[1]
	var player_count := parts[2].to_int()
	_discovered_servers[ip] = {
		"name": server_name,
		"player_count": player_count,
		"last_seen": Time.get_ticks_msec() / 1000.0
	}
	server_found.emit(ip, server_name, player_count)

func _check_timeouts() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var expired: Array = []
	for ip in _discovered_servers:
		if now - _discovered_servers[ip]["last_seen"] > SERVER_TIMEOUT:
			expired.append(ip)
	for ip in expired:
		_discovered_servers.erase(ip)
		server_lost.emit(ip)
