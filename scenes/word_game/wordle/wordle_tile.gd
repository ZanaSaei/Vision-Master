class_name WordleTile
extends Control
## ============================================================
##  WORDLE TILE — one letter cell of the game board.
##
##  Visual states:
##    EMPTY  — not filled yet (soft outline)
##    FILLED — letter typed, awaiting submission (strong outline)
##    ABSENT / PRESENT / CORRECT — post-reveal Wordle colours
##
##  WHY IT DRAWS ITSELF instead of being a PanelContainer + Label:
##  the app-wide theme walk (ThemeService.style_scene) restyles every
##  PanelContainer/Panel/Label in a scene. Running over the board it turned
##  every cell into a plain card — erasing the reveal colours of restored
##  rows and repainting the letters in the theme colour. A self-drawing
##  Control is invisible to that walk, so the board keeps its state, works
##  in both themes, and survives a live theme toggle.
##
##  Colours: outlines and unrevealed letters come from the palette (so the
##  board sits naturally on the light or the dark page), while the three
##  reveal colours are fixed — they carry meaning and must not drift.
## ============================================================

enum TileState { EMPTY, FILLED, ABSENT, PRESENT, CORRECT }

## Classic Wordle palette — fixed on purpose.
const COLOR_CORRECT := Color("#6AAA64")
const COLOR_PRESENT := Color("#C9B458")
const COLOR_ABSENT := Color("#787C7E")
## Letters always read white on top of a reveal colour.
const COLOR_LETTER_REVEALED := Color("#FFFFFF")

## How long one half of the reveal flip takes. Public: the screen waits for
## a whole row of flips and must not guess at it.
const FLIP_HALF_TIME := 0.17

## Letter height as a fraction of the cell (Wordle uses roughly half).
const LETTER_SIZE_RATIO := 0.5
const MIN_LETTER_SIZE := 18
## Outline of an untouched cell, as a fraction of theme "text_dim".
const EMPTY_OUTLINE_ALPHA := 0.45
const BORDER_WIDTH := 3
const MIN_CORNER_RADIUS := 8.0

var _state: TileState = TileState.EMPTY
var _text := ""
var _cell_px := 120.0
var _letter_size := 34
var _style: StyleBoxFlat = StyleBoxFlat.new()


func _ready() -> void:
	# The cell is decoration: it must never swallow a click aimed at the
	# keyboard or at a panel behind it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Scaling (the flip) has to happen around the centre, and the cell can be
	# resized by the board layout after the first pass.
	resized.connect(_on_resized)
	_rebuild_style()


## Sizes the cell and its letter. Called by the board for every tile.
func set_tile_size(px: float) -> void:
	var size_vector := Vector2(px, px)
	if custom_minimum_size == size_vector:
		# Nothing to redo. Bailing out here also keeps the board's `resized`
		# signal from re-entering this method forever.
		return
	_cell_px = maxf(px, 32.0)
	custom_minimum_size = Vector2(_cell_px, _cell_px)
	_letter_size = maxi(MIN_LETTER_SIZE, int(round(_cell_px * LETTER_SIZE_RATIO)))
	pivot_offset = Vector2(_cell_px, _cell_px) * 0.5
	_rebuild_style()


func _on_resized() -> void:
	pivot_offset = size * 0.5


func get_state() -> TileState:
	return _state


func get_letter() -> String:
	return _text


func is_revealed() -> bool:
	return _state in [TileState.ABSENT, TileState.PRESENT, TileState.CORRECT]


## Types a letter into the cell ("" clears it). A revealed cell keeps its
## colour: revealing is what the player is judging, typing is transient.
func set_letter(letter: String) -> void:
	_text = letter.to_upper()
	if _text.length() == 1 and 'A' <= _text[0] and _text[0] <= 'Z':
		if not is_revealed():
			_state = TileState.FILLED
	elif _text.is_empty():
		_state = TileState.EMPTY
	_rebuild_style()


## Applies a reveal colour instantly (used when restoring a saved board, and
## by `reveal()` at the midpoint of the flip).
func set_revealed(score: int) -> void:
	_state = _state_for_score(score)
	_rebuild_style()


## Staggered Wordle flip: the cell collapses flat while still showing its
## pre-reveal look, swaps colour exactly at the flat midpoint, then opens
## back up. `delay` staggers a row left to right.
##
## The colour swap has to happen on the tween's midpoint callback — applying
## it up front (as this used to) turned the whole row green before it flipped,
## which destroyed the point of the animation.
func reveal(score: int, delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(delay, 0.0))
	tw.tween_property(self, "scale:y", 0.0, FLIP_HALF_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(set_revealed.bind(score))
	tw.tween_property(self, "scale:y", 1.0, FLIP_HALF_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Small pop used on the winning row.
func play_win_bounce(delay: float) -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _state_for_score(score: int) -> TileState:
	match score:
		WordleEvaluator.Score.CORRECT: return TileState.CORRECT
		WordleEvaluator.Score.PRESENT: return TileState.PRESENT
		_: return TileState.ABSENT


## Re-reads the palette and repaints. Called on a live theme toggle: the
## colours are looked up while drawing, so nothing else has to be tracked.
func refresh_theme() -> void:
	_rebuild_style()


## The single source of truth for the cell's look.
func _rebuild_style() -> void:
	_style.set_corner_radius_all(int(maxf(MIN_CORNER_RADIUS, _cell_px * 0.08)))
	_style.set_border_width_all(0)
	match _state:
		TileState.EMPTY, TileState.FILLED:
			# Unrevealed cells stay transparent, so the board reads as part
			# of the page in either theme: only the outline differs.
			_style.bg_color = Color(0, 0, 0, 0)
			_style.border_color = _outline_color()
			_style.set_border_width_all(BORDER_WIDTH)
		TileState.CORRECT:
			_style.bg_color = COLOR_CORRECT
		TileState.PRESENT:
			_style.bg_color = COLOR_PRESENT
		TileState.ABSENT:
			_style.bg_color = COLOR_ABSENT
	queue_redraw()


## Empty cells wear the soft theme border, a typed cell the strong text
## colour — the same "the outline firms up as you type" cue as Wordle.
func _outline_color() -> Color:
	if _state == TileState.FILLED:
		return Global.get_theme_color("text")
	var dim := Global.get_theme_color("text_dim")
	dim.a = EMPTY_OUTLINE_ALPHA
	return dim


func _letter_color() -> Color:
	return COLOR_LETTER_REVEALED if is_revealed() else Global.get_theme_color("text")


## The letter is drawn, not a child Label, so the theme walk cannot
## re-colour it (see the class docs).
func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	if _text.is_empty():
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var ascent := font.get_ascent(_letter_size)
	var descent := font.get_descent(_letter_size)
	var baseline := (size.y + ascent - descent) * 0.5
	draw_string(font, Vector2(0.0, baseline), _text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, _letter_size, _letter_color())
