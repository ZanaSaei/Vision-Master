extends PanelContainer

signal playback_updated(current_time: float)
signal audio_closed
signal audio_finished

const SEEK_STEP: float = 10.0 #
const TAP_PRESS_SCALE: Vector2 = Vector2(0.85, 0.85)
const TAP_PRESS_DURATION: float = 0.06
const TAP_RELEASE_DURATION: float = 0.26
var is_dragging_slider: bool = false #
var _transparent_tex: ImageTexture = null

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_slider: HSlider = $MarginContainer/AudioUILayout/TimeRow/AudioSlider
@onready var current_time_label: Label = $MarginContainer/AudioUILayout/TimeRow/CurrentTimeLabel
@onready var total_time_label: Label = $MarginContainer/AudioUILayout/TimeRow/TotalTimeLabel
@onready var rewind_button: TextureButton = $MarginContainer/AudioUILayout/ControlsLayout/RewindButton
@onready var play_pause_button: TextureButton = $MarginContainer/AudioUILayout/ControlsLayout/PlayPauseButton
@onready var forward_button: TextureButton = $MarginContainer/AudioUILayout/ControlsLayout/ForwardButton
@onready var close_audio_button: TextureButton = $MarginContainer/AudioUILayout/ControlsLayout/CloseAudioButton

func _ready() -> void:
	# Connect internal signals[cite: 2, 3]
	rewind_button.pressed.connect(_on_rewind_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	forward_button.pressed.connect(_on_forward_pressed)
	close_audio_button.pressed.connect(_on_close_audio_pressed)
	
	audio_slider.drag_started.connect(_on_slider_drag_started)
	audio_slider.drag_ended.connect(_on_slider_drag_ended)
	audio_slider.value_changed.connect(_on_slider_value_changed)
	audio_player.finished.connect(_on_audio_finished)

	# Juicy tap animations on every control button.
	for button: TextureButton in [rewind_button, play_pause_button, forward_button, close_audio_button]:
		_wire_tap_animation(button)

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()
	_apply_slider_theme()
	_setup_animated_dot()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Global.get_theme_color("accent") if Global.theme_is_dark() else Global.get_theme_color("surface")
	panel_sb.corner_radius_top_left = 150
	panel_sb.corner_radius_top_right = 150
	add_theme_stylebox_override("panel", panel_sb)

	# Time labels (current on the left, total on the right).
	current_time_label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	total_time_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))


func _apply_slider_theme() -> void:
	if not is_inside_tree():
		return
	var dark: bool = Global.theme_is_dark()
	# Thick rounded track (unplayed portion).
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1.0, 1.0, 1.0, 0.28) if dark else Color(0.0, 0.0, 0.0, 0.12)
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	track.corner_radius_top_left = 10
	track.corner_radius_top_right = 10
	track.corner_radius_bottom_left = 10
	track.corner_radius_bottom_right = 10
	audio_slider.add_theme_stylebox_override("slider", track)
	# Played portion fill.
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE if dark else Global.get_theme_color("accent")
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	fill.corner_radius_top_left = 10
	fill.corner_radius_top_right = 10
	fill.corner_radius_bottom_left = 10
	fill.corner_radius_bottom_right = 10
	audio_slider.add_theme_stylebox_override("grabber_area", fill)
	audio_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	# The visible dot is drawn by an overlay (AudioSliderDot) so it can be hidden
	# and animated; the slider's own grabber stays invisible.
	audio_slider.add_theme_icon_override("grabber", _make_transparent_texture())
	audio_slider.add_theme_icon_override("grabber_highlight", _make_transparent_texture())
	# Center the grabber on the fill edge so the dot travels the full width
	# of the track (reaches the very start and the very end of the slide).
	audio_slider.add_theme_constant_override("center_grabber", 1)


func _setup_animated_dot() -> void:
	# Replace the slider's built-in grabber with an overlay dot that is only
	# visible (and animated) while the user touches the bar.
	var dot := AudioSliderDot.new()
	audio_slider.add_child(dot)
	dot.setup(audio_slider)

	audio_slider.drag_started.connect(dot.show_dot)
	audio_slider.drag_ended.connect(func(_changed: bool) -> void: dot.hide_dot())


func _make_transparent_texture() -> ImageTexture:
	if _transparent_tex == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
		_transparent_tex = ImageTexture.create_from_image(img)
	return _transparent_tex


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()
	_apply_slider_theme()

# ==========================================
# TAP ANIMATIONS
# ==========================================
func _wire_tap_animation(button: TextureButton) -> void:
	button.pivot_offset = button.size * 0.5
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.button_down.connect(func() -> void: _animate_button_press(button))
	button.button_up.connect(func() -> void: _animate_button_release(button))


func _animate_button_press(button: TextureButton) -> void:
	_stop_tap_tween(button)
	var tween: Tween = button.create_tween()
	button.set_meta("tap_tween", tween)
	tween.tween_property(button, "scale", TAP_PRESS_SCALE, TAP_PRESS_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_button_release(button: TextureButton) -> void:
	_stop_tap_tween(button)
	var tween: Tween = button.create_tween()
	button.set_meta("tap_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE, TAP_RELEASE_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_tap_tween(button: TextureButton) -> void:
	if button.has_meta("tap_tween"):
		var tween: Tween = button.get_meta("tap_tween") as Tween
		if is_instance_valid(tween):
			tween.kill()
		button.remove_meta("tap_tween")


func _reset_button_scales() -> void:
	for button: TextureButton in [rewind_button, play_pause_button, forward_button, close_audio_button]:
		_stop_tap_tween(button)
		button.scale = Vector2.ONE

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
	if audio_path == "":
		push_warning("Audio not found: " + audio_path)
		return

	# Content resolves the clip whether it is bundled (res://) or was
	# downloaded on demand into user://content/.
	var stream: AudioStream = null
	if Content.has_asset(audio_path):
		stream = Content.load_audio(audio_path)
	if stream == null:
		push_warning("Audio not available yet: " + audio_path)
		return

	show()
	_reset_button_scales()
	audio_player.stream = stream
	audio_player.play()
	audio_player.stream_paused = false
	audio_slider.max_value = stream.get_length()
	total_time_label.text = _format_time(stream.get_length())
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
		if not audio_player.playing: 
			audio_player.play(audio_slider.value)
	elif audio_player.playing:
		audio_player.stream_paused = true
	else:
		# Stream finished (or was stopped): hit play again to replay from the start.
		audio_slider.value = 0.0
		audio_player.play()

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
	_reset_button_scales()
	hide()
	audio_closed.emit()

func _on_audio_finished() -> void:
	# Snap the slider to the very end so the dot lands on the far edge.
	audio_slider.value = audio_slider.max_value
	audio_finished.emit()

func _on_slider_drag_started() -> void: 
	is_dragging_slider = true #[cite: 2, 3]

func _on_slider_drag_ended(_value_changed: bool) -> void:
	is_dragging_slider = false #[cite: 2, 3]
	if audio_player.stream != null: 
		audio_player.seek(audio_slider.value) #[cite: 2, 3]


func _on_slider_value_changed(value: float) -> void:
	current_time_label.text = _format_time(value)


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(floor(seconds)))
	var hours: int = floori(total / 3600.0)
	var minutes: int = floori((total % 3600) / 60.0)
	var secs: int = total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%d:%02d" % [minutes, secs]
