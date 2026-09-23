extends CanvasLayer
class_name DictionaryPopup

signal popup_closed

var popup_panel: PanelContainer
var title_label: Label
var audio_button: Button  # NEW TTS BUTTON
var type_label: Label
var meaning_label: Label
var extra_label: Label
var btn_save_word: Button
var btn_close_popup: Button

var font_regular = preload("res://assets/fonts/PlusJakartaSans-Regular.ttf")
var font_bold = preload("res://assets/fonts/PlusJakartaSans-Bold.ttf")
var font_italic = preload("res://assets/fonts/PlusJakartaSans-Italic.ttf")
var font_farsi = preload("res://assets/fonts/Vazirmatn-Regular.ttf")

var popup_style: StyleBoxFlat
var close_style: StyleBoxFlat
var close_pressed: StyleBoxFlat

var current_word_data: Dictionary = {}

func _init() -> void:
	layer = 100
	_build_ui()

func _build_ui() -> void:
	popup_panel = PanelContainer.new()
	popup_style = StyleBoxFlat.new()
	var style := popup_style
	style.bg_color = Color("#FFFFFF")
	style.corner_radius_bottom_left = 32
	style.corner_radius_bottom_right = 32
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 25
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 110
	style.content_margin_bottom = 40
	popup_panel.add_theme_stylebox_override("panel", style)
	
	popup_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	popup_panel.position.y = -900 # Start further offscreen due to larger margins
	add_child(popup_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	popup_panel.add_child(vbox)
	
	# --- HEADER ROW (Title + Audio) ---
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 75)
	title_label.add_theme_color_override("font_color", DesignTokens.INK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_bold != null: title_label.add_theme_font_override("font", font_bold)
	header_hbox.add_child(title_label)
	
	# --- THE TTS BUTTON (Styled like a modern icon pill) ---
	audio_button = Button.new()
	audio_button.text = "🔊 Listen"
	audio_button.add_theme_font_size_override("font_size", 38)
	if font_bold != null: audio_button.add_theme_font_override("font", font_bold)
	audio_button.add_theme_color_override("font_color", DesignTokens.ACCENT)
	audio_button.add_theme_color_override("font_pressed_color", DesignTokens.ACCENT_DEEP)
	audio_button.add_theme_color_override("font_hover_color", DesignTokens.ACCENT) # Match normal text color
	
	var audio_style = StyleBoxFlat.new()
	audio_style.bg_color = Color("#EFF6FF")
	audio_style.corner_radius_top_left = 24
	audio_style.corner_radius_top_right = 24
	audio_style.corner_radius_bottom_left = 24
	audio_style.corner_radius_bottom_right = 24
	audio_style.content_margin_left = 20
	audio_style.content_margin_right = 20
	
	# Apply same style to normal AND hover
	audio_button.add_theme_stylebox_override("normal", audio_style)
	audio_button.add_theme_stylebox_override("hover", audio_style)
	
	var audio_pressed = audio_style.duplicate()
	audio_pressed.bg_color = Color("#DBEAFE")
	audio_button.add_theme_stylebox_override("pressed", audio_pressed)
	
	audio_button.pressed.connect(_on_audio_pressed)
	header_hbox.add_child(audio_button)
	
	type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 42)
	type_label.add_theme_color_override("font_color", Color("#64748B"))
	if font_italic != null: type_label.add_theme_font_override("font", font_italic)
	vbox.add_child(type_label)
	
	meaning_label = Label.new()
	meaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	meaning_label.add_theme_font_size_override("font_size", 52)
	meaning_label.add_theme_color_override("font_color", Color("#334155"))
	if font_regular != null: meaning_label.add_theme_font_override("font", font_regular)
	vbox.add_child(meaning_label)
	
	extra_label = Label.new()
	extra_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	extra_label.add_theme_font_size_override("font_size", 42)
	extra_label.add_theme_color_override("font_color", Color("#0284C7"))
	if font_regular != null: extra_label.add_theme_font_override("font", font_regular)
	vbox.add_child(extra_label)
	
	# Spacer to push buttons down slightly
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_hbox)
	
	# --- SAVE BUTTON (Primary Action) ---
	btn_save_word = Button.new()
	btn_save_word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_word.add_theme_font_size_override("font_size", 48)
	btn_save_word.add_theme_color_override("font_color", Color.WHITE)
	btn_save_word.add_theme_color_override("font_hover_color", Color.WHITE) # Match normal text color
	btn_save_word.add_theme_color_override("font_disabled_color", Color("#94A3B8"))
	if font_farsi != null: btn_save_word.add_theme_font_override("font", font_farsi)
	
	var save_style = StyleBoxFlat.new()
	save_style.bg_color = Color("#10B981") # Emerald Green
	save_style.corner_radius_top_left = 16
	save_style.corner_radius_top_right = 16
	save_style.corner_radius_bottom_left = 16
	save_style.corner_radius_bottom_right = 16
	save_style.shadow_color = Color(0.06, 0.72, 0.5, 0.3)
	save_style.shadow_size = 8
	save_style.shadow_offset = Vector2(0, 4)
	save_style.content_margin_top = 20
	save_style.content_margin_bottom = 20
	
	# Apply same style to normal AND hover
	btn_save_word.add_theme_stylebox_override("normal", save_style)
	btn_save_word.add_theme_stylebox_override("hover", save_style)
	
	var save_pressed = save_style.duplicate()
	save_pressed.bg_color = Color("#059669")
	save_pressed.shadow_size = 2
	save_pressed.shadow_offset = Vector2(0, 1)
	btn_save_word.add_theme_stylebox_override("pressed", save_pressed)
	
	var save_disabled = save_style.duplicate()
	save_disabled.bg_color = Color("#E2E8F0")
	save_disabled.shadow_size = 0
	btn_save_word.add_theme_stylebox_override("disabled", save_disabled)
	
	btn_save_word.pressed.connect(_on_save_word_pressed)
	btn_hbox.add_child(btn_save_word)
	
	# --- CLOSE BUTTON (Secondary Action) ---
	btn_close_popup = Button.new()
	btn_close_popup.text = "بستن"
	btn_close_popup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_close_popup.add_theme_font_size_override("font_size", 48)
	btn_close_popup.add_theme_color_override("font_color", Color("#475569"))
	btn_close_popup.add_theme_color_override("font_hover_color", Color("#475569")) # Match normal text color
	if font_farsi != null: btn_close_popup.add_theme_font_override("font", font_farsi)
	
	close_style = StyleBoxFlat.new()
	var close_sb := close_style
	close_sb.bg_color = Color("#F1F5F9")
	close_style.corner_radius_top_left = 16
	close_style.corner_radius_top_right = 16
	close_style.corner_radius_bottom_left = 16
	close_style.corner_radius_bottom_right = 16
	close_style.content_margin_top = 20
	close_style.content_margin_bottom = 20
	
	# Apply same style to normal AND hover
	btn_close_popup.add_theme_stylebox_override("normal", close_style)
	btn_close_popup.add_theme_stylebox_override("hover", close_style)
	
	close_pressed = close_style.duplicate()
	close_pressed.bg_color = Color("#E2E8F0")
	btn_close_popup.add_theme_stylebox_override("pressed", close_pressed)
	
	btn_close_popup.pressed.connect(_hide_popup)
	btn_hbox.add_child(btn_close_popup)

func show_word(def: Dictionary) -> void:
	current_word_data = def
	title_label.text = str(def.get("word", "")).capitalize()
	
	var type_str := str(def.get("word_type", "Unknown")).capitalize()
	if type_str.to_lower() == "noun" and def.get("countable") != null:
		type_str += " (Countable)" if def.get("countable") else " (Uncountable)"
	type_label.text = type_str
	
	var en_meaning = def.get("meaning_en", "")
	var fa_meaning = def.get("meaning_fa", "")
	meaning_label.text = en_meaning + ("\n" + fa_meaning if fa_meaning != "" else "")
	
	if fa_meaning != "" and font_farsi != null:
		meaning_label.add_theme_font_override("font", font_farsi)
	else:
		meaning_label.add_theme_font_override("font", font_regular)
	
	extra_label.text = ""
	if type_str.to_lower().begins_with("verb") and def.has("verb_forms"):
		var forms = def["verb_forms"]
		var form_strings := []
		if forms.has("past"): form_strings.append("Past: " + forms["past"])
		if forms.has("past_participle"): form_strings.append("PP: " + forms["past_participle"])
		if forms.has("present_participle"): form_strings.append("ING: " + forms["present_participle"])
		extra_label.text = " • ".join(form_strings)
	
	extra_label.visible = extra_label.text != ""
	
	if Global.is_word_saved(def.get("word"), def.get("book"), def.get("lesson")):
		btn_save_word.text = "✓ ذخیره شد"
		btn_save_word.disabled = true
	else:
		btn_save_word.text = "ذخیره کنید"
		btn_save_word.disabled = false

	var tween = create_tween()
	tween.tween_property(popup_panel, "position:y", 0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _hide_popup() -> void:
	var tween = create_tween()
	tween.tween_property(popup_panel, "position:y", -popup_panel.size.y - 50, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): popup_closed.emit())

func _on_save_word_pressed() -> void:
	if not current_word_data.is_empty():
		Global.save_word(current_word_data)
		btn_save_word.text = "✓ ذخیره شد"
		btn_save_word.disabled = true
		Global.button_bounce(btn_save_word)

func _on_audio_pressed() -> void:
	Global.button_bounce(audio_button)
	
	var audio_filename: String = current_word_data.get("audio", "")
	var word_text: String = current_word_data.get("word", "")

	# Trigger unified audio playback (with built-in TTS fallback)
	Global.play_word_audio(audio_filename, word_text)

func is_open() -> bool:
	return popup_panel.position.y >= 0


func _ready() -> void:
	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	popup_style.bg_color = Global.get_theme_color("surface")
	title_label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	type_label.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	meaning_label.add_theme_color_override("font_color", Global.get_theme_color("text"))
	btn_close_popup.add_theme_color_override("font_color", Global.get_theme_color("text_dim"))
	btn_close_popup.add_theme_color_override("font_hover_color", Global.get_theme_color("text_dim"))
	close_style.bg_color = Global.get_theme_color("surface_alt")
	close_pressed.bg_color = Global.get_theme_color("surface_alt")


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()
