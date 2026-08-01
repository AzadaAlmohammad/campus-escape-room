class_name KeypadPuzzle
extends PuzzleBase

@export var correct_code: String = "1234"
@export var code_length: int = 4

@onready var display_label: Label3D = $Display/DisplayLabel
@onready var display_mesh: MeshInstance3D = $Display/DisplayMesh

var entered_code: String = ""

func enter_digit(digit: String) -> void:
	if is_solved:
		return
	entered_code += digit
	_sync_display.rpc(entered_code)
	if entered_code.length() >= code_length:
		attempt_solve(entered_code)

func clear_code() -> void:
	entered_code = ""
	_sync_display.rpc(entered_code)

func _validate_solution(data: Variant) -> bool:
	return str(data) == correct_code

func _on_solved() -> void:
	display_label.text = "OK"
	var material := display_mesh.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		display_mesh.set_surface_override_material(0, material)
	material.albedo_color = Color.GREEN

@rpc("authority", "reliable", "call_local")
func _sync_display(code: String) -> void:
	entered_code = code
	display_label.text = "*".repeat(code.length())
