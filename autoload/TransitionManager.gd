extends CanvasLayer

# ============================================================
#  TRANSITION MANAGER
#  Handles fade in/fade out scene transitions
# ============================================================

var transition_color := Color.BLACK
var fade_duration := 0.2  # Duration of fade in/out

var color_rect: ColorRect


func _ready() -> void:
	# Create the ColorRect programmatically
	color_rect = ColorRect.new()
	color_rect.color = transition_color
	color_rect.visible = false
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Make it fill the entire screen
	color_rect.anchor_left = 0.0
	color_rect.anchor_top = 0.0
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	add_child(color_rect)


func change_scene(scene_path: String) -> void:
	# Fade out to black
	await _fade_out()
	
	# Change the scene
	get_tree().change_scene_to_file(scene_path)
	
	# Wait for the scene to load
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Fade in from black
	await _fade_in()


func _fade_out() -> void:
	color_rect.visible = true
	color_rect.color = Color(0, 0, 0, 0)  # Start fully transparent
	
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, fade_duration)  # Fade to fully opaque
	await tween.finished


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, fade_duration)  # Fade to fully transparent
	await tween.finished
	
	color_rect.visible = false
