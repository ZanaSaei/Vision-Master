extends "res://autoload/BackButtonHandler.gd"
## ============================================================
##  WORDLE SCREEN — the daily puzzle of «کلمه روز» (وردل).
##
##  This scene is the GAME CONTENT: board, keyboard, message line and the
##  two overlays (end-of-game vocabulary card, how-to-play). WordOfDay.tscn
##  instances it and owns the header bar and the back navigation — that is
##  why the کلمه روز hub button opens this game directly and why there is
##  no second Wordle entry point anywhere in the app.
##
##  What this script owns:
##    * the dynamic UI (board rows sized to the answer, QWERTY keys),
##    * the game loop (typing, submitting, revealing, feedback),
##    * persistence (through WordleGame) and the record on the end card.
##  Board state is drawn by WordleTile, which is immune to the app-wide
##  theme walk; panels, labels and buttons are left to that walk and are
##  only re-coloured here where meaning demands it.
## ============================================================

const TILE_SCENE := preload("res://scenes/word_game/wordle/WordleTile.tscn")

# QWERTY keyboard rows (data, not layout — the scene owns the containers).
const KEY_ROWS := [
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L"],
	["ENTER", "Z", "X", "C", "V", "B", "N", "M", "BACK"],
]
const KEY_SUBMIT := "ENTER"
const KEY_ERASE := "BACK"
## Labelled in Persian on purpose: "⏎" and "⌫" are not in the app font and
## rendered as empty boxes.
const KEY_SUBMIT_LABEL := "تأیید"
const KEY_ERASE_LABEL := "پاک"
@export_group("Keyboard")
@export var key_min_size: Vector2 = Vector2(88, 104)
@export var key_font_size: int = 46
@export var key_action_font_size: int = 34
@export var key_gap: int = 8
@export var key_corner_radius: int = 14

@export_group("Board")
## Board geometry. The tile size is measured from the box the scene layout
## actually gives the board, so a 5- and a 10-letter answer both fit.
@export var tile_gap: float = 12.0
@export var tile_max_size: float = 150.0
@export var tile_min_size: float = 44.0

@export_group("Pacing")
@export var reveal_step: float = 0.16
## Beat between the last flip and the vocabulary card, so the player gets to
## look at the row that just finished.
@export var end_panel_delay: float = 1.15
@export var message_flash_time: float = 2.6

const MESSAGE_NOT_A_WORD := "این کلمه در فهرست واژگان بازی نیست"
const MESSAGE_TOO_SHORT := "تعداد حروف کافی نیست"
const MESSAGE_WIN := "آفرین! درست بود"
const MESSAGE_LOSE := "پایان بازی — کلمه‌ی درست:"
const MESSAGE_LOAD_ERROR := "خطا در بارگذاری واژگان بازی"

@export_group("Vocabulary card")
## The end-of-game card wears its own look — a warm cream paper card with a
## thick green frame and centred dark ink — instead of the plain themed panel.
## Colours are fixed on purpose (not from the palette) so the card reads the
## same in both themes, like a printed card. They are exported so the card can
## be restyled from the Inspector without touching this script.
@export var card_bg: Color = Color(0.984, 0.953, 0.898)          # warm cream
@export var card_border: Color = Color(0.345, 0.780, 0.525)      # felt-tip green
@export var card_ink: Color = Color(0.208, 0.216, 0.290)         # dark blue-grey text
@export var card_ink_dim: Color = Color(0.373, 0.392, 0.463)     # muted captions
@export var card_accent: Color = Color(0.180, 0.639, 0.404)      # green emphasis
@export var card_radius: float = 44.0
@export var card_border_width: int = 6

## Which palette role a message line is painted with, so it stays legible in
## both themes.
enum MessageKind { INFO, ERROR, SUCCESS }

## Raised whenever the host's «کارت واژه» header button should be offered or
## hidden. The header belongs to the HOST scene (WordOfDay.tscn), so this
## content scene reports its own state upward instead of reaching into a
## sibling node's internals — see AGENTS "signal up, call down".
signal card_available_changed(available: bool)

@onready var board_container: VBoxContainer = $GameArea/BoardContainer
@onready var status_label: Label = $GameArea/StatusRow/StatusLabel
@onready var message_label: Label = $GameArea/MessageLabel
@onready var keyboard_container: VBoxContainer = $Keyboard
@onready var end_panel: PanelContainer = $EndPanel
@onready var end_scroll: ScrollContainer = $EndPanel/EndScroll
@onready var end_headline: Label = $EndPanel/EndScroll/EndBox/Headline
@onready var end_word: Label = $EndPanel/EndScroll/EndBox/WordLabel
@onready var end_phonetics: Label = $EndPanel/EndScroll/EndBox/PhoneticsLabel
@onready var end_source: Label = $EndPanel/EndScroll/EndBox/SourceLabel
@onready var end_audio_button: Button = $EndPanel/EndScroll/EndBox/AudioButton
@onready var end_meaning_fa: Label = $EndPanel/EndScroll/EndBox/MeaningFaLabel
@onready var end_meaning_en: Label = $EndPanel/EndScroll/EndBox/MeaningEnLabel
@onready var end_example: Label = $EndPanel/EndScroll/EndBox/ExampleLabel
@onready var end_synonyms: Label = $EndPanel/EndScroll/EndBox/SynonymsLabel
@onready var end_antonyms: Label = $EndPanel/EndScroll/EndBox/AntonymsLabel
@onready var end_stats: Label = $EndPanel/EndScroll/EndBox/StatsLabel
@onready var end_next_word: Label = $EndPanel/EndScroll/EndBox/NextWordLabel
@onready var end_card_number: Label = $EndPanel/EndScroll/EndBox/CardNumber
@onready var end_close_button: Button = $EndPanel/EndScroll/EndBox/CloseButton
@onready var help_panel: PanelContainer = $HelpPanel
@onready var help_title: Label = $HelpPanel/HelpBox/HelpTitle
@onready var help_body: Label = $HelpPanel/HelpBox/HelpBody
@onready var help_close_button: Button = $HelpPanel/HelpBox/HelpCloseButton

var game: WordleGame = null
var _rows: Array = []                    # Array[Array[WordleTile]]
var _row_nodes: Array[HBoxContainer] = []
var _key_buttons: Dictionary = {}        # letter -> Button
var _input_locked := false               # a row is revealing
var _board_ready := false
## A MessageKind, kept as an int so _set_message() can take a plain int
## parameter without an enum cast at every call site.
var _message_kind: int = MessageKind.INFO
## Bumped whenever the message line changes, so a pending auto-clear can see
## that something newer replaced it.
var _message_token := 0
var _end_audio_filename := ""


func _ready() -> void:
	# The host header buttons trigger these overlays.
	end_panel.visible = false
	help_panel.visible = false
	end_audio_button.visible = false
	end_close_button.pressed.connect(close_panels)
	help_close_button.pressed.connect(close_panels)
	end_audio_button.pressed.connect(_on_audio_button_pressed)

	# The app-wide theme walk runs on scene load, not on a live toggle, so
	# anything colour-coded has to look after itself here.
	Global.on_theme_changed(_on_theme_changed)

	game = WordleGame.load_or_create_today()
	if game == null or game.answer.is_empty():
		status_label.text = ""
		_set_message(MESSAGE_LOAD_ERROR, MessageKind.ERROR)
		return

	await _build_game_ui()


## Builds the board and the keyboard once the host layout has run, so the
## tiles can be measured against the space they really get.
func _build_game_ui() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_build_board()
	_build_keyboard()
	_restore_saved_progress()
	_refresh_status()
	if not board_container.resized.is_connected(_refit_tiles):
		board_container.resized.connect(_refit_tiles)


############################################################
# BOARD
############################################################
func _build_board() -> void:
	var columns := game.answer.length()
	var cell := _measure_cell(board_container.size)
	for row_index in WordleGame.MAX_GUESSES:
		var row := HBoxContainer.new()
		row.name = "Row%d" % row_index
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(tile_gap))
		var tiles: Array = []
		for column in columns:
			var tile: WordleTile = TILE_SCENE.instantiate()
			tile.name = "Tile%d_%d" % [row_index, column]
			tile.set_tile_size(cell)
			row.add_child(tile)
			tiles.append(tile)
		board_container.add_child(row)
		_row_nodes.append(row)
		_rows.append(tiles)
	board_container.add_theme_constant_override("separation", int(tile_gap))
	_board_ready = true


## The largest square cell that fits `columns` columns of MAX_GUESSES rows
## into `box` — capped so a 5-letter board doesn't balloon on a wide screen,
## floored so a long answer stays readable.
func _measure_cell(box: Vector2) -> float:
	if box.x <= 1.0 or box.y <= 1.0:
		# Layout has not settled. The build waits a frame so this should not
		# happen; the fallback keeps a first frame from producing absurd cells.
		box = Vector2(get_viewport_rect().size.x - 80.0, 800.0)
	var columns := maxi(game.answer.length(), 1)
	var rows := WordleGame.MAX_GUESSES
	var by_width := (box.x - tile_gap * float(columns - 1)) / float(columns)
	var by_height := (box.y - tile_gap * float(rows - 1)) / float(rows)
	return clampf(floorf(minf(minf(by_width, by_height), tile_max_size)),
		tile_min_size, tile_max_size)


## Keeps the board proportional when the window or the orientation changes.
func _refit_tiles() -> void:
	if not _board_ready:
		return
	var cell := _measure_cell(board_container.size)
	for tiles in _rows:
		for tile: WordleTile in tiles:
			tile.set_tile_size(cell)


func _row_tiles(row_index: int) -> Array:
	if row_index < 0 or row_index >= _rows.size():
		return []
	return _rows[row_index]


## Paints the word currently being typed into row `row_index`.
func _set_row_letters(row_index: int, word: String) -> void:
	var tiles := _row_tiles(row_index)
	for i in tiles.size():
		tiles[i].set_letter(word[i] if i < word.length() else "")


## Rejection shake. The tween runs on the row container (visual only), so the
## board's layout never actually moves — and an empty/absent row is a no-op
## instead of the out-of-range crash the old static helper could hit.
func _shake_row(row_index: int) -> void:
	if row_index < 0 or row_index >= _row_nodes.size():
		return
	var row := _row_nodes[row_index]
	var origin := row.position.x
	var tw := row.create_tween()
	tw.tween_property(row, "position:x", origin - 16.0, 0.05)
	tw.tween_property(row, "position:x", origin + 16.0, 0.09)
	tw.tween_property(row, "position:x", origin - 9.0, 0.07)
	tw.tween_property(row, "position:x", origin, 0.05)


############################################################
# KEYBOARD
############################################################
func _build_keyboard() -> void:
	for row_letters in KEY_ROWS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", key_gap)
		for key in row_letters:
			var button := _make_key_button(key)
			row.add_child(button)
			if key != KEY_SUBMIT and key != KEY_ERASE:
				_key_buttons[key] = button
		keyboard_container.add_child(row)
	_apply_keyboard_colors()


func _make_key_button(key: String) -> Button:
	var button := Button.new()
	button.name = "Key%s" % key
	button.custom_minimum_size = key_min_size
	button.pressed.connect(_on_key_pressed.bind(key))
	if key == KEY_SUBMIT or key == KEY_ERASE:
		button.text = KEY_SUBMIT_LABEL if key == KEY_SUBMIT else KEY_ERASE_LABEL
		button.add_theme_font_size_override("font_size", key_action_font_size)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		button.text = key
		button.add_theme_font_size_override("font_size", key_font_size)
	MenuStyle.wire_microinteractions(button)
	return button


## Paints every key: untried letters keep the neutral app button look, tried
## ones wear the best Wordle colour they earned (never downgraded). Re-run
## after a restore and after a theme change.
func _apply_keyboard_colors() -> void:
	var states: Dictionary = game.get_keyboard_states() if game != null else {}
	for letter in _key_buttons:
		var button: Button = _key_buttons[letter]
		var score: int = int(states.get(letter, -1))
		var style := _key_style(score)
		for slot in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(slot, style)
		var font: Color = WordleTile.COLOR_LETTER_REVEALED
		if score < 0:
			font = Global.get_theme_color("text")
		for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(slot, font)


## `score` < 0 means "never tried": the key keeps the theme's own surface
## instead of a Wordle colour.
func _key_style(score: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(key_corner_radius)
	style.bg_color = _key_color(score)
	if score < 0:
		style.set_border_width_all(1)
		style.border_color = Global.get_theme_color("border")
	return style


func _key_color(score: int) -> Color:
	match score:
		WordleEvaluator.Score.CORRECT: return WordleTile.COLOR_CORRECT
		WordleEvaluator.Score.PRESENT: return WordleTile.COLOR_PRESENT
		WordleEvaluator.Score.ABSENT: return WordleTile.COLOR_ABSENT
		_: return Global.get_theme_color("surface_alt")


func _on_key_pressed(key: String) -> void:
	Sfx.click()
	if _input_locked or game == null or game.is_finished() or has_open_panel():
		return
	match key:
		KEY_SUBMIT:
			_submit_row()
		KEY_ERASE:
			if game.remove_letter():
				_set_row_letters(game.attempts_used(), game.get_current_row())
		_:
			if game.add_letter(key):
				_set_row_letters(game.attempts_used(), game.get_current_row())


## Physical keyboard support (desktop testing, hardware keyboards).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		close_panels()
		return
	if has_open_panel():
		# A card is up: the board must not eat keystrokes aimed at it.
		return
	var keycode := key.keycode as int
	# KEY_ENTER / KEY_BACKSPACE here are Godot's key enums; KEY_SUBMIT and
	# KEY_ERASE are the on-screen key ids (deliberately not named KEY_ENTER /
	# KEY_BACK, which would shadow those enums and break this branch).
	if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		_on_key_pressed(KEY_SUBMIT)
	elif keycode == KEY_BACKSPACE:
		_on_key_pressed(KEY_ERASE)
	elif keycode >= KEY_A and keycode <= KEY_Z:
		_on_key_pressed(char(65 + keycode - KEY_A))


############################################################
# SUBMIT / REVEAL
############################################################
func _submit_row() -> void:
	if game.get_current_row().length() != game.answer.length():
		_flash_message(MESSAGE_TOO_SHORT, MessageKind.ERROR)
		_shake_row(game.attempts_used())
		Sfx.wrong()
		return
	var result := game.submit_current_row()
	if not result.ok:
		# A rejected word never consumes an attempt (WordleGame guarantees
		# it) — say so, shake the row and leave the letters where they are.
		_flash_message(MESSAGE_NOT_A_WORD, MessageKind.ERROR)
		_shake_row(game.attempts_used())
		Sfx.wrong()
		return

	_set_message("", MessageKind.INFO)
	_reveal_row(result)


## Flips the row that was just submitted, then reacts to the outcome.
func _reveal_row(result: Dictionary) -> void:
	_input_locked = true
	var row_index := game.attempts_used() - 1
	var tiles := _row_tiles(row_index)
	for i in tiles.size():
		tiles[i].reveal(int(result.evaluation[i]), reveal_step * float(i))

	# Wait for the last flip of the row to land.
	var wait := reveal_step * float(tiles.size()) + WordleTile.FLIP_HALF_TIME * 2.0 + 0.08
	await get_tree().create_timer(wait).timeout
	if not is_inside_tree():
		return

	_apply_keyboard_colors()
	_input_locked = false
	_refresh_status()

	var won: bool = result.won
	if won:
		_set_message(MESSAGE_WIN, MessageKind.SUCCESS)
		_bounce_win_row(row_index)
		Sfx.correct()
	else:
		Sfx.wrong()
		if game.is_finished():
			_set_message("%s %s" % [MESSAGE_LOSE, game.answer], MessageKind.ERROR)

	if not game.is_finished():
		return

	# The record is written exactly once per day, and only here: never per
	# guess (which filed a mid-game guess as a loss and then blocked the real
	# result, since recording is idempotent per puzzle) and never on restore.
	WordleStats.record_result(won, game.attempts_used(), game.puzzle_id)

	# Let the player look at the finished row before the card covers it.
	await get_tree().create_timer(end_panel_delay).timeout
	if not is_inside_tree():
		return
	_show_end_panel(game.get_state() == WordleGame.State.WON)


func _bounce_win_row(row_index: int) -> void:
	var tiles := _row_tiles(row_index)
	for i in tiles.size():
		tiles[i].play_win_bounce(0.1 * float(i))


############################################################
# FEEDBACK — message line, status line, card button
############################################################
## The only writer of the message line. Bumping the token invalidates any
## pending auto-clear, so a flash can never wipe a newer message.
func _set_message(text: String, kind: int) -> void:
	_message_kind = kind
	_message_token += 1
	message_label.text = text
	var color := Global.get_theme_color("text_dim")
	match kind:
		MessageKind.ERROR: color = Global.get_theme_color("error")
		MessageKind.SUCCESS: color = Global.get_theme_color("success")
	message_label.add_theme_color_override("font_color", color)


## Shows a message that clears itself after `seconds`.
func _flash_message(text: String, kind: int, seconds: float = message_flash_time) -> void:
	_set_message(text, kind)
	var token := _message_token
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree() or token != _message_token:
		return
	_set_message("", MessageKind.INFO)


## "تلاش‌ها: ۳ از ۶" — the player always knows where they stand.
func _refresh_status() -> void:
	if game == null:
		return
	status_label.text = MenuStyle.persian_digits(
		"تلاش‌ها: %d از %d\nکلمه‌ی بعدی در %s" % [
			game.attempts_used(), WordleGame.MAX_GUESSES,
			WordleDaily.format_until_next_word(),
		])
	status_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	_notify_card_available()


## The vocabulary card can be dismissed, so a finished board offers a way
## back to it — otherwise the day's word would be lost for good. The host owns
## the header button, so this screen only reports whether it should be shown.
func _notify_card_available() -> void:
	card_available_changed.emit(game != null and game.is_finished() and not end_panel.visible)


## Re-opens the end-of-game vocabulary card. Called by the host (WordOfDay)
## when its header button is pressed — the same public API as show_help().
func show_card() -> void:
	Sfx.click()
	if game != null and game.is_finished():
		_show_end_panel(game.get_state() == WordleGame.State.WON)


############################################################
# RESTORE
############################################################
## Replays the saved guesses instantly (no reveal animation), so a player who
## closed the app mid-puzzle comes back to the exact board they left.
func _restore_saved_progress() -> void:
	for row_index in game.guesses.size():
		var tiles := _row_tiles(row_index)
		if tiles.is_empty():
			break
		var word: String = game.guesses[row_index]
		var evaluation: Array = game.evaluations[row_index]
		for i in tiles.size():
			tiles[i].set_letter(word[i] if i < word.length() else "")
			if i < evaluation.size():
				tiles[i].set_revealed(int(evaluation[i]))
	_apply_keyboard_colors()

	if game.is_finished():
		if game.get_state() == WordleGame.State.WON:
			_set_message(MESSAGE_WIN, MessageKind.SUCCESS)
		else:
			_set_message("%s %s" % [MESSAGE_LOSE, game.answer], MessageKind.ERROR)
		_show_end_panel(game.get_state() == WordleGame.State.WON, true)


############################################################
# VOCABULARY CARD
############################################################
## The answer's dictionary entry. `won` only changes the headline — the word
## is shown either way, because this is a learning app and the day's answer
## is worth reading even when it beat you.
## `instant` skips the fade (an already finished day needs no animation).
func _show_end_panel(won: bool, instant: bool = false) -> void:
	_apply_panel_theme()
	end_headline.text = MESSAGE_WIN if won else MESSAGE_LOSE
	end_headline.add_theme_color_override("font_color",
		Global.get_theme_color("success" if won else "warning"))

	# A word can reach the pool through another entry's synonym list; in that
	# case show that entry — and say so — instead of a card full of dashes.
	var info := WordleVocab.get_word_info(game.answer)
	var meta: Dictionary = info.meta
	end_word.text = game.answer
	end_phonetics.text = _meta_text(meta, "phonetics", "")
	end_phonetics.visible = not end_phonetics.text.is_empty()
	end_source.text = ""
	if not bool(info.exact) and not str(info.source_word).is_empty():
		end_source.text = "برگرفته از مدخل «%s»" % str(info.source_word)
	end_source.visible = not end_source.text.is_empty()

	end_meaning_fa.text = "معنی: %s" % _meaning_fa(meta)
	end_meaning_en.text = "Meaning: %s" % _meta_text(meta, "meaning_en")
	end_example.text = "Example: %s" % _meta_text(meta, "example")
	end_synonyms.text = "مترادف‌ها: %s" % _vocab_list(meta, "synonyms")
	end_antonyms.text = "متضادها: %s" % _vocab_list(meta, "antonyms")
	end_stats.text = MenuStyle.persian_digits(_stats_text())
	end_next_word.text = "کلمه‌ی بعدی در %s" % WordleDaily.format_until_next_word()
	# The big bottom number of the printed card: the player's current streak,
	# zero-padded to two digits ("۰۱").
	end_card_number.text = MenuStyle.persian_digits("%02d" % WordleStats.get_current_streak())

	# Pronunciation comes from a recorded clip, or from the TTS fallback that
	# Global speaks when the clip is missing — so only offer the button when
	# one of the two can really produce sound.
	_end_audio_filename = str(meta.get("audio", ""))
	var has_clip := not _end_audio_filename.is_empty()
	var can_speak := Global.tts_enabled and not Global.english_voice_id.is_empty()
	end_audio_button.visible = has_clip or can_speak

	end_panel.visible = true
	end_scroll.scroll_vertical = 0
	_notify_card_available()
	if instant:
		end_panel.modulate.a = 1.0
	else:
		end_panel.modulate.a = 0.0
		create_tween().tween_property(end_panel, "modulate:a", 1.0, 0.28)


func _on_audio_button_pressed() -> void:
	Sfx.click()
	Global.play_word_audio(_end_audio_filename, game.answer)


## One compact line of the player's record, so the daily habit is visible
## without a separate statistics screen.
func _stats_text() -> String:
	var played := WordleStats.get_played()
	var wins := WordleStats.get_wins()
	var line := "بازی: %d · برد: %d" % [played, wins]
	if played > wins:
		line += " · باخت: %d" % (played - wins)
	line += " · پیاپی: %d" % WordleStats.get_current_streak()
	line += " · بهترین: %d" % WordleStats.get_best_streak()
	return line


## `key` as a display string, falling back when the field is absent or empty.
func _meta_text(meta: Dictionary, key: String, fallback: String = "—") -> String:
	var value := str(meta.get(key, ""))
	return value if not value.is_empty() else fallback


## The Persian meaning, or the entry's Persian synonyms when it has none.
func _meaning_fa(meta: Dictionary) -> String:
	var direct := _meta_text(meta, "meaning_fa", "")
	if not direct.is_empty():
		return direct
	var synonyms := _vocab_list(meta, "synonyms", "")
	return synonyms if not synonyms.is_empty() else "—"


## Joins a { fa: [...], en: [...] } list into one readable line.
func _vocab_list(meta: Dictionary, key: String, fallback: String = "—") -> String:
	var group = meta.get(key, {})
	if not group is Dictionary:
		return fallback
	var parts: Array[String] = []
	for lang in ["fa", "en"]:
		if group.get(lang) is Array:
			for value in group[lang]:
				if value is String and not value.is_empty():
					parts.append(value)
	return "، ".join(parts) if not parts.is_empty() else fallback


############################################################
# OVERLAYS — help card + the API the host scene drives
############################################################
## Opens the how-to-play card. Called by the host's header button.
func show_help() -> void:
	if game == null:
		return
	_apply_panel_theme()
	help_panel.visible = true


## Closes whichever card is up. Returns true when one was open, so the host's
## Android-back handler can consume the press instead of leaving the screen.
func close_panels() -> bool:
	var closed := false
	if help_panel.visible:
		help_panel.visible = false
		closed = true
	if end_panel.visible:
		end_panel.visible = false
		_notify_card_available()
		closed = true
	return closed


func has_open_panel() -> bool:
	return help_panel.visible or end_panel.visible


############################################################
# THEMING
############################################################
## The app-wide theme walk runs when a scene is entered, not on a live
## toggle, so a player who switches theme mid-puzzle is handled from here:
## the tiles repaint at once (they read the palette while drawing) and the
## coloured parts are re-applied once the host has re-walked the tree.
func _on_theme_changed() -> void:
	if not is_inside_tree():
		return
	for tiles in _rows:
		for tile: WordleTile in tiles:
			tile.refresh_theme()
	call_deferred("_apply_theme_colors")


func _apply_theme_colors() -> void:
	if not is_inside_tree():
		return
	_apply_keyboard_colors()
	_set_message(message_label.text, _message_kind)
	_refresh_status()
	_apply_panel_theme()


## Colours the overlay cards from the palette. The generic walk paints plain
## labels; the emphasis (headline, answer, muted captions) is only known here.
func _apply_panel_theme() -> void:
	_apply_card_style()
	var text := Global.get_theme_color("text")
	var dim := Global.get_theme_color("text_dim")

	for label in [end_meaning_fa, end_meaning_en, end_synonyms, end_antonyms]:
		label.add_theme_color_override("font_color", text)
	for label in [end_example, end_phonetics, end_source, end_stats, end_next_word]:
		label.add_theme_color_override("font_color", dim)
	end_word.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))

	if game != null and game.is_finished():
		end_headline.add_theme_color_override("font_color",
			Global.get_theme_color("success" if game.get_state() == WordleGame.State.WON
				else "warning"))

	help_title.add_theme_color_override("font_color", Global.get_theme_color("accent_bright"))
	help_body.add_theme_color_override("font_color", text)


## Dresses the vocabulary card in its printed look: cream paper, thick green
## rounded frame and fixed dark ink so it stays readable in both themes.
## Re-run on every show and theme change because the app-wide walk repaints
## panels and labels behind our back.
func _apply_card_style() -> void:
	if not is_inside_tree():
		return
	var style := StyleBoxFlat.new()
	style.bg_color = card_bg
	style.set_corner_radius_all(int(card_radius))
	style.set_border_width_all(card_border_width)
	style.border_color = card_border
	style.content_margin_left = 44.0
	style.content_margin_right = 44.0
	style.content_margin_top = 40.0
	style.content_margin_bottom = 36.0
	end_panel.add_theme_stylebox_override("panel", style)

	# Fixed ink: the walk paints themed (light/dark) colours, which would be
	# unreadable on cream, so every card label is overridden here.
	for label in [end_headline, end_word, end_meaning_fa, end_meaning_en,
			end_synonyms, end_antonyms]:
		label.add_theme_color_override("font_color", card_ink)
	for label in [end_phonetics, end_source, end_example, end_stats, end_next_word]:
		label.add_theme_color_override("font_color", card_ink_dim)
	end_word.add_theme_color_override("font_color", card_accent)
	end_card_number.add_theme_color_override("font_color", card_ink)
	if game != null and game.is_finished():
		end_headline.add_theme_color_override("font_color",
			card_accent if game.get_state() == WordleGame.State.WON
				else Color(0.851, 0.502, 0.239))
