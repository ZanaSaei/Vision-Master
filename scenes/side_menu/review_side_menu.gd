extends CanvasLayer
signal word_selected(word_data)  # New signal for when a word is selected from search

# --- Node References ---
@onready var overlay: ColorRect = $Overlay
@onready var menu_panel: Control = $MenuPanel
@onready var total_words_label: Label = $MenuPanel/MarginContainer/VBoxContainer/TotalWordsLabel
@onready var word_list: VBoxContainer = $MenuPanel/MarginContainer/VBoxContainer/ScrollContainer/WordList

# New search-related nodes
@onready var search_container: HBoxContainer = $MenuPanel/MarginContainer/VBoxContainer/SearchContainer
@onready var search_input: LineEdit = $MenuPanel/MarginContainer/VBoxContainer/SearchContainer/SearchInput
@onready var clear_search_button: Button = $MenuPanel/MarginContainer/VBoxContainer/SearchContainer/ClearSearchButton

var ENG_FONT : Font = load("res://assets/fonts/PlusJakartaSans-Medium.ttf")
var FARSI_FONT : Font = load("res://assets/fonts/Vazirmatn-Regular.ttf")

# متغیری برای ذخیره انیمیشن فعلی تا تداخلی پیش نیاید
var is_open := false
var tween: Tween
var hamburger_button: Button
var hamburger_original_position: Vector2
var menu_closed_position: float
var menu_open_position: float

# Search state
var is_searching := false
var current_search_results: Array = []
var all_review_words: Array = []

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
	
	# Setup search
	search_input.text_changed.connect(_on_search_text_changed)
	clear_search_button.pressed.connect(_clear_search)
	
	# Connect to Global signal to update list when review words change
	Global.review_words_changed.connect(_on_review_words_changed)
	
	# Initially hide clear button
	clear_search_button.visible = false

func set_hamburger_button(button: Button) -> void:
	hamburger_button = button
	hamburger_original_position = hamburger_button.position

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	# Refresh data when opening
	_refresh_data()
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
	
	# Clear search when opening menu
	_clear_search()
	# Focus on search input after animation
	tween.tween_callback(func(): 
		if search_input:
			search_input.grab_focus()
	)

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
# SEARCH SYSTEM
# ==========================================

func _refresh_data() -> void:
	"""Refresh the all_review_words cache"""
	all_review_words = Global.get_review_words()
	current_search_results = []

func _on_review_words_changed() -> void:
	"""Called when review words change - refresh the list"""
	_refresh_data()
	if is_searching and search_input.text != "":
		_perform_search(search_input.text)
	else:
		_populate_list()

func _on_search_text_changed(new_text: String) -> void:
	if new_text == "":
		_clear_search()
		return
	
	is_searching = true
	clear_search_button.visible = true
	_perform_search(new_text)

func _perform_search(query: String) -> void:
	"""Search through review words and display results"""
	var trimmed_query = query.strip_edges().to_lower()
	if trimmed_query == "":
		_clear_search()
		return
	
	current_search_results = []
	
	# Search through all review words
	for entry in all_review_words:
		var word = entry.get("word", "").to_lower()
		var meaning_en = entry.get("meaning_en", "").to_lower()
		var meaning_fa = entry.get("meaning_fa", "").to_lower()
		
		# Check if the query matches word, English meaning, or Persian meaning
		if word.find(trimmed_query) != -1 or \
		   meaning_en.find(trimmed_query) != -1 or \
		   meaning_fa.find(trimmed_query) != -1:
			current_search_results.append(entry)
	
	# Update the word count label
	_update_total_count(current_search_results.size(), true)
	
	# Clear and repopulate the word list with search results
	_clear_word_list()
	for entry in current_search_results:
		_create_word_item(entry, true)  # true = search result mode

func _clear_search() -> void:
	"""Clear the search and show all words"""
	is_searching = false
	search_input.text = ""
	clear_search_button.visible = false
	current_search_results = []
	_populate_list()
	# Remove focus from search input
	if search_input:
		search_input.release_focus()

func _clear_word_list() -> void:
	"""Clear all children from the word list"""
	for child in word_list.get_children():
		child.queue_free()

# ==========================================
# WORD LIST POPULATION
# ==========================================

func _populate_list() -> void:
	"""Populate the word list with all review words"""
	_clear_word_list()
	
	var review_words: Array = Global.get_review_words()
	_update_total_count(review_words.size(), false)
	
	for entry in review_words:
		_create_word_item(entry, false)  # false = normal mode

func _create_word_item(entry: Dictionary, is_search_result: bool = false) -> void:
	var item_box = HBoxContainer.new()
	item_box.alignment = BoxContainer.ALIGNMENT_CENTER
	item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add click behavior to select word
	item_box.gui_input.connect(_on_word_item_clicked.bind(entry, item_box))
	
	# Word label
	var word_label = Label.new()
	word_label.text = entry.get("word", "Unknown")
	word_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if ENG_FONT:
		word_label.add_theme_font_override("font", ENG_FONT)
	
	# Set font size
	word_label.add_theme_font_size_override("font_size", 45)
	
	# Add search highlight if this is a search result
	if is_search_result and search_input.text != "":
		word_label.add_theme_color_override("font_color", Color("#3B82F6"))  # Blue highlight
	
	# Delete button
	var delete_btn = Button.new()
	delete_btn.text = "حذف"
	delete_btn.modulate = Color("#EF4444") 
	
	if FARSI_FONT:
		delete_btn.add_theme_font_override("font", FARSI_FONT)
	
	# Set font size
	delete_btn.add_theme_font_size_override("font_size", 45)
	delete_btn.add_theme_color_override("font_color", Color("000000ff"))
	
	# Add Corner Radius Styling
	var style_box_normal = StyleBoxFlat.new()
	style_box_normal.bg_color = Color("#EF4444")
	style_box_normal.set_corner_radius_all(30)
	style_box_normal.set_border_width_all(0)
	style_box_normal.content_margin_left = 15
	style_box_normal.content_margin_right = 15
	style_box_normal.content_margin_top = 5
	style_box_normal.content_margin_bottom = 5

	var style_box_hover = style_box_normal.duplicate()
	style_box_hover.bg_color = Color("#DC2626")

	var style_box_pressed = style_box_normal.duplicate()
	style_box_pressed.bg_color = Color("#B91C1C")

	# Apply the style overrides
	delete_btn.add_theme_stylebox_override("normal", style_box_normal)
	delete_btn.add_theme_stylebox_override("hover", style_box_hover)
	delete_btn.add_theme_stylebox_override("pressed", style_box_pressed)
	
	delete_btn.pressed.connect(func(): _on_delete_word_pressed(entry, item_box))
	
	item_box.add_child(word_label)
	item_box.add_child(delete_btn)
	
	word_list.add_child(item_box)

func _on_word_item_clicked(event: InputEvent, entry: Dictionary, _item_node: Node) -> void:
	"""Handle clicking on a word item to navigate to it"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Emit signal that a word was selected
		word_selected.emit(entry)
		# Close the menu
		close()

func _on_delete_word_pressed(entry: Dictionary, item_node: Node) -> void:
	var word: String = entry.get("word", "")
	var book: int = entry.get("book", 0)
	var lesson: int = entry.get("lesson", 0)
	
	Global.remove_review_word(word, book, lesson)
	item_node.queue_free()
	
	# Refresh the list if in search mode
	if is_searching:
		current_search_results.erase(entry)
		_update_total_count(current_search_results.size(), true)
		# If no results left, clear search
		if current_search_results.is_empty():
			_clear_search()
	else:
		var new_count = Global.get_review_words().size()
		_update_total_count(new_count, false)

func _update_total_count(count: int, is_search: bool = false) -> void:
	if is_search:
		var query = search_input.text.strip_edges()
		if query != "":
			# فقط تعداد کلمات را نشان می‌دهیم بدون نمایش کلمه جستجو شده
			total_words_label.text = "%d کلمه یافت شد" % count
		else:
			total_words_label.text = "تعداد کل کلمات در مرور: %d" % count
	else:
		total_words_label.text = "تعداد کل کلمات در مرور: %d" % count

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

func focus_search() -> void:
	"""Focus the search input field"""
	if search_input:
		search_input.grab_focus()
