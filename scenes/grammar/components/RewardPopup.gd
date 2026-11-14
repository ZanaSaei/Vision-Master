class_name RewardPopup
extends Control
# ============================================================
#  REWARD POPUP — Celebration & Mastery Screen
# ============================================================
#  Features:
#   1. Procedural confetti cannon celebration
#   2. Animated XP counting with star badge
#   3. Animated mastery progress bar & rank indicator
#   4. High-craft tactile primary & secondary action buttons
# ============================================================

signal next_requested
signal back_requested

var emoji_label: Label
var title_label: Label
var reward_label: Label
var bonus_label: Label
var rank_badge_panel: PanelContainer
var rank_label: Label
var mastery_bar: ProgressBar
var next_button: GrammarButton
var back_button: GrammarButton
var _card: PanelContainer


func _ready() -> void:
	_build_ui()
	_apply_theme()
	Global.on_theme_changed(_on_theme_changed)
	hide()


func _exit_tree() -> void:
	if is_instance_valid(Global) and Global.theme_changed.is_connected(_on_theme_changed):
		Global.theme_changed.disconnect(_on_theme_changed)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(840, 0)
	var card_style := GrammarTheme.rounded_box(Global.get_theme_color("surface"), 30, GrammarTheme.accent_color(), 2)
	card_style.shadow_color = Color(0, 0, 0, 0.35)
	card_style.shadow_size = 18
	card_style.shadow_offset = Vector2(0, 8)
	_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	_card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	emoji_label = Label.new()
	emoji_label.text = "🎉"
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.add_theme_font_size_override("font_size", 84)
	layout.add_child(emoji_label)

	title_label = Label.new()
	title_label.text = "بخش با موفقیت کامل شد!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	title_label.add_theme_font_size_override("font_size", 42)
	layout.add_child(title_label)

	reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	reward_label.add_theme_color_override("font_color", GrammarTheme.xp_color())
	reward_label.add_theme_font_size_override("font_size", 52)
	layout.add_child(reward_label)

	bonus_label = Label.new()
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	bonus_label.add_theme_color_override("font_color", GrammarTheme.success_color())
	bonus_label.add_theme_font_size_override("font_size", 30)
	bonus_label.visible = false
	layout.add_child(bonus_label)

	# Rank & Mastery Progress Mini-Card
	rank_badge_panel = PanelContainer.new()
	var rank_style := GrammarTheme.rounded_box(Global.get_theme_color("surface_alt"), 20, Global.get_theme_color("border"), 1)
	rank_badge_panel.add_theme_stylebox_override("panel", rank_style)
	layout.add_child(rank_badge_panel)

	var rank_margin := MarginContainer.new()
	rank_margin.add_theme_constant_override("margin_left", 22)
	rank_margin.add_theme_constant_override("margin_right", 22)
	rank_margin.add_theme_constant_override("margin_top", 16)
	rank_margin.add_theme_constant_override("margin_bottom", 16)
	rank_badge_panel.add_child(rank_margin)

	var rank_vbox := VBoxContainer.new()
	rank_vbox.add_theme_constant_override("separation", 10)
	rank_margin.add_child(rank_vbox)

	rank_label = Label.new()
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_override("font", GrammarTheme.get_fa_bold())
	rank_label.add_theme_font_size_override("font_size", 28)
	rank_vbox.add_child(rank_label)

	mastery_bar = ProgressBar.new()
	mastery_bar.show_percentage = false
	mastery_bar.custom_minimum_size = Vector2(0, 18)
	mastery_bar.add_theme_stylebox_override("background", GrammarTheme.rounded_box(GrammarTheme.disabled_color(), 10))
	mastery_bar.add_theme_stylebox_override("fill", GrammarTheme.rounded_box(GrammarTheme.xp_color(), 10))
	rank_vbox.add_child(mastery_bar)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	layout.add_child(spacer)

	next_button = GrammarButton.new()
	next_button.variant = GrammarButton.ButtonVariant.PRIMARY
	next_button.text = "ادامه به بخش بعد  🚀"
	next_button.min_height = 104
	next_button.font_size = 42
	next_button.custom_minimum_size = Vector2(0, 104)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(_on_next)
	layout.add_child(next_button)

	back_button = GrammarButton.new()
	back_button.variant = GrammarButton.ButtonVariant.SECONDARY
	back_button.text = "بازگشت به فهرست بخش‌ها"
	back_button.min_height = 96
	back_button.font_size = 34
	back_button.custom_minimum_size = Vector2(0, 96)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(_on_back)
	back_button.visible = false
	layout.add_child(back_button)


func _apply_theme() -> void:
	if _card != null:
		var card_style := GrammarTheme.rounded_box(Global.get_theme_color("surface"), 30, GrammarTheme.accent_color(), 2)
		card_style.shadow_color = Color(0, 0, 0, 0.35)
		card_style.shadow_size = 18
		card_style.shadow_offset = Vector2(0, 8)
		_card.add_theme_stylebox_override("panel", card_style)
	if title_label != null:
		title_label.add_theme_color_override("font_color", GrammarTheme.text_color())
	if reward_label != null:
		reward_label.add_theme_color_override("font_color", GrammarTheme.xp_color())
	if rank_badge_panel != null:
		rank_badge_panel.add_theme_stylebox_override("panel", GrammarTheme.info_card_style())


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()


func show_reward(title: String, awarded_xp: int, next_text: String = "ادامه به بخش بعد  🚀", show_back: bool = false, bonus_xp: int = 0) -> void:
	GrammarTheme.set_bidi_text(title_label, title)
	GrammarTheme.set_bidi_text(next_button, next_text)
	back_button.visible = show_back

	if bonus_xp > 0:
		bonus_label.visible = true
		GrammarTheme.set_bidi_text(bonus_label, "🔥 +%d XP پاداش پاسخ بدون اشتباه!" % bonus_xp)
	else:
		bonus_label.visible = false

	var mastery := GrammarData.get_mastery_status(Global.current_book, Global.current_lesson)
	var rank_str := "%s سطح تسلط: %s  (⭐ %d / %d XP)" % [
		mastery["rank_icon"],
		mastery["rank_title_fa"],
		mastery["current_xp"],
		mastery["base_max_xp"]
	]
	GrammarTheme.set_bidi_text(rank_label, rank_str)
	rank_label.add_theme_color_override("font_color", mastery["rank_color"])
	mastery_bar.add_theme_stylebox_override("fill", GrammarTheme.rounded_box(mastery["rank_color"], 10))
	mastery_bar.value = 0.0

	show()
	GrammarAnimation.pop(_card)
	GrammarAnimation.spawn_confetti(self, 85 if awarded_xp > 0 else 35)

	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(mastery_bar, "value", mastery["progress_ratio"] * 100.0, 0.75)

	if awarded_xp > 0:
		emoji_label.text = "🏆" if mastery["progress_ratio"] >= 1.0 else "🎉"
		Sfx.reward()
		t.parallel().tween_method(
			func(val: int) -> void: reward_label.text = "⭐ +%d XP" % val,
			0,
			awarded_xp,
			0.65
		)
	else:
		emoji_label.text = "✅"
		GrammarTheme.set_bidi_text(reward_label, "⭐ مرور مجدد (امتیاز قبلاً دریافت شده)")


func _on_next() -> void:
	hide()
	next_requested.emit()


func _on_back() -> void:
	hide()
	back_requested.emit()
