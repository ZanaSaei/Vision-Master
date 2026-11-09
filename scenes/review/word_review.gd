extends "res://autoload/BackButtonHandler.gd"

# ============================================================
#  WORD REVIEW SCENE — Enhanced Anki-Style Spaced Repetition (SRS)
#  Modernized Leitner Review System for Vision Master
#
#  Features:
#    * 3D-style smooth card flip animation with spring physics
#    * Card slide & pop transitions on rating
#    * Session progress bar & due / new card badges
#    * Native audio & pronunciation player with auto-play toggle
#    * Rich card layout: Persian & English definitions, examples,
#      synonyms, antonyms, phonetics & part-of-speech badges
#    * Interactive celebration summary on session completion
#    * Helpful empty state with direct navigation to vocabularies
#    * Full keyboard / hotkey shortcuts (Desktop & Tablet)
#    * Complete Theme awareness (Dark & Light) via DesignTokens
# ============================================================

const SCENE_SAVED_WORDS := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_FLASHCARDS  := "res://scenes/vocabulary/FlashcardHub.tscn"

# --- Header & Navigation ---
@onready var back_button: Button            = $HeaderBar/MarginContainer/Header/BackButton
@onready var due_counter: Label             = $HeaderBar/MarginContainer/Header/DueCounter
@onready var auto_audio_toggle: Button      = $HeaderBar/MarginContainer/Header/AutoAudioToggle
@onready var header_title: Label            = $HeaderBar/MarginContainer/Header/HeaderTitle
@onready var background_color: ColorRect    = $BackgroundColor

# --- Progress Bar & Stats ---
@onready var progress_section: VBoxContainer   = $MarginContainer/MainLayout/ProgressSection
@onready var progress_count_label: Label       = $MarginContainer/MainLayout/ProgressSection/ProgressHeader/ProgressCountLabel
@onready var new_badge: Label                  = $MarginContainer/MainLayout/ProgressSection/ProgressHeader/BadgesContainer/NewBadge
@onready var due_badge: Label                  = $MarginContainer/MainLayout/ProgressSection/ProgressHeader/BadgesContainer/DueBadge
@onready var session_progress_bar: ProgressBar = $MarginContainer/MainLayout/ProgressSection/ProgressBar

# --- Card Structure ---
@onready var card_panel: PanelContainer        = $MarginContainer/MainLayout/CardMargin/CardPanel
@onready var stage_badge: Label                = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/CardHeader/StageBadge
@onready var word_type_badge: Label            = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/CardHeader/WordTypeBadge
@onready var audio_button: Button              = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/CardHeader/AudioButton
@onready var source_badge: Label               = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/CardHeader/SourceBadge

# --- Front Face ---
@onready var front: PanelContainer             = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/Front
@onready var word_label: Label                 = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/Front/FrontCenter/WordLabel
@onready var phonetics_label: Label            = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/Front/FrontCenter/PhoneticsLabel
@onready var tap_hint: Label                   = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/Front/FrontCenter/TapHint

# --- Back Face ---
@onready var back: ScrollContainer             = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace
@onready var back_word_label: Label            = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/WordRow/WordRowContent/BackWordLabel
@onready var back_phonetics_label: Label       = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/WordRow/WordRowContent/BackPhoneticsLabel
@onready var back_audio_button: Button         = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/WordRow/WordRowContent/BackAudioButton
@onready var meaning_fa_row: PanelContainer    = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/MeaningFaRow
@onready var meaning_label: Label              = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/MeaningFaRow/MeaningFaRowContent/MeaningFaLabel
@onready var meaning_en_row: PanelContainer    = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/MeaningEnRow
@onready var meaning_en_label: Label           = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/MeaningEnRow/MeaningEnRowContent/MeaningEnLabel
@onready var example_row: PanelContainer       = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/ExampleRow
@onready var example_label: Label              = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/ExampleRow/ExampleRowContent/ExampleLabel
@onready var tags_row: PanelContainer          = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/TagsRow
@onready var synonyms_label: Label             = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/TagsRow/TagsContent/SynonymsLabel
@onready var antonyms_label: Label             = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/TagsRow/TagsContent/AntonymsLabel
@onready var flip_back_button: Button          = $MarginContainer/MainLayout/CardMargin/CardPanel/CardContent/CardVBox/BackFace/BackScrollContent/FlipBackButton

# --- Celebration Summary Card ---
@onready var summary_card: PanelContainer                = $MarginContainer/MainLayout/CardMargin/SummaryCard
@onready var total_reviewed_label: Label                 = $MarginContainer/MainLayout/CardMargin/SummaryCard/SummaryContent/StatsPanel/StatsVBox/TotalReviewedLabel
@onready var retention_rate_label: Label                 = $MarginContainer/MainLayout/CardMargin/SummaryCard/SummaryContent/StatsPanel/StatsVBox/RetentionRateLabel
@onready var stat_again: Label                           = $MarginContainer/MainLayout/CardMargin/SummaryCard/SummaryContent/StatsPanel/StatsVBox/BreakdownHBox/StatAgain
@onready var stat_hard: Label                            = $MarginContainer/MainLayout/CardMargin/SummaryCard/SummaryContent/StatsPanel/StatsVBox/BreakdownHBox/StatHard
@onready var stat_good: Label                            = $MarginContainer/MainLayout/CardMargin/SummaryCard/SummaryContent/StatsPanel/StatsVBox/BreakdownHBox/StatGood
@onready var stat_easy: Label                            = $MarginContainer/MainLayout/CardMargin/SummaryCard/SummaryContent/StatsPanel/StatsVBox/BreakdownHBox/StatEasy
@onready var summary_back_button: Button                 = $MarginContainer/MainLayout/CardMargin/SummaryCard/SummaryContent/SummaryActions/SummaryBackButton
@onready var summary_review_again_button: Button         = $MarginContainer/MainLayout/CardMargin/SummaryCard/SummaryContent/SummaryActions/SummaryReviewAgainButton

# --- Empty Card ---
@onready var empty_card: PanelContainer                  = $MarginContainer/MainLayout/CardMargin/EmptyCard
@onready var go_vocab_button: Button                     = $MarginContainer/MainLayout/CardMargin/EmptyCard/EmptyContent/GoVocabButton

# --- Bottom Controls ---
@onready var controls: VBoxContainer           = $MarginContainer/MainLayout/Controls
@onready var show_answer_button: Button        = $MarginContainer/MainLayout/Controls/ShowAnswerButton
@onready var rating_buttons: HBoxContainer     = $MarginContainer/MainLayout/Controls/RatingButtons
@onready var again_button: Button              = $MarginContainer/MainLayout/Controls/RatingButtons/Again
@onready var hard_button: Button               = $MarginContainer/MainLayout/Controls/RatingButtons/Hard
@onready var good_button: Button               = $MarginContainer/MainLayout/Controls/RatingButtons/Good
@onready var easy_button: Button               = $MarginContainer/MainLayout/Controls/RatingButtons/Easy

# --- Side Menu ---
@onready var open_list_menu_button: Button     = $OpenListMenuButton
@onready var review_side_menu                  = $ReviewSideMenu

# --- State ---
var review_queue: Array       = []
var current_entry: Dictionary = {}
var is_animating: bool        = false
var is_card_flipped: bool     = false
var auto_audio_enabled: bool  = true
var _card_default_pos: Vector2 = Vector2.ZERO

# Session Statistics
var session_total_count: int      = 0
var session_completed_count: int  = 0
var stats_again: int              = 0
var stats_hard: int               = 0
var stats_good: int               = 0
var stats_easy: int               = 0

const MAX_SESSION_REQUEUES := 3
var _session_requeues: Dictionary = {}


func _ready() -> void:
	Global.review_words_changed.connect(_on_review_words_changed)
	back_button.pressed.connect(_on_back_button_pressed)
	show_answer_button.pressed.connect(_on_show_answer_pressed)
	again_button.pressed.connect(_on_rate_pressed.bind("again"))
	hard_button.pressed.connect(_on_rate_pressed.bind("hard"))
	good_button.pressed.connect(_on_rate_pressed.bind("good"))
	easy_button.pressed.connect(_on_rate_pressed.bind("easy"))
	
	audio_button.pressed.connect(_play_current_audio)
	back_audio_button.pressed.connect(_play_current_audio)
	auto_audio_toggle.pressed.connect(_toggle_auto_audio)
	flip_back_button.pressed.connect(func() -> void: _animate_flip(false))
	
	summary_back_button.pressed.connect(_on_back_button_pressed)
	summary_review_again_button.pressed.connect(_restart_session_practice)
	go_vocab_button.pressed.connect(_on_go_vocab_pressed)
	
	# Tap card to flip
	front.gui_input.connect(_on_front_gui_input)

	# Connect side menu
	review_side_menu.word_selected.connect(_on_word_selected_from_menu)
	review_side_menu.set_hamburger_button(open_list_menu_button)
	open_list_menu_button.pivot_offset = open_list_menu_button.size / 2.0
	open_list_menu_button.pressed.connect(review_side_menu.toggle)

	# Wire motion microinteractions
	_wire_interactive_motion()
	_style_rating_buttons()

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()

	# Record default layout position
	call_deferred("_cache_card_position")

	# Initialize queue & session
	_start_session()


func _cache_card_position() -> void:
	card_panel.pivot_offset = card_panel.size / 2.0
	_card_default_pos = card_panel.position


func _wire_interactive_motion() -> void:
	for btn: Button in [show_answer_button, again_button, hard_button, good_button, easy_button,
						audio_button, back_audio_button, summary_back_button, summary_review_again_button,
						go_vocab_button, auto_audio_toggle, back_button]:
		UiMotion.wire_microinteractions(btn)


# ----------------------------------------------------------------
#  KEYBOARD SHORTCUTS
# ----------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.keycode
	
	if key == KEY_ESCAPE:
		_on_back_button_pressed()
	elif key == KEY_SPACE or key == KEY_ENTER:
		if not is_card_flipped and show_answer_button.visible and not is_animating:
			_on_show_answer_pressed()
	elif key == KEY_1:
		if is_card_flipped and rating_buttons.visible and not is_animating:
			_on_rate_pressed("again")
	elif key == KEY_2:
		if is_card_flipped and rating_buttons.visible and not is_animating:
			_on_rate_pressed("hard")
	elif key == KEY_3:
		if is_card_flipped and rating_buttons.visible and not is_animating:
			_on_rate_pressed("good")
	elif key == KEY_4:
		if is_card_flipped and rating_buttons.visible and not is_animating:
			_on_rate_pressed("easy")
	elif key == KEY_R or key == KEY_P:
		_play_current_audio()


# ----------------------------------------------------------------
#  AUDIO & PRONUNCIATION
# ----------------------------------------------------------------
func _play_current_audio() -> void:
	if current_entry.is_empty():
		return
	var audio_fn: String = str(current_entry.get("audio", ""))
	var word_txt: String = str(current_entry.get("word", ""))
	Global.play_word_audio(audio_fn, word_txt)
	UiMotion.pop(audio_button, 1.15)
	UiMotion.pop(back_audio_button, 1.15)


func _toggle_auto_audio() -> void:
	auto_audio_enabled = not auto_audio_enabled
	auto_audio_toggle.text = "🔊" if auto_audio_enabled else "🔇"
	Sfx.click()


# ----------------------------------------------------------------
#  SESSION & QUEUE INITIALIZATION
# ----------------------------------------------------------------
func _start_session() -> void:
	review_queue = Global.get_due_words()
	session_total_count = review_queue.size()
	session_completed_count = 0
	stats_again = 0
	stats_hard = 0
	stats_good = 0
	stats_easy = 0
	_load_next_card()


func _restart_session_practice() -> void:
	Sfx.click()
	review_queue = Global.get_review_words()
	session_total_count = review_queue.size()
	session_completed_count = 0
	stats_again = 0
	stats_hard = 0
	stats_good = 0
	stats_easy = 0
	summary_card.visible = false
	empty_card.visible = false
	card_panel.visible = true
	controls.visible = true
	progress_section.visible = true
	_load_next_card()


# ----------------------------------------------------------------
#  CARD NAVIGATION & WORD SELECTION FROM SIDE MENU
# ----------------------------------------------------------------
func _on_word_selected_from_menu(word_data: Dictionary) -> void:
	for i in range(review_queue.size()):
		if _is_same_entry(review_queue[i], word_data):
			var temp = review_queue[i]
			review_queue.remove_at(i)
			review_queue.insert(0, temp)
			_load_next_card()
			return

	review_queue = Global.get_due_words()
	for i in range(review_queue.size()):
		if _is_same_entry(review_queue[i], word_data):
			var temp = review_queue[i]
			review_queue.remove_at(i)
			review_queue.insert(0, temp)
			_load_next_card()
			return
	_update_header_and_progress()


func _is_same_entry(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("word", "")) == str(b.get("word", "")) \
		and int(a.get("book", 0)) == int(b.get("book", 0)) \
		and int(a.get("lesson", 0)) == int(b.get("lesson", 0))


func _on_review_words_changed() -> void:
	var keep_key := _entry_key(current_entry) if not current_entry.is_empty() else ""
	review_queue = Global.get_due_words()
	if keep_key != "":
		for i in range(review_queue.size()):
			if _entry_key(review_queue[i]) == keep_key:
				var entry = review_queue[i]
				review_queue.remove_at(i)
				review_queue.insert(0, entry)
				break
	_load_next_card()


func _populate_word_list() -> void:
	_on_review_words_changed()


func _on_review_menu_closed() -> void:
	review_queue = Global.get_due_words()
	_load_next_card()


# ----------------------------------------------------------------
#  CARD LOADING & PRESENTATION
# ----------------------------------------------------------------
func _load_next_card() -> void:
	_update_header_and_progress()

	if review_queue.is_empty():
		if Global.review_words.is_empty():
			_show_no_words_saved()
		else:
			_show_all_done()
		return

	card_panel.visible = true
	summary_card.visible = false
	empty_card.visible = false
	controls.visible = true
	progress_section.visible = true

	current_entry = review_queue[0]
	var word_text: String = str(current_entry.get("word", ""))
	word_label.text = word_text
	back_word_label.text = word_text

	# Phonetics
	var phonetics_text: String = str(current_entry.get("phonetics", ""))
	if phonetics_text == "":
		phonetics_text = str(current_entry.get("pronunciation", ""))
	if phonetics_text != "":
		phonetics_label.text = phonetics_text
		phonetics_label.visible = true
		back_phonetics_label.text = "  " + phonetics_text
		back_phonetics_label.visible = true
	else:
		phonetics_label.text = ""
		phonetics_label.visible = false
		back_phonetics_label.visible = false

	# Word type
	var wtype: String = str(current_entry.get("word_type", "")).strip_edges()
	if wtype != "":
		word_type_badge.text = wtype
		word_type_badge.visible = true
	else:
		word_type_badge.visible = false

	# Stage Badge
	stage_badge.text = _get_state_badge(current_entry)

	# Source (Vision book & lesson)
	var book: int   = int(current_entry.get("book", 0))
	var lesson: int = int(current_entry.get("lesson", 0))
	if book > 0:
		source_badge.text = "Vision %d • درس %d" % [book, lesson]
		source_badge.visible = true
	else:
		source_badge.visible = false

	# Persian Meaning
	meaning_label.text = str(current_entry.get("meaning_fa", "")).strip_edges()

	# English Meaning
	var en_meaning: String = str(current_entry.get("meaning_en", "")).strip_edges()
	if en_meaning != "":
		meaning_en_label.text = en_meaning
		meaning_en_row.visible = true
	else:
		meaning_en_row.visible = false

	# Example Sentence
	var ex_text: String = str(current_entry.get("example", "")).strip_edges()
	if ex_text != "":
		example_label.text = ex_text
		example_row.visible = true
	else:
		example_row.visible = false

	# Synonyms & Antonyms
	var syn_text := _format_tags(current_entry.get("synonyms"))
	var ant_text := _format_tags(current_entry.get("antonyms"))
	if syn_text != "" or ant_text != "":
		tags_row.visible = true
		synonyms_label.text = "🔗 مترادف‌ها: " + syn_text if syn_text != "" else ""
		synonyms_label.visible = (syn_text != "")
		antonyms_label.text = "⚡ متضادها: " + ant_text if ant_text != "" else ""
		antonyms_label.visible = (ant_text != "")
	else:
		tags_row.visible = false

	# Reset faces
	_show_front()

	# Auto pronounce if enabled
	if auto_audio_enabled:
		_play_current_audio()


func _format_tags(data: Variant) -> String:
	if data is Array:
		var items: Array[String] = []
		for item in data:
			items.append(str(item))
		return ", ".join(items)
	elif data is Dictionary:
		var items: Array[String] = []
		if data.has("en") and data["en"] is Array:
			for item in data["en"]:
				items.append(str(item))
		if data.has("fa") and data["fa"] is Array:
			for item in data["fa"]:
				items.append(str(item))
		return ", ".join(items)
	elif data is String and data.strip_edges() != "":
		return data.strip_edges()
	return ""


func _get_state_badge(entry: Dictionary) -> String:
	Global._ensure_srs_fields(entry)
	var due: int  = int(entry.get("srs_due", -1))
	var reps: int = int(entry.get("srs_reps", 0))

	if due == -1:
		return "🆕 کلمه جدید"
	elif reps < 2:
		return "🔁 در حال یادگیری"
	else:
		return "🧠 مرور تثبیت"


func _show_front() -> void:
	is_card_flipped = false
	front.visible = true
	back.visible = false
	show_answer_button.visible = true
	rating_buttons.visible = false


func _show_back() -> void:
	is_card_flipped = true
	front.visible = false
	back.visible = true
	show_answer_button.visible = false
	rating_buttons.visible = true
	rating_buttons.modulate = Color.WHITE
	_update_rating_previews()


func _on_front_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_card_flipped and not is_animating:
			_animate_flip(true)


func _on_show_answer_pressed() -> void:
	_animate_flip(true)


func _animate_flip(to_back: bool) -> void:
	if is_animating:
		return
	is_animating = true
	card_panel.pivot_offset = card_panel.size / 2.0
	Sfx.click()

	var tw := create_tween()
	tw.tween_property(card_panel, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if to_back:
			_show_back()
		else:
			_show_front()
		card_panel.pivot_offset = card_panel.size / 2.0
	)
	tw.tween_property(card_panel, "scale:x", 1.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		is_animating = false
	)


func _update_rating_previews() -> void:
	var previews: Dictionary = Global.preview_intervals(current_entry)
	again_button.text = "دوباره\n(%s)" % previews.get("again", "همین حالا")
	hard_button.text  = "سخت\n(%s)"   % previews.get("hard", "امروز")
	good_button.text  = "خوب\n(%s)"   % previews.get("good", "۱ روز")
	easy_button.text  = "آسان\n(%s)"  % previews.get("easy", "۳ روز")


# ----------------------------------------------------------------
#  RATING & PROGRESSION LOGIC
# ----------------------------------------------------------------
func _on_rate_pressed(rating: String) -> void:
	if current_entry.is_empty() or is_animating:
		return
	_animate_rate_and_next(rating)


func _animate_rate_and_next(rating: String) -> void:
	is_animating = true
	card_panel.pivot_offset = card_panel.size / 2.0

	# Audio cue per rating
	match rating:
		"again":
			Sfx.wrong()
			stats_again += 1
		"hard":
			Sfx.click()
			stats_hard += 1
		"good":
			Sfx.correct()
			stats_good += 1
		"easy":
			Sfx.reward()
			stats_easy += 1

	session_completed_count += 1

	# Directional card slide
	var target_offset: float = -260.0 if (rating == "again" or rating == "hard") else 260.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card_panel, "position:x", _card_default_pos.x + target_offset, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card_panel, "modulate:a", 0.0, 0.14)

	tw.chain().tween_callback(func() -> void:
		_process_rating(rating)
		card_panel.position.x = _card_default_pos.x
		_load_next_card()
		card_panel.modulate.a = 1.0
		if not review_queue.is_empty():
			UiMotion.pop_in(card_panel)
		is_animating = false
	)


func _process_rating(rating: String) -> void:
	var key := _entry_key(current_entry)
	Global.review_word(
		str(current_entry.get("word", "")),
		int(current_entry.get("book", 0)),
		int(current_entry.get("lesson", 0)),
		rating
	)

	review_queue.pop_front()
	_session_requeues.erase(key)

	if rating == "again" and int(_session_requeues.get(key, 0)) < MAX_SESSION_REQUEUES:
		_session_requeues[key] = int(_session_requeues.get(key, 0)) + 1
		review_queue.append(current_entry.duplicate(true))


func _entry_key(entry: Dictionary) -> String:
	return "%s|%d|%d" % [
		str(entry.get("word", "")),
		int(entry.get("book", 0)),
		int(entry.get("lesson", 0))
	]


func _update_header_and_progress() -> void:
	var remaining: int = review_queue.size()
	due_counter.text = "%s کلمه باقی مانده" % MenuStyle.persian_digits(str(remaining)) \
		if remaining > 0 else "تمام شد ✅"

	# Count breakdown in remaining queue
	var new_count := 0
	var due_count := 0
	for item in review_queue:
		if int(item.get("srs_due", -1)) == -1:
			new_count += 1
		else:
			due_count += 1

	new_badge.text = "🆕 %s جدید" % MenuStyle.persian_digits(str(new_count))
	due_badge.text = "🔁 %s مرور" % MenuStyle.persian_digits(str(due_count))

	var total: int = max(1, session_total_count)
	var current_done: int = min(session_completed_count, total)
	progress_count_label.text = "جلسه مرور: %s از %s" % [
		MenuStyle.persian_digits(str(current_done)),
		MenuStyle.persian_digits(str(total))
	]
	
	var target_ratio: float = clampf(float(current_done) / float(total), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(session_progress_bar, "value", target_ratio, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ----------------------------------------------------------------
#  SESSION COMPLETION & EMPTY STATES
# ----------------------------------------------------------------
func _show_all_done() -> void:
	card_panel.visible = false
	empty_card.visible = false
	summary_card.visible = true
	controls.visible = false
	progress_section.visible = false
	due_counter.text = "تمام شد ✅"

	total_reviewed_label.text = "کلمات مرور شده در این جلسه: %s کلمه" % MenuStyle.persian_digits(str(session_completed_count))
	
	var total_answers := stats_again + stats_hard + stats_good + stats_easy
	var successful_answers := stats_good + stats_easy
	var retention_pct: int = int(round(float(successful_answers) / float(max(1, total_answers)) * 100.0))
	retention_rate_label.text = "میزان تسلط شما: %s٪" % MenuStyle.persian_digits(str(retention_pct))

	stat_again.text = "🔴 دوباره: %s" % MenuStyle.persian_digits(str(stats_again))
	stat_hard.text  = "🟠 سخت: %s"   % MenuStyle.persian_digits(str(stats_hard))
	stat_good.text  = "🟢 خوب: %s"   % MenuStyle.persian_digits(str(stats_good))
	stat_easy.text  = "🔵 آسان: %s"  % MenuStyle.persian_digits(str(stats_easy))

	Sfx.complete()
	UiMotion.pop_in(summary_card)


func _show_no_words_saved() -> void:
	card_panel.visible = false
	summary_card.visible = false
	empty_card.visible = true
	controls.visible = false
	progress_section.visible = false
	due_counter.text = "لیست خالی است"
	UiMotion.pop_in(empty_card)


func _on_go_vocab_pressed() -> void:
	TransitionManager.change_scene(SCENE_FLASHCARDS)


# ----------------------------------------------------------------
#  BUTTON STYLING (Modern Anki Color Palette)
# ----------------------------------------------------------------
func _style_rating_buttons() -> void:
	_apply_button_color(again_button, Color("#EF4444"))  # red
	_apply_button_color(hard_button,  Color("#F59E0B"))  # orange
	_apply_button_color(good_button,  Color("#10B981"))  # emerald green
	_apply_button_color(easy_button,  Color("#3B82F6"))  # blue

	for btn in [again_button, hard_button, good_button, easy_button]:
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD


func _apply_button_color(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = color
	style.corner_radius_top_left     = 20
	style.corner_radius_top_right    = 20
	style.corner_radius_bottom_left  = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(color.r, color.g, color.b, 0.35)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)

	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)


# ----------------------------------------------------------------
#  THEME AWARENESS
# ----------------------------------------------------------------
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	var dark := Global.theme_is_dark()
	background_color.color = _page_bg_color()

	# Re-style card panel
	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(28)
	if dark:
		card_style.bg_color = Color(0.15, 0.17, 0.22, 1)
		card_style.border_color = Color(1, 1, 1, 0.08)
		card_style.set_border_width_all(1)
		card_style.shadow_color = Color(0, 0, 0, 0.5)
	else:
		card_style.bg_color = Color(1, 1, 1, 1)
		card_style.border_color = Color(0, 0, 0, 0.06)
		card_style.set_border_width_all(1)
		card_style.shadow_color = Color(0, 0, 0, 0.08)
	card_style.shadow_size = 20
	card_style.shadow_offset = Vector2(0, 8)
	card_panel.add_theme_stylebox_override("panel", card_style)
	summary_card.add_theme_stylebox_override("panel", card_style)
	empty_card.add_theme_stylebox_override("panel", card_style)

	# Style header
	Global.style_header($HeaderBar)

	# Side button style
	var ham := StyleBoxFlat.new()
	ham.set_corner_radius_all(30)
	ham.expand_margin_left = 200
	if dark:
		ham.bg_color = Color(0.18, 0.24, 0.32, 0.95)
		ham.border_color = Color(1, 1, 1, 0.10)
	else:
		ham.bg_color = Color(0.15, 0.22, 0.32, 0.95)
		ham.border_color = Color(0, 0, 0, 0.10)
	ham.set_border_width_all(1)
	open_list_menu_button.add_theme_stylebox_override("normal", ham)
	open_list_menu_button.add_theme_stylebox_override("pressed", ham)
	open_list_menu_button.add_theme_stylebox_override("hover", ham)
	open_list_menu_button.add_theme_color_override("font_color", Color.WHITE)

	# Text colors
	var txt_col: Color = Global.get_theme_color("text")
	if dark:
		word_label.add_theme_color_override("font_color", Color.WHITE)
		back_word_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		word_label.add_theme_color_override("font_color", txt_col)
		back_word_label.add_theme_color_override("font_color", txt_col)


func _page_bg_color() -> Color:
	if Global.theme_is_dark():
		return Color(0.10, 0.11, 0.16, 1)
	return Color(0.95, 0.94, 0.92, 1)


# ----------------------------------------------------------------
#  NAVIGATION
# ----------------------------------------------------------------
func _on_back_button_pressed() -> void:
	var target: String = str(AppRouter.get_arg("return_route", ""))
	if target == "":
		target = SCENE_SAVED_WORDS
	TransitionManager.change_scene(target)


func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
