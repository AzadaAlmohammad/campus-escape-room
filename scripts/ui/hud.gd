extends Control

const ALARM_COLORS := [
	Color(0.55, 0.85, 0.55),
	Color(0.95, 0.85, 0.3),
	Color(1.0, 0.6, 0.2),
	Color(1.0, 0.25, 0.2),
]
const ALARM_LABELS := ["Ruhig", "Aufmerksam", "Alarmiert", "Großalarm"]

@onready var timer_label: Label = $TimerLabel
@onready var prompt_label: Label = $PromptLabel
@onready var puzzle_progress: Label = $PuzzleProgress
@onready var alarm_label: Label = $AlarmLabel
@onready var alert_label: Label = $AlertLabel

var _alert_tween: Tween

func _ready() -> void:
	add_to_group("hud")
	hide_interaction_prompt()
	alert_label.visible = false
	AlarmSystem.alarm_level_changed.connect(update_alarm)
	AlarmSystem.alert_message.connect(show_alert)
	update_alarm(AlarmSystem.alarm_level)

func show_interaction_prompt(text: String) -> void:
	prompt_label.text = "[E] %s" % text
	prompt_label.visible = true

func hide_interaction_prompt() -> void:
	prompt_label.visible = false

func update_timer(remaining: float) -> void:
	var minutes := int(remaining) / 60
	var seconds := int(remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func update_puzzle_progress(solved: int, total: int) -> void:
	puzzle_progress.text = "%d/%d" % [solved, total]

func update_alarm(level: int) -> void:
	var index := clampi(level, 0, ALARM_LABELS.size() - 1)
	alarm_label.text = "Alarm: %s" % ALARM_LABELS[index]
	alarm_label.add_theme_color_override("font_color", ALARM_COLORS[index])

func show_alert(text: String) -> void:
	alert_label.text = text
	alert_label.visible = true
	alert_label.modulate.a = 1.0
	if _alert_tween:
		_alert_tween.kill()
	_alert_tween = create_tween()
	_alert_tween.tween_interval(2.5)
	_alert_tween.tween_property(alert_label, "modulate:a", 0.0, 1.0)
	_alert_tween.tween_callback(func(): alert_label.visible = false)
