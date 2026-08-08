class_name AudioController
extends Node

## Manages the lifecycle and state of the shared AudioPanel scene.

var audio_panel_scene_path := "res://scenes/shared/AudioPanel.tscn"

var _audio_panel: Node = null
var _audio_panel_owned := false
var _audio_btn: Button = null

func setup_audio_button(btn: Button, audio_path: String) -> void:
	_audio_btn = btn
	_audio_btn.pressed.connect(_on_button_pressed.bind(audio_path))

func _on_button_pressed(path: String) -> void:
	if _audio_panel == null or not is_instance_valid(_audio_panel):
		_instantiate_panel()
		
	if _audio_panel == null:
		return
		
	if _audio_panel.is_playing():
		_audio_panel.stop_and_close()
		_set_button_idle()
	else:
		_audio_panel.load_and_play(path)
		_set_button_playing()

func _instantiate_panel() -> void:
	if not ResourceLoader.exists(audio_panel_scene_path):
		push_warning("AudioPanel scene not found.")
		return
		
	var scene := load(audio_panel_scene_path) as PackedScene
	if scene == null: return
	
	_audio_panel = scene.instantiate()
	get_tree().root.add_child(_audio_panel)
	_audio_panel_owned = true
	
	if _audio_panel.audio_closed.is_connected(_on_panel_closed):
		_audio_panel.audio_closed.connect(_on_panel_closed)

func _on_panel_closed() -> void:
	_set_button_idle()

func _set_button_playing() -> void:
	if _audio_btn:
		_audio_btn.text = "Stop the Audio"
		# Apply error color style via ExerciseTheme if needed

func _set_button_idle() -> void:
	if _audio_btn:
		_audio_btn.text = "Play the Audio"

func _exit_tree() -> void:
	if _audio_panel != null and is_instance_valid(_audio_panel):
		if _audio_panel.is_playing():
			_audio_panel.stop_and_close()
		if _audio_panel_owned:
			_audio_panel.queue_free()
