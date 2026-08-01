extends Control

const NUM_TEAMS := 4

@onready var team_labels: Array = [
	$VBoxContainer/HBoxContainer/TeamColumn0/TeamLabel0,
	$VBoxContainer/HBoxContainer/TeamColumn1/TeamLabel1,
	$VBoxContainer/HBoxContainer/TeamColumn2/TeamLabel2,
	$VBoxContainer/HBoxContainer/TeamColumn3/TeamLabel3,
]
@onready var team_lists: Array = [
	$VBoxContainer/HBoxContainer/TeamColumn0/TeamList0,
	$VBoxContainer/HBoxContainer/TeamColumn1/TeamList1,
	$VBoxContainer/HBoxContainer/TeamColumn2/TeamList2,
	$VBoxContainer/HBoxContainer/TeamColumn3/TeamList3,
]
@onready var auto_assign_button: Button = $VBoxContainer/HBoxContainer2/AutoAssignButton

func _ready() -> void:
	for i in range(NUM_TEAMS):
		team_labels[i].text = "%s - %s" % [TeamManager.TEAM_NAMES[i], TeamManager.TEAM_ROOMS[i].capitalize()]
		team_lists[i].item_activated.connect(_on_item_activated.bind(i))
	auto_assign_button.pressed.connect(auto_assign)
	TeamManager.teams_updated.connect(refresh)
	NetworkManager.player_connected.connect(func(_id): refresh())
	NetworkManager.player_disconnected.connect(func(_id): refresh())
	if NetworkManager.is_host() and TeamManager.teams.is_empty():
		TeamManager.setup_teams(NUM_TEAMS)
	refresh()

func refresh() -> void:
	auto_assign_button.visible = NetworkManager.is_host()
	for i in range(NUM_TEAMS):
		team_lists[i].clear()
		for peer_id in TeamManager.get_team_members(i):
			var player_name: String = NetworkManager.players.get(peer_id, {}).get("name", "?")
			var idx := team_lists[i].add_item("%s (ID: %d)" % [player_name, peer_id])
			team_lists[i].set_item_metadata(idx, peer_id)

func auto_assign() -> void:
	if not NetworkManager.is_host():
		return
	var peer_ids := NetworkManager.players.keys()
	for i in range(peer_ids.size()):
		_on_move_button(peer_ids[i], i % NUM_TEAMS)

func _on_move_button(peer_id: int, target_team: int) -> void:
	if not NetworkManager.is_host():
		return
	TeamManager.assign_player_to_team(peer_id, target_team)

func _on_item_activated(index: int, from_team: int) -> void:
	if not NetworkManager.is_host():
		return
	var peer_id: int = team_lists[from_team].get_item_metadata(index)
	var target_team := (from_team + 1) % NUM_TEAMS
	_on_move_button(peer_id, target_team)
