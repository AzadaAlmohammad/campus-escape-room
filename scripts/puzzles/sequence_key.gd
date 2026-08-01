class_name SequenceKey
extends Interactable

@export var element_index: int = 0

@onready var sequence_puzzle: SequencePuzzle = get_parent().get_parent() as SequencePuzzle

func interact(player: CharacterBody3D) -> void:
	if sequence_puzzle and not sequence_puzzle.is_solved:
		sequence_puzzle.add_to_sequence(element_index)
	super.interact(player)
