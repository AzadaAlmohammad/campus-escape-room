extends Node

const SAMPLE_RATE := 44100

var players: Dictionary = {}

func _ready() -> void:
	_create_sound("interact", 440.0, 0.1)
	_create_sound("pickup", 880.0, 0.15)
	_create_sound("puzzle_solved", 523.0, 0.5)
	_create_sound("door_open", 220.0, 0.3)
	_create_sound("error", 150.0, 0.2)
	_create_sound("hint", 660.0, 0.4)
	_create_sound("timer_warning", 300.0, 0.1)

func play(sound_name: String) -> void:
	if sound_name in players:
		players[sound_name].play()

func _create_sound(sound_name: String, frequency: float, duration: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _generate_tone(frequency, duration)
	player.volume_db = -12.0
	add_child(player)
	players[sound_name] = player

func _generate_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / sample_count)
		var sample := sin(TAU * frequency * t) * envelope
		data.encode_s16(i * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
