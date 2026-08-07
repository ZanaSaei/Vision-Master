extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  WORD REVIEW SCENE — Anki-style spaced repetition
#  Replaces the old Quiz scene for reviewing saved words.
#
#  Flow per card:
#    1. Show word only (Front)
#    2. User taps "Show Answer" → reveals Back (meaning/example/etc.)
#    3. User rates Again / Hard / Good / Easy
#    4. Word is rescheduled via Global.review_word()
#       "Again" comes back later in the SAME session.
#       Hard/Good/Easy schedule it for a future day.
#    5. Repeat until the due queue for today is empty.
# ============================================================

const SCENE_SAVED_WORDS := "res://scenes/saved_words/SavedWords.tscn"

@onready var back_button: Button           = $HeaderBar/MarginContainer/Header/BackButton
@onready var due_counter: Label            = $HeaderBar/MarginContainer/Header/DueCounter
@onready var review_side_menu              = $ReviewSideMenu
@onready var open_list_menu_button: Button = $OpenListMenuButton

@onready var card_panel: PanelContainer    = $MarginContainer/MainLayout/CardMargin/CardPanel
@onready var front: PanelContainer        = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/Front
@onready var word_label: Label             = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/Front/WordLabel

@onready var back: VBoxContainer           = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/BackFace
@onready var type_label: Label             = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/BackFace/WordRow/WordRowContent/BackWordLabel
@onready var meaning_label: Label          = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/BackFace/MeaningFaRow/MeaningFaRowContent/MeaningFaLabel
@onready var example_label: Label          = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/BackFace/ExampleRow/ExampleRowContent/ExampleLabel
@onready var extra_label: Label            = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/BackFace/Extra/ExtraRowContent/ExtraLabel
@onready var phonetics_label: Label        = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/BackFace/PhoneticsRow/PhoneticsRowContent/PhoneticsLabel

@onready var show_answer_button: Button    = $MarginContainer/MainLayout/Controls/ShowAnswerButton
@onready var rating_buttons: HBoxContainer = $MarginContainer/MainLayout/Controls/RatingButtons
@onready var again_button: Button          = $MarginContainer/MainLayout/Controls/RatingButtons/Again
@onready var hard_button: Button           = $MarginContainer/MainLayout/Controls/RatingButtons/Hard
@onready var good_button: Button           = $MarginContainer/MainLayout/Controls/RatingButtons/Good
@onready var easy_button: Button           = $MarginContainer/MainLayout/Controls/RatingButtons/Easy


var review_queue: Array       = []
var current_entry: Dictionary = {}


func _ready() -> void:
	Global.review_words_changed.connect(_on_review_words_changed)
	back_button.pressed.connect(_on_back_button_pressed)
	show_answer_button.pressed.connect(_on_show_answer_pressed)
	again_button.pressed.connect(_on_rate_pressed.bind("again"))
	hard_button.pressed.connect(_on_rate_pressed.bind("hard"))
	good_button.pressed.connect(_on_rate_pressed.bind("good"))
	easy_button.pressed.connect(_on_rate_pressed.bind("easy"))
	
	# Connect the new word_selected signal
	review_side_menu.word_selected.connect(_on_word_selected_from_menu)
	
	# متصل کردن دکمه باز کردن منو
	review_side_menu.set_hamburger_button(open_list_menu_button)
	open_list_menu_button.pivot_offset = open_list_menu_button.size / 2.0 
	
	open_list_menu_button.pressed.connect(review_side_menu.toggle)
	
	_style_rating_buttons()

	review_queue = Global.get_due_words()
	_load_next_card()
	_populate_word_list()

# Add this new function to handle word selection
func _on_word_selected_from_menu(word_data: Dictionary) -> void:
	"""Navigate to a specific word in the review queue"""
	# Find the word in the queue
	for i in range(review_queue.size()):
		var entry = review_queue[i]
		if entry.get("word") == word_data.get("word") and \
		   entry.get("book") == word_data.get("book") and \
		   entry.get("lesson") == word_data.get("lesson"):
			# Reorder queue to put this word first
			var temp = review_queue[i]
			review_queue.remove_at(i)
			review_queue.insert(0, temp)
			_load_next_card()
			return
	
	# If word not found in queue, reload queue and try again
	review_queue = Global.get_due_words()
	for entry in review_queue:
		if entry.get("word") == word_data.get("word") and \
		   entry.get("book") == word_data.get("book") and \
		   entry.get("lesson") == word_data.get("lesson"):
			_load_next_card()
			return

func _on_review_words_changed():
	# This will be called every time a word is added or removed
	_populate_word_list()   # re‑reads Global.review_words and updates UI

func _populate_word_list() -> void:
	review_queue = Global.get_due_words()
	_load_next_card()
	_update_due_counter()


func _on_review_menu_closed() -> void:
	# گرفتن مجدد صف کلمات از گلوبال در صورتی که لیست تغییر کرده باشد
	review_queue = Global.get_due_words()
	_load_next_card()

# ----------------------------------------------------------------
#  VISUAL STYLING FOR RATING BUTTONS (Anki's standard color code)
# ----------------------------------------------------------------
func _style_rating_buttons() -> void:
	_apply_button_color(again_button, Color("#EF4444"))  # red
	_apply_button_color(hard_button,  Color("#F59E0B"))  # orange
	_apply_button_color(good_button,  Color("#22C55E"))  # green
	_apply_button_color(easy_button,  Color("#2563EB"))  # blue

	for btn in [again_button, hard_button, good_button, easy_button]:
		btn.add_theme_color_override("font_color", Color("#FFFFFF"))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.custom_minimum_size = Vector2(200, 100)  # Ensure buttons have size


func _apply_button_color(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = color
	style.corner_radius_top_left     = 14
	style.corner_radius_top_right    = 14
	style.corner_radius_bottom_left  = 14
	style.corner_radius_bottom_right = 14
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)

	var hover := style.duplicate()
	hover.bg_color = color.darkened(0.12)
	btn.add_theme_stylebox_override("hover", hover)


# ----------------------------------------------------------------
#  CARD FLOW
# ----------------------------------------------------------------
func _load_next_card() -> void:
	_update_due_counter()

	if review_queue.is_empty():
		_show_all_done()
		return

	current_entry = review_queue[0]

	word_label.text    = current_entry.get("word", "")
	meaning_label.text = "%s\n%s" % [
		current_entry.get("meaning_en", ""),
		current_entry.get("meaning_fa", "")
	]
	example_label.text = current_entry.get("example", "")

	var phonetics_text: String = current_entry.get("phonetics", "")
	if phonetics_text != "":
		phonetics_label.text = phonetics_text
		phonetics_label.visible = true
	else:
		phonetics_label.text = ""
		phonetics_label.visible = false

	var book: int   = current_entry.get("book", 0)
	var lesson: int = current_entry.get("lesson", 0)
	extra_label.text = ("Vision %d — Lesson %d" % [book, lesson]) if book > 0 else ""

	type_label.text = _get_state_badge(current_entry)

	_show_front()


# Shows a badge describing where this word is in its learning journey
func _get_state_badge(entry: Dictionary) -> String:
	Global._ensure_srs_fields(entry)
	var due: int  = entry.get("srs_due", -1)
	var reps: int = entry.get("srs_reps", 0)

	if due == -1:
		return "🆕 کلمه جدید"
	elif reps < 2:
		return "🔁 در حال یادگیری"
	else:
		return "✅ مرور"


func _show_front() -> void:
	front.visible           = true
	back.visible             = false
	show_answer_button.visible = true
	rating_buttons.visible     = false


func _on_show_answer_pressed() -> void:
	front.visible              = false
	back.visible               = true
	show_answer_button.visible = false
	rating_buttons.visible     = true
	
	# Make sure rating buttons are properly positioned and visible
	rating_buttons.show()
	rating_buttons.modulate = Color(1, 1, 1, 1)
	
	_update_rating_previews()


# Shows "in 1 day / 3 days / ..." on each rating button so the student
# understands the consequence of each choice, just like real Anki.
func _update_rating_previews() -> void:
	var previews: Dictionary = Global.preview_intervals(current_entry)
	again_button.text = "دوباره\n(%s)" % previews["again"]
	hard_button.text  = "سخت\n(%s)"   % previews["hard"]
	good_button.text  = "خوب\n(%s)"   % previews["good"]
	easy_button.text  = "آسان\n(%s)"  % previews["easy"]


func _on_rate_pressed(rating: String) -> void:
	Global.review_word(
		current_entry.get("word", ""),
		current_entry.get("book", 0),
		current_entry.get("lesson", 0),
		rating
	)

	review_queue.pop_front()

	# "Again" words come back later in the SAME session, not tomorrow
	if rating == "again":
		review_queue.append(current_entry)

	_load_next_card()


func _update_due_counter() -> void:
	due_counter.text = "%d کلمه باقی مانده" % review_queue.size()


# ----------------------------------------------------------------
#  SESSION COMPLETE STATE
# ----------------------------------------------------------------
func _show_all_done() -> void:
	word_label.text    = "🎉\nهمه‌ی کلمات مرور شده!\nفردا دوباره سر بزن."
	front.visible               = true
	back.visible                 = false
	show_answer_button.visible   = false
	rating_buttons.visible       = false

	due_counter.text = "تمام شد ✅"


func _on_back_button_pressed() -> void:
	# Return to whichever scene opened this review session
	var target: String = Global.word_review_return
	if target == "":
		target = SCENE_SAVED_WORDS   # safe fallback if never set
	TransitionManager.change_scene(target)
	
	# Keep the little press feedback
	var tween = create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
