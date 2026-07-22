extends CanvasLayer

signal menu_closed

# --- Node References ---
@onready var overlay: ColorRect = $Overlay
@onready var menu_panel: Control = $MenuPanel
@onready var total_words_label: Label = $MenuPanel/MarginContainer/VBoxContainer/TotalWordsLabel
@onready var word_list: VBoxContainer = $MenuPanel/MarginContainer/VBoxContainer/ScrollContainer/WordList

var ENG_FONT : Font = load("res://assets/fonts/PlusJakartaSans-Medium.ttf")
var FARSI_FONT : Font = load("res://assets/fonts/Vazirmatn-Regular.ttf")

# متغیری برای ذخیره انیمیشن فعلی تا تداخلی پیش نیاید
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
	menu_closed_position = -menu_panel.size.x  # Off-screen left
	menu_open_position = 0  # At screen's left edge
	
	# Set initial position (off-screen left)
	menu_panel.position.x = menu_closed_position
	
	# Now show the menu (it's off-screen so won't be visible)
	menu_panel.visible = true
	
	overlay.gui_input.connect(_on_overlay_gui_input)

func set_hamburger_button(button: Button) -> void:
	hamburger_button = button
	hamburger_original_position = hamburger_button.position

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	_populate_list()
	if is_open: 
		return
	
	is_open = true
	overlay.visible = true
	
	if tween: 
		tween.kill()
	
	tween = create_tween().set_parallel(true)
	
	# Move panel from left (off-screen) to fully open
	tween.tween_property(menu_panel, "position:x", menu_open_position, 0.4)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade in overlay
	tween.tween_property(overlay, "modulate:a", 0.5, 0.4)
	
	if hamburger_button:
		# Move hamburger button to stay at the right edge of the menu panel
		var target_btn_x = menu_panel.size.x - hamburger_original_position.x
		tween.tween_property(hamburger_button, "position:x", target_btn_x, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not is_open: 
		return
	
	is_open = false
	
	if tween: 
		tween.kill()
	
	tween = create_tween().set_parallel(true)
	
	# Move panel back off-screen left
	tween.tween_property(menu_panel, "position:x", menu_closed_position, 0.4)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Fade out overlay
	tween.tween_property(overlay, "modulate:a", 0.0, 0.4)
	
	if hamburger_button:
		# Return hamburger button to the original position (stuck to the menu panel)
		var target_btn_x = hamburger_original_position.x
		tween.tween_property(hamburger_button, "position:x", target_btn_x, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(hamburger_button, "rotation_degrees", 0.0, 0.4)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Hide overlay after animation completes
	tween.chain().tween_callback(func(): overlay.visible = false)

func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

		
# ==========================================
# بقیه متدهای شما (بدون تغییر باقی می‌مانند)
# ==========================================
func _populate_list() -> void:
	for child in word_list.get_children():
		child.queue_free()
		
	var review_words: Array = Global.get_review_words()
	_update_total_count(review_words.size())
	
	for entry in review_words:
		_create_word_item(entry)

func _create_word_item(entry: Dictionary) -> void:
	var item_box = HBoxContainer.new()
	item_box.alignment = BoxContainer.ALIGNMENT_CENTER
	item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var word_label = Label.new()
	word_label.text = entry.get("word", "Unknown")
	word_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if ENG_FONT:
		word_label.add_theme_font_override("font", ENG_FONT)
	
	# Set font size
	word_label.add_theme_font_size_override("font_size", 45)

	
	var delete_btn = Button.new()
	delete_btn.text = "حذف"
	delete_btn.modulate = Color("#EF4444") 
	
	if FARSI_FONT:
		delete_btn.add_theme_font_override("font", FARSI_FONT)
	
	# Set font size
	delete_btn.add_theme_font_size_override("font_size", 45)
	delete_btn.add_theme_color_override("font_color", Color("000000ff"))
	
	# --- START: Add Corner Radius Styling ---
	var style_box_normal = StyleBoxFlat.new()
	style_box_normal.bg_color = Color("#EF4444") # Background color for normal state
	style_box_normal.set_corner_radius_all(30)   # Corner radius of 30
	style_box_normal.set_border_width_all(0)    # Remove border if you want smooth edges
	
	var style_box_hover = style_box_normal.duplicate()
	style_box_hover.bg_color = Color("#DC2626") # Slightly darker red for hover
	style_box_hover.set_corner_radius_all(30)
	
	var style_box_pressed = style_box_normal.duplicate()
	style_box_pressed.bg_color = Color("#B91C1C") # Even darker red for pressed
	style_box_pressed.set_corner_radius_all(30)
	
	# --- START: Add Corner Radius Styling ---
	style_box_normal.bg_color = Color("#EF4444")
	style_box_normal.set_corner_radius_all(30)
	style_box_normal.set_border_width_all(0)
	style_box_normal.content_margin_left = 15
	style_box_normal.content_margin_right = 15
	style_box_normal.content_margin_top = 5
	style_box_normal.content_margin_bottom = 5

	style_box_hover.bg_color = Color("#DC2626")

	style_box_pressed.bg_color = Color("#B91C1C")

	# Apply the style overrides using proper methods
	delete_btn.add_theme_stylebox_override("normal", style_box_normal)
	delete_btn.add_theme_stylebox_override("hover", style_box_hover)
	delete_btn.add_theme_stylebox_override("pressed", style_box_pressed)
	# --- END: Add Corner Radius Styling ---

	
	delete_btn.pressed.connect(func(): _on_delete_word_pressed(entry, item_box))
	
	item_box.add_child(word_label)
	item_box.add_child(delete_btn)
	
	word_list.add_child(item_box)


func _on_delete_word_pressed(entry: Dictionary, item_node: Node) -> void:
	var word: String = entry.get("word", "")
	var book: int = entry.get("book", 0)
	var lesson: int = entry.get("lesson", 0)
	
	Global.remove_review_word(word, book, lesson)
	item_node.queue_free()
	
	var new_count = Global.get_review_words().size()
	_update_total_count(new_count)

func _update_total_count(count: int) -> void:
	total_words_label.text = "تعداد کل کلمات در مرور: %d" % count
