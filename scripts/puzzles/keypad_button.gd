class_name KeypadButton
extends Interactable

@export var digit: String = "0"

@onready var keypad_puzzle: KeypadPuzzle = get_parent().get_parent() as KeypadPuzzle

func interact(player: CharacterBody3D) -> void:
	if keypad_puzzle:
		keypad_puzzle.enter_digit(digit)
	super.interact(player)
