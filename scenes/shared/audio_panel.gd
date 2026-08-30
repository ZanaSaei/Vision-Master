extends PanelContainer

signal playback_updated(current_time: float)
signal audio_closed
signal audio_finished

const SEEK_STEP: float = 10.0 #
var is_dragging_slider: bool = false #

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_slider: HSlider = $MarginContainer/AudioUILayout/AudioSlider
@onready var rewind_button: Button = $MarginContainer/AudioUILayout/ControlsLayout/RewindButton
@onready var play_pause_button: Button = $MarginContainer/AudioUILayout/ControlsLayout/PlayPauseButton
@onready var forward_button: Button = $MarginContainer/AudioUILayout/ControlsLayout/ForwardButton
@onready var close_audio_button: Button = $MarginContainer/AudioUILayout/ControlsLayout/CloseAudioButton

func _ready() -> void:
	# Connect internal signals[cite: 2, 3]
	rewind_button.pressed.connect(_on_rewind_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	forward_button.pressed.connect(_on_forward_pressed)
	close_audio_button.pressed.connect(_on_close_audio_pressed)
	
	audio_slider.drag_started.connect(_on_slider_drag_started)
	audio_slider.drag_ended.connect(_on_slider_drag_ended)
	audio_player.finished.connect(_on_audio_finished)

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Global.get_theme_color("accent") if Global.theme_is_dark() else Global.get_theme_color("surface")
	panel_sb.corner_radius_top_left = 150
	panel_sb.corner_radius_top_right = 150
	add_theme_stylebox_override("panel", panel_sb)


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()

func _process(_delta: float) -> void:
	# Broadcast the current time for syncing text[cite: 2, 3]
	if (audio_player.playing or audio_player.stream_paused) and not is_dragging_slider:
		var current_time = audio_player.get_playback_position()
		audio_slider.value = current_time
		playback_updated.emit(current_time)

# ==========================================
# PUBLIC API (Called by Parent Scenes)
# ==========================================
func load_and_play(audio_path: String) -> void:
	if audio_path == "" or not ResourceLoader.exists(audio_path):
		push_warning("Audio not found: " + audio_path)
		return
		
	show()
	audio_player.stream = load(audio_path)
	audio_player.play()
	audio_player.stream_paused = false
	play_pause_button.text = "Pause"
	audio_slider.max_value = audio_player.stream.get_length()
	audio_slider.value = 0.0

func stop_and_close() -> void:
	_on_close_audio_pressed()

func is_playing() -> bool:
	return audio_player.playing or audio_player.stream_paused

# ==========================================
# INTERNAL EVENT HANDLERS
# ==========================================
func _on_play_pause_pressed() -> void:
	if audio_player.stream == null: return
	
	if audio_player.stream_paused:
		audio_player.stream_paused = false
		play_pause_button.text = "Pause"
		if not audio_player.playing: 
			audio_player.play(audio_slider.value)
	elif audio_player.playing:
		audio_player.stream_paused = true
		play_pause_button.text = "Play"

func _on_rewind_pressed() -> void:
	if audio_player.stream != null:
		audio_player.seek(max(0.0, audio_player.get_playback_position() - SEEK_STEP)) #[cite: 2, 3]
		audio_slider.value = audio_player.get_playback_position()

func _on_forward_pressed() -> void:
	if audio_player.stream != null:
		var max_len = audio_player.stream.get_length()
		audio_player.seek(min(max_len, audio_player.get_playback_position() + SEEK_STEP)) #[cite: 2, 3]
		audio_slider.value = audio_player.get_playback_position()

func _on_close_audio_pressed() -> void:
	audio_player.stop() #[cite: 2, 3]
	audio_player.stream_paused = false #[cite: 2, 3]
	audio_slider.value = 0.0 #[cite: 2, 3]
	hide()
	audio_closed.emit()

func _on_audio_finished() -> void:
	play_pause_button.text = "Play" #[cite: 2, 3]
	audio_finished.emit()

func _on_slider_drag_started() -> void: 
	is_dragging_slider = true #[cite: 2, 3]

func _on_slider_drag_ended(_value_changed: bool) -> void:
	is_dragging_slider = false #[cite: 2, 3]
	if audio_player.stream != null: 
		audio_player.seek(audio_slider.value) #[cite: 2, 3]
