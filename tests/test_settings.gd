extends Node
# Verifies the Settings screen's backend logic: the sound/TTS toggle
# persistence (Global.save_settings / _load_settings round-trip) and the
# custom on/off switch styling. Deliberately does NOT call the destructive
# reset_all_progress()/clear_* helpers so it can never wipe real user data.

func test_settings_persistence() -> void:
	var global := get_node_or_null("/root/Global")
	if global == null:
		print("settings persistence: SKIP (Global autoload not present in this test context)")
		return

	# Remember the user's real values so we restore them afterwards.
	var prev_sound: bool = global.sound_enabled
	var prev_tts: bool = global.tts_enabled

	# Write known values, then reload from disk and confirm they stuck.
	global.sound_enabled = false
	global.tts_enabled = true
	global.save_settings()

	global.sound_enabled = true   # simulate a fresh start
	global.tts_enabled = false
	global.call("_load_settings")

	var ok: bool = global.sound_enabled == false and global.tts_enabled == true
	print("settings persistence: ", "PASS" if ok else "FAIL", " -> sound=", global.sound_enabled, " tts=", global.tts_enabled)
	assert(ok, "settings persistence failed")

	# Restore the user's real settings.
	global.sound_enabled = prev_sound
	global.tts_enabled = prev_tts
	global.save_settings()


func test_toggle_style() -> void:
	var scene: PackedScene = load("res://scenes/settings/Settings.tscn")
	if scene == null:
		print("toggle style: SKIP (scene missing)")
		return
	var s: Control = scene.instantiate()
	add_child(s)
	var sound_toggle: Button = s.get_node("Scroll/Margin/Layout/SoundCard/VBox/SoundRow/SoundToggle")
	var on_text: String = sound_toggle.text
	var style: StyleBox = sound_toggle.get_theme_stylebox("normal")
	var ok: bool = on_text == "روشن" and style is StyleBoxFlat and style.bg_color.a > 0.5
	print("toggle style: ", "PASS" if ok else "FAIL", " -> text=", on_text)
	assert(ok, "toggle style failed")
	s.queue_free()


func test_confirm_dialog_styled() -> void:
	var scene: PackedScene = load("res://scenes/settings/Settings.tscn")
	if scene == null:
		print("confirm dialog style: SKIP (scene missing)")
		return
	var s: Control = scene.instantiate()

	# Build the custom modal in isolation (does not need the scene in-tree).
	s.call("_build_confirm_dialog")

	var title_label: Label = s.get("_confirm_title")
	var ok: Button = s.get("_confirm_ok")
	var card: PanelContainer = s.get("_confirm_card")

	var ok_font: int = ok.get_theme_font_size("font_size")
	var ok_min: Vector2 = ok.custom_minimum_size
	var title_font: int = title_label.get_theme_font_size("font_size")
	var card_style: StyleBox = card.get_theme_stylebox("panel")

	var ok_pass: bool = title_font >= 40 \
		and ok_font >= 32 and ok_min.x >= 200 \
		and card_style is StyleBoxFlat
	print("confirm dialog style: ", "PASS" if ok_pass else "FAIL",
		" -> title_font=", title_font, " ok_font=", ok_font,
		" ok_min=", ok_min, " card_flat=", card_style is StyleBoxFlat)
	assert(ok_pass, "confirm dialog styling failed")

	# Clean up children created by the manual build.
	s.queue_free()
