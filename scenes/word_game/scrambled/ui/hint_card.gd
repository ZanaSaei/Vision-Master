class_name ScrambledHintCard
extends PanelContainer
## ============================================================
##  HINT CARD — the meaning of the word, dealt like a printed card.
##
##  The English meaning is the hint (that is what a spelling game may give
##  away); the Persian meaning sits underneath as a second hand, and in the
##  day's competition a line says what the word is now worth.
##
##  Its whole look — the cream paper, the green frame, and the four label
##  voices on it — is declared in the theme as `ScrambledHintCard` and the
##  `ScrambledHint*` label variations, so this script owns only the meaning it
##  shows and the animation that deals it in. The card is deliberately painted
##  from fixed colours rather than the palette: it must read the same in both
##  themes, like a card dealt onto the board.
##
##  The entrance lives here with the thing it animates (per the project's UI
##  rules) — it is the one moment on this screen that should feel like
##  something being dealt.
## ============================================================

## The card lands slightly small and opens out, TRANS_BACK.
const ENTER_FROM := 0.86
const ENTER_TIME := 0.34
const ENTER_FADE_TIME := 0.22

@onready var _meaning: Label = $Column/Meaning
@onready var _persian: Label = $Column/Persian
@onready var _worth: Label = $Column/Worth

var _audio_btn: Button = null
var _current_word: String = ""


func _ready() -> void:
	visible = false
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	_setup_audio_button()


func _setup_audio_button() -> void:
	var col := get_node_or_null("Column") as VBoxContainer
	if col == null:
		return
	_audio_btn = Button.new()
	_audio_btn.name = "AudioButton"
	_audio_btn.text = "🔊  شنیدن تلفظ"
	_audio_btn.custom_minimum_size = Vector2(180, 50)
	_audio_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_audio_btn.add_theme_font_override("font", MenuStyle.vazir())
	_audio_btn.add_theme_font_size_override("font_size", 24)
	_audio_btn.add_theme_color_override("font_color", Color("#2563EB"))

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#EFF6FF")
	sb.set_corner_radius_all(14)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color("#BFDBFE")
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	_audio_btn.add_theme_stylebox_override("normal", sb)

	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color("#DBEAFE")
	_audio_btn.add_theme_stylebox_override("hover", sb_hover)
	_audio_btn.add_theme_stylebox_override("pressed", sb_hover)
	_audio_btn.add_theme_stylebox_override("focus", sb)

	_audio_btn.pressed.connect(func() -> void:
		if not _current_word.is_empty():
			var g := get_node_or_null("/root/Global")
			if g != null and g.has_method("play_word_audio"):
				g.play_word_audio(_current_word.to_lower() + ".mp3", _current_word)
			UiMotion.pop(_audio_btn, 1.15)
			Sfx.click()
	)
	MenuStyle.wire_microinteractions(_audio_btn)
	col.add_child(_audio_btn)


func is_shown() -> bool:
	return visible


## Deals the card in: the meaning first, the Persian one under it, and — in the
## competition — a line about what reading it costs.
func show_hint(meaning: String, meaning_fa: String, worth_text: String, word_to_speak: String = "") -> void:
	_current_word = word_to_speak
	if _audio_btn != null:
		_audio_btn.visible = not word_to_speak.is_empty()
	_meaning.text = meaning if not meaning.is_empty() else "—"
	_persian.text = meaning_fa
	_persian.visible = not meaning_fa.is_empty()
	_worth.text = worth_text
	_worth.visible = not worth_text.is_empty()

	pivot_offset = size * 0.5
	scale = Vector2(ENTER_FROM, ENTER_FROM)
	modulate.a = 0.0
	visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, ENTER_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, ENTER_FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Takes the card away with no animation: used when a new word is dealt, where
## the board is already moving and a second animation would fight it.
func hide_hint() -> void:
	visible = false
	scale = Vector2.ONE
	modulate.a = 1.0
