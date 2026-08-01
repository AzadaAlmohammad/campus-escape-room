class_name CrossTeamTerminal
extends Interactable

const IDLE_COLOR := Color(0.1, 0.3, 0.6)
const ALERT_COLOR := Color(1.0, 0.5, 0.0)

var hint_messages: Array[String] = []
var terminal_ui: Control = null
var has_unread_hint: bool = false

@onready var status_light: MeshInstance3D = $StatusLight

var _status_light_material: StandardMaterial3D
var _blink_tween: Tween

func _ready() -> void:
	super._ready()
	display_name = "Cross-Team Terminal"
	interaction_prompt = "Terminal öffnen"
	_status_light_material = status_light.get_surface_override_material(0).duplicate()
	status_light.set_surface_override_material(0, _status_light_material)
	TeamManager.cross_team_hint_received.connect(_on_hint_received)

func interact(player: CharacterBody3D) -> void:
	_toggle_terminal_ui()
	super.interact(player)

func _on_hint_received(from_team: int, message: String) -> void:
	var team_name: String = TeamManager.TEAM_NAMES[from_team] if from_team < TeamManager.TEAM_NAMES.size() else "Unknown"
	hint_messages.append("[Team %s]: %s" % [team_name, message])
	_notify_new_hint.rpc()

func _toggle_terminal_ui() -> void:
	if terminal_ui == null:
		_build_terminal_ui()
	terminal_ui.visible = !terminal_ui.visible
	if terminal_ui.visible:
		_refresh_terminal_ui()
		_clear_unread_hint()

func _build_terminal_ui() -> void:
	terminal_ui = Control.new()
	terminal_ui.visible = false
	terminal_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	terminal_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := Panel.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(420, 320)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210, -160)
	terminal_ui.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "Cross-Team Terminal"
	title.position = Vector2(16, 12)
	panel.add_child(title)

	var hint_list := RichTextLabel.new()
	hint_list.name = "HintList"
	hint_list.position = Vector2(16, 44)
	hint_list.size = Vector2(388, 260)
	hint_list.scroll_active = true
	panel.add_child(hint_list)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.add_child(terminal_ui)
	else:
		get_tree().current_scene.add_child(terminal_ui)

func _refresh_terminal_ui() -> void:
	var hint_list := terminal_ui.get_node("Panel/HintList") as RichTextLabel
	hint_list.text = "\n".join(hint_messages) if not hint_messages.is_empty() else "Keine Hinweise empfangen."

func _clear_unread_hint() -> void:
	has_unread_hint = false
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	_status_light_material.emission = IDLE_COLOR

@rpc("authority", "reliable", "call_local")
func _notify_new_hint() -> void:
	has_unread_hint = true
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_status_light_material, "emission", ALERT_COLOR, 0.4)
	_blink_tween.tween_property(_status_light_material, "emission", IDLE_COLOR, 0.4)
