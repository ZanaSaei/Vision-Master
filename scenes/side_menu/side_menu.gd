extends CanvasLayer

signal menu_closed
signal profile_pressed
signal saved_words_pressed
signal purchase_pressed
signal settings_pressed
signal about_me_pressed

const SCENE_SAVED_WORDS  := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_SETTINGS     := "res://scenes/settings/Settings.tscn"

# --- Node References ---
@onready var overlay: ColorRect = $Overlay
@onready var menu_panel: Control = $MenuPanel

# Buttons
@onready var profile_button: Button = $MenuPanel/MarginContainer/VBoxContainer/ProfileButton
@onready var saved_words_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SavedWordsButton
@onready var purchase_button: Button = $MenuPanel/MarginContainer/VBoxContainer/PurchaseButton
@onready var settings_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var about_me_button: Button = $MenuPanel/MarginContainer/VBoxContainer/AboutMeButton

var is_open := false
var tween: Tween
var hamburger_button: Button
var hamburger_original_position: Vector2
var menu_closed_position: float
var menu_open_position: float

func _ready() -> void:
	# Hide menu immediately to prevent flash
	menu_panel.visible = false
	
	overlay.modulate.a = 0.0
	overlay.visible = false
	
	# Calculate positions based on viewport
	menu_closed_position = get_viewport().get_visible_rect().size.x  # Off-screen right
	menu_open_position = get_viewport().get_visible_rect().size.x - menu_panel.size.x  # Visible on left
	
	# Set initial position (off-screen right)
	menu_panel.position.x = menu_closed_position
	
	# Now show the menu (it's off-screen so won't be visible)
	menu_panel.visible = true
	
	overlay.gui_input.connect(_on_overlay_gui_input)
	
	profile_button.pressed.connect(func(): emit_signal("profile_pressed"); close())
	saved_words_button.pressed.connect(func(): emit_signal("saved_words_pressed"); close())
	purchase_button.pressed.connect(func(): emit_signal("purchase_pressed"); close())
	settings_button.pressed.connect(func(): emit_signal("settings_pressed"); close())
	about_me_button.pressed.connect(func(): emit_signal("about_me_pressed"); close())

func set_hamburger_button(button: Button) -> void:
	hamburger_button = button
	hamburger_original_position = hamburger_button.position

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open: 
		return
	
	is_open = true
	overlay.visible = true
	
	if tween: 
		tween.kill()
	
	tween = create_tween().set_parallel(true)
	
	# Move panel from right to left
	tween.tween_property(menu_panel, "position:x", menu_open_position, 0.4)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade in overlay
	tween.tween_property(overlay, "modulate:a", 0.5, 0.4)
	
	if hamburger_button:
		# Move hamburger button to stay at the right edge of the menu panel
		# The button should move left by the same amount as the panel, keeping it visible
		var target_btn_x = hamburger_original_position.x - menu_panel.size.x
		tween.tween_property(hamburger_button, "position:x", target_btn_x, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(hamburger_button, "rotation_degrees", 90.0, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not is_open: 
		return
	
	is_open = false
	
	if tween: 
		tween.kill()
	
	tween = create_tween().set_parallel(true)
	
	# Move panel back off-screen right
	tween.tween_property(menu_panel, "position:x", menu_closed_position, 0.4)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade out overlay
	tween.tween_property(overlay, "modulate:a", 0.0, 0.4)
	
	if hamburger_button:
		# Return hamburger button to original position
		tween.tween_property(hamburger_button, "position:x", hamburger_original_position.x, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(hamburger_button, "rotation_degrees", 0.0, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Hide overlay after animation completes
	tween.chain().tween_callback(func(): overlay.visible = false)

func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
