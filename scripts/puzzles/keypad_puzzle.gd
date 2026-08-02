class_name KeypadPuzzle
extends PuzzleBase

@export var correct_code: String = "1234"
@export var code_length: int = 4
@export var max_attempts: int = 3
@export var lockout_seconds: float = 15.0

@onready var display_label: Label3D = $Display/DisplayLabel
@onready var display_mesh: MeshInstance3D = $Display/DisplayMesh

var entered_code: String = ""
var wrong_attempts: int = 0
var is_locked_out: bool = false

func enter_digit(digit: String) -> void:
	if is_solved or is_locked_out:
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

func _on_failed_attempt(_data: Variant) -> void:
	wrong_attempts += 1
	if wrong_attempts >= max_attempts:
		wrong_attempts = 0
		AlarmSystem.report_wrong_code("Keypad")
		_begin_lockout.rpc()
	else:
		_flash_error.rpc(max_attempts - wrong_attempts)

func _on_solved() -> void:
	display_label.text = "OK"
	var material := display_mesh.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		display_mesh.set_surface_override_material(0, material)
	material.albedo_color = Color.GREEN

@rpc("authority", "reliable", "call_local")
func _flash_error(remaining: int) -> void:
	SfxManager.play("error")
	entered_code = ""
	display_label.text = "X%d" % remaining

@rpc("authority", "reliable", "call_local")
func _begin_lockout() -> void:
	is_locked_out = true
	entered_code = ""
	SfxManager.play("error")
	var remaining := lockout_seconds
	while remaining > 0.0:
		display_label.text = "-%d-" % int(ceil(remaining))
		await get_tree().create_timer(1.0).timeout
		if is_solved:
			return
		remaining -= 1.0
	is_locked_out = false
	display_label.text = ""

@rpc("authority", "reliable", "call_local")
func _sync_display(code: String) -> void:
	entered_code = code
	display_label.text = "*".repeat(code.length())
