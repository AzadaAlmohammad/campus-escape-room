extends Control

@onready var timer_label: Label = $TimerLabel
@onready var prompt_label: Label = $PromptLabel
@onready var puzzle_progress: Label = $PuzzleProgress

func _ready() -> void:
	add_to_group("hud")
	hide_interaction_prompt()

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
