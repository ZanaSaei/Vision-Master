extends "res://autoload/BackButtonHandler.gd"

############################################################
# MAIN MENU — modern, animated, alive (Godot 4.7 / GDScript)
# Light Theme Adaptation
############################################################

# --- Scene paths ---
const SCENE_BOOK_MENU        := "res://scenes/book_menu/BookMenu.tscn"
const SCENE_SAVED_WORDS      := "res://scenes/saved_words/SavedWords.tscn"
const SCENE_SETTINGS         := "res://scenes/settings/Settings.tscn"
const SCENE_FINAL_EXAMS      := "res://scenes/exam/FinalExams.tscn"
const SCENE_PURCHASE         := "res://scenes/purchase/Purchase.tscn"
const SCENE_LEITNER          := "res://scenes/review/WordReview.tscn"
const SCENE_ABOUT_ME         := "res://scenes/about_me/AboutMe.tscn"
const SCENE_MAIN_MENU        := "res://scenes/main_menu/MainMenu.tscn"

# --- Per-button accent colors (Mapped to new palette) ---
const COLOR_CONTINUE  := Color("3d0070ff") # Primary (Hero action)
const COLOR_BOOK1     := Color("0b338dff") # Primary
const COLOR_BOOK2     := Color("006b1bff") # Primary Hover
const COLOR_BOOK3     := Color("882815ff") # Text (Dark Navy for premium feel)
const COLOR_SPECIFIC  := Color("95009aff") # Accent
const COLOR_HAMBURGER := Color("#64748B") # Muted Text

# --- Hamburger gloss tail ---
const HAMBURGER_GLOSS_EXTEND := 200.0
const HAMBURGER_GLOSS_DIR := 1   # 1 = tail to the RIGHT, -1 = to the LEFT

# --- Node references (match your scene tree exactly) ---
@onready var continue_button: Button         = $MainLayout/InnerLayout/ContinueButton
@onready var book1_button: Button            = $MainLayout/InnerLayout/Book1Button
@onready var book2_button: Button            = $MainLayout/InnerLayout/Book2Button
@onready var book3_button: Button            = $MainLayout/InnerLayout/Book3Button
@onready var exam_button: Button             = $MainLayout/InnerLayout/Exam
@onready var app_title: Label                = $MainLayout/InnerLayout/HeroSection/AppTitle
@onready var app_subtitle: Label             = $MainLayout/InnerLayout/HeroSection/AppSubtitle
@onready var choose_label: Label             = $MainLayout/InnerLayout/ChooseLabel
@onready var main_layout: Control            = $MainLayout
@onready var hamburger_button: Button        = $HamburgerButton
@onready var side_menu                       = $SideMenu

const FONT_LABEL := "res://assets/fonts/JosefinSans-Bold.ttf"
var font_title: FontFile

# --- Ambient / state ---
var _floating_letters: Array[Label] = []
var _navigating: bool = false        # blocks double-taps during navigation
var _ambient_bg: Control = null

const FLOATING_GLYPHS := ["V", "I", "S", "O", "N", "m", "a", "s", "t", "e", "r"]

# Moving-light materials built in code.
var _btn_border_mats: Array[ShaderMaterial] = []
var _btn_border_owners: Array[Button] = []

# Hamburger gloss tail (built in code).
var _hamburger_gloss: Panel = null
var _hg_styles: Dictionary = {}

############################################################
# READY
############################################################
func _ready() -> void:
	# The background now lives in the MenuBackground autoload.
	var legacy_bg := get_node_or_null("AnimatedBackground")
	if legacy_bg:
		legacy_bg.visible = false
		legacy_bg.queue_free()

	# 1. Button signals
	continue_button.pressed.connect(_on_continue_pressed)
	book1_button.pressed.connect(_on_book_pressed.bind(1))
	book2_button.pressed.connect(_on_book_pressed.bind(2))
	book3_button.pressed.connect(_on_book_pressed.bind(3))
	exam_button.pressed.connect(_on_exam_pressed)

	# 2. Logo / wordmark styling (set BEFORE pivots so sizes are right)
	_style_logo()
	
	# 2b. Moving specular shine ON the wordmark (after the font is set)
	_setup_title_shine()
	
	# 3. Pivots (needed before any scale animation)
	_setup_pivots()
	
	# 4. Side menu wiring
	side_menu.set_hamburger_button(hamburger_button)
	hamburger_button.pressed.connect(side_menu.toggle)
	side_menu.saved_words_pressed.connect(_on_side_menu_saved_words_pressed)
	side_menu.settings_pressed.connect(_on_side_menu_settings_pressed)
	side_menu.purchase_pressed.connect(_on_side_menu_purchase_pressed)
	side_menu.leitner_pressed.connect(_on_side_menu_leitner_pressed) 
	side_menu.about_me_pressed.connect(_on_side_menu_about_me_pressed)
	
	# 5. Solid premium cards — each tile gets its palette hue
	_apply_glass_style(continue_button, COLOR_CONTINUE)
	_apply_glass_style(book1_button, COLOR_BOOK1)
	_apply_glass_style(book2_button, COLOR_BOOK2)
	_apply_glass_style(book3_button, COLOR_BOOK3)
	_apply_glass_style(exam_button, COLOR_SPECIFIC)
	continue_button.add_theme_font_size_override("font_size", 64)
	
	# 5b. A comet of light racing around every button's outline
	_setup_border_shine()
	
	# 6. Hover / press micro-interactions
	_setup_button_effects()
	
	# 7. Text + visibility
	_setup_book_buttons()
	_setup_continue_button()
	
	# 8. Ambient drifting glyphs (behind the UI)
	_create_floating_letters()
	
	# 9. Hamburger gloss tail (built AFTER floaters so z-order is right)
	_setup_hamburger_gloss()
	
	# 10. Make sure every shine shader knows its true pixel size
	_finalize_shine_sizes()

	# 10b. Theme awareness (menu button + labels follow Dark / Light)
	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()

	# 11. Entrance — cinematic stagger (ambient starts when it finishes)
	if not Global.intro_animation_played:
		Global.intro_animation_played = true
		_play_intro_animation()
	else:
		_skip_intro_animation()
		_start_ambient()

############################################################
# THEME AWARENESS — MainMenu stays brand-consistent in both
# themes: coloured glass cards + white text read on any backdrop,
# so only the menu button and plain labels need adjusting.
############################################################
func _on_theme_changed(_mode: int) -> void:
	_apply_theme()


func _apply_theme() -> void:
	# Hamburger / menu button — keep it clearly readable on the theme backdrop.
	# The button itself stays chrome-free (transparent); the separate gloss
	# tail panel behind it carries the box + border, so we must NOT paint a
	# bordered stylebox here or it would draw a stray inner frame.
	var hb_style := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		hamburger_button.add_theme_stylebox_override(s, hb_style)
	hamburger_button.add_theme_color_override("font_color", Color.WHITE)
	hamburger_button.add_theme_color_override("font_hover_color", Color.WHITE)
	hamburger_button.add_theme_color_override("font_pressed_color", Color.WHITE)

	# Choose-label follows the theme so it never disappears.
	choose_label.add_theme_color_override("font_color", Global.get_theme_color("text"))


############################################################
# LOGO — bold, high-contrast wordmark for "Vision Master"
############################################################
func _style_logo() -> void:
	app_title.text = "Vision\nMaster"
	app_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app_title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	app_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	font_title = load(FONT_LABEL)
	app_title.add_theme_font_override("font", font_title)
	app_title.add_theme_font_size_override("font_size", 180)
	
	# Light theme: Primary text with a crisp white sticker-outline
	app_title.add_theme_color_override("font_color", Color("f4262aff"))
	app_title.add_theme_color_override("font_outline_color", Color("#FFFFFF"))
	app_title.add_theme_constant_override("outline_size", 16)
	app_title.add_theme_color_override("font_shadow_color", Color("#0F172A", 0.15))
	app_title.add_theme_constant_override("shadow_offset_x", 0)
	app_title.add_theme_constant_override("shadow_offset_y", 8)
	
	app_subtitle.add_theme_font_size_override("font_size", 26)
	app_subtitle.add_theme_color_override("font_color", Color("#64748B")) # Muted Text
	app_subtitle.add_theme_color_override("font_outline_color", Color("#FFFFFF"))
	app_subtitle.add_theme_constant_override("outline_size", 4)

############################################################
# TITLE SHINE — specular highlight raking across the letters
############################################################
func _title_shine_source() -> String:
	return "\n".join([
		"shader_type canvas_item;",
		"",
		"uniform float speed : hint_range(0.0, 1.0) = 0.30;",
		"uniform float sweep_frac : hint_range(0.1, 1.0) = 0.45;",
		"uniform float band_px : hint_range(10.0, 400.0) = 90.0;",
		"uniform float tilt : hint_range(-1.0, 1.0) = 0.30;",
		"uniform float label_w : hint_range(1.0, 4000.0) = 1080.0;",
		"uniform float label_h : hint_range(1.0, 4000.0) = 420.0;",
		# Soft light-blue shine to match Primary theme
		"uniform vec3 shine_col : source_color = vec3(0.23, 0.51, 0.96);",
		"uniform float shine_str : hint_range(0.0, 4.0) = 1.2;",
		"",
		"void fragment() {",
		"    vec4 base = COLOR * texture(TEXTURE, UV);",
		"    float d = VERTEX.x + VERTEX.y * tilt;",
		"    float span = label_w + label_h * abs(tilt);",
		"    float cycle = fract(TIME * speed);",
		"    float sweep = clamp(cycle / sweep_frac, 0.0, 1.0);",
		"    float margin = band_px * 2.0;",
		"    float pos = mix(-margin, span + margin, sweep);",
		"    float band = smoothstep(band_px, 0.0, abs(d - pos));",
		"    vec3 shine = shine_col * band * shine_str * base.a;",
		"    COLOR = vec4(base.rgb + shine, base.a);",
		"}",
	])

func _setup_title_shine() -> void:
	var sh := Shader.new()
	sh.code = _title_shine_source()
	var mat := ShaderMaterial.new()
	mat.shader = sh
	app_title.material = mat
	# Re-measure whenever the label changes size.
	app_title.resized.connect(_set_title_shine_size)

func _set_title_shine_size() -> void:
	if not (app_title.material is ShaderMaterial):
		return
	# Feed the shader the real pixel size of the label.
	var w := app_title.size.x if app_title.size.x > 1.0 else 1080.0
	var h := app_title.size.y if app_title.size.y > 1.0 else 420.0
	app_title.material.set_shader_parameter("label_w", w)
	app_title.material.set_shader_parameter("label_h", h)

############################################################
# BORDER COMET — light racing around each button's outline
############################################################
func _border_shine_source() -> String:
	return "\n".join([
		"shader_type canvas_item;",
		"",
		"uniform float speed : hint_range(0.0, 1.0) = 0.28;",
		"uniform float phase : hint_range(0.0, 1.0) = 0.0;",
		"uniform float tail_len : hint_range(0.05, 0.8) = 0.32;",
		"uniform float ring_soft : hint_range(0.5, 8.0) = 2.6;",
		"uniform float glow : hint_range(0.0, 2.0) = 0.95;",
		"uniform float corner_radius : hint_range(0.0, 200.0) = 26.0;",
		"uniform vec2 rect_size = vec2(600.0, 150.0);",
		"uniform vec3 accent : source_color = vec3(0.3, 0.82, 0.96);",
		"",
		"float sd_round_box(vec2 p, vec2 b, float r) {",
		"    vec2 q = abs(p) - b + vec2(r);",
		"    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;",
		"}",
		"",
		"void fragment() {",
		"    vec4 base = COLOR * texture(TEXTURE, UV);",
		"    vec2 half_size = rect_size * 0.5;",
		"    vec2 p = VERTEX - half_size;",
		"    float r = clamp(corner_radius, 0.0, min(half_size.x, half_size.y) - 1.0);",
		"    float sd = sd_round_box(p, half_size, r);",
		"",
		"    float core = smoothstep(1.6, 0.0, abs(sd));",
		"    float halo = exp(-abs(sd) / ring_soft);",
		"    float ring = max(core, halo * 0.6);",
		"",
		"    float ang  = atan(p.y, p.x);",
		"    float t    = (ang + 3.14159265) / 6.28318530;",
		"    float head = fract(TIME * speed + phase);",
		"    float back = fract(head - t + 1.0);",
		"",
		"    float tail = pow(smoothstep(tail_len, 0.0, back), 1.4);",
		"    float hot  = smoothstep(0.05, 0.0, back);",
		"    float comet = tail + hot * 1.6;",
		"",
		"    vec3 tail_col = accent * 1.25;",
		"    vec3 comet_col = mix(tail_col, vec3(1.0), smoothstep(0.12, 0.0, back));",
		"    float rim_base = halo * 0.18;",
		"",
		"    vec3  add   = comet_col * comet * ring + accent * rim_base;",
		"    float add_a = (comet * ring + rim_base) * glow;",
		"    COLOR = vec4(base.rgb + add, clamp(base.a + add_a, 0.0, 1.0));",
		"}",
	])

func _setup_border_shine() -> void:
	var sh := Shader.new()
	sh.code = _border_shine_source()
	
	# [button, corner radius (matches its stylebox), accent hue]
	var specs: Array = [
		[continue_button, 26.0, COLOR_CONTINUE],
		[book1_button, 26.0, COLOR_BOOK1],
		[book2_button, 26.0, COLOR_BOOK2],
		[book3_button, 26.0, COLOR_BOOK3],
		[exam_button, 26.0, COLOR_SPECIFIC],
		[hamburger_button, 20.0, COLOR_HAMBURGER],
	]
	
	for i in range(specs.size()):
		var btn: Button = specs[i][0]
		var radius: float = specs[i][1]
		var accent: Color = specs[i][2]
		
		var mat := ShaderMaterial.new()
		mat.shader = sh   # one shader shared, per-button parameters
		mat.set_shader_parameter("corner_radius", radius)
		mat.set_shader_parameter("accent", Vector3(accent.r, accent.g, accent.b))
		# Stagger the comets so they never march in unison.
		mat.set_shader_parameter("phase", float(i) * 0.16)
		_set_btn_border_size(mat, btn)   # safe initial size
		
		btn.material = mat
		# Keep the shader in sync if the button resizes.
		btn.resized.connect(_set_btn_border_size.bind(mat, btn))
		_btn_border_mats.append(mat)
		_btn_border_owners.append(btn)

func _set_btn_border_size(mat: ShaderMaterial, btn: Button) -> void:
	var rs := btn.size
	if rs.x < 1.0 or rs.y < 1.0:   # not laid out yet — use a sane default
		rs = Vector2(600.0, 150.0)
	mat.set_shader_parameter("rect_size", rs)

# Re-measure a couple of frames after layout settles
func _finalize_shine_sizes() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_set_title_shine_size()
	for i in range(_btn_border_mats.size()):
		_set_btn_border_size(_btn_border_mats[i], _btn_border_owners[i])

############################################################
# HAMBURGER GLOSS TAIL — Surface panel glued to the ☰ button
############################################################
func _make_neutral_style(bg_col: Color, border_col: Color, shadow_size: int, shadow_off_y: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.set_corner_radius_all(20)
	s.border_width_left = 2; s.border_width_top = 2
	s.border_width_right = 2; s.border_width_bottom = 2
	s.border_color  = border_col
	s.shadow_color  = Color(0, 0, 0, 0.08) # Soft light-mode shadow
	s.shadow_size   = shadow_size
	s.shadow_offset = Vector2(0, shadow_off_y)
	return s

func _setup_hamburger_gloss() -> void:
	var keep_size := hamburger_button.size
	
	# Strip the hamburger's own chrome — the tail panel carries the gloss.
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		hamburger_button.add_theme_stylebox_override(st, empty)
		
	hamburger_button.custom_minimum_size = keep_size
	hamburger_button.pivot_offset = keep_size / 2.0
	
	# Three gloss variants swapped on hover/press using palette colors.
	_hg_styles["normal"] = _make_neutral_style(Color("004a4a"), Color("#E2E8F0"), 12, 4)
	_hg_styles["hover"]  = _make_neutral_style(Color("004a4a"), Color("#2563EB"), 16, 6) # Primary border on hover
	_hg_styles["press"]  = _make_neutral_style(Color("004a4a"), Color("#1D4ED8"), 6, 2)
	
	_hamburger_gloss = Panel.new()
	# Never steal touches from the button above it.
	_hamburger_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hamburger_gloss.add_theme_stylebox_override("panel", _hg_styles["normal"])
	add_child(_hamburger_gloss)
	
	# Sit directly behind the ☰ in draw order.
	move_child(_hamburger_gloss, hamburger_button.get_index())
	_sync_hamburger_gloss()

# Re-glue the gloss panel to the button every frame
func _sync_hamburger_gloss() -> void:
	if not _hamburger_gloss or not is_instance_valid(hamburger_button):
		return
		
	var bsize := hamburger_button.size
	var ext := HAMBURGER_GLOSS_EXTEND
	
	if HAMBURGER_GLOSS_DIR >= 0:
		# Tail extends to the right of the button.
		_hamburger_gloss.global_position = hamburger_button.global_position
		_hamburger_gloss.pivot_offset = Vector2(bsize.x * 0.5, bsize.y * 0.5)
	else:
		# Tail extends to the left of the button.
		_hamburger_gloss.global_position = hamburger_button.global_position - Vector2(ext, 0)
		_hamburger_gloss.pivot_offset = Vector2(bsize.x * 0.5 + ext, bsize.y * 0.5)
		
	_hamburger_gloss.size     = bsize + Vector2(ext, 0)
	
	# Mirror the button's animation state.
	_hamburger_gloss.scale    = hamburger_button.scale
	_hamburger_gloss.modulate = hamburger_button.modulate

func _process(_delta: float) -> void:
	_sync_hamburger_gloss()

############################################################
# PIVOTS
############################################################
func _setup_pivots() -> void:
	var nodes := [
		app_title, app_subtitle, choose_label,
		continue_button, book1_button, book2_button,
		book3_button, exam_button, hamburger_button,
	]
	for n in nodes:
		# Scale animations grow from the centre.
		if n is Control and n.pivot_offset == Vector2.ZERO:
			n.pivot_offset = n.size / 2.0

############################################################
# SOLID PREMIUM CARDS (per-accent)
############################################################
func _apply_glass_style(btn: Button, accent: Color) -> void:
	if btn.pivot_offset == Vector2.ZERO:
		btn.pivot_offset = btn.size / 2.0

	# Solid fill for clean light-mode UI
	var fill := accent
	# Slightly darker rim for definition
	var rim: Color = accent.darkened(0.15)
	# Soft, colored drop shadow
	var glow := Color(accent.r, accent.g, accent.b, 0.25)
	
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(26)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color  = rim
	style.shadow_color  = glow
	style.shadow_size   = 16
	style.shadow_offset = Vector2(0, 8)
	btn.add_theme_stylebox_override("normal", style)
	
	# Hover: slightly brighter/shadow grows
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color   = accent.lightened(0.05)
	hover_style.shadow_size = 22
	hover_style.shadow_offset = Vector2(0, 10)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed: dimmer fill, tight shadow
	var press_style := style.duplicate() as StyleBoxFlat
	press_style.bg_color      = accent.darkened(0.10)
	press_style.shadow_size   = 6
	press_style.shadow_offset = Vector2(0, 3)
	btn.add_theme_stylebox_override("pressed", press_style)
	
	# Focus: crisp bright rim for keyboard/gamepad navigation
	var focus_style := hover_style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color("#0F172A") # Text color
	focus_style.border_color.a = 0.9
	btn.add_theme_stylebox_override("focus", focus_style)
	
	# Label styling - High contrast text based on luminance
	var text_color := Color("#FFFFFF")
	if accent.get_luminance() > 0.6:
		text_color = Color("#0F172A")
		
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_font_size_override("font_size", 72)
	# Remove dark outline since background is solid and provides contrast
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.0))
	btn.add_theme_constant_override("outline_size", 0)

############################################################
# BUTTON MICRO-INTERACTIONS
############################################################
func _setup_button_effects() -> void:
	var buttons := [
		continue_button, book1_button, book2_button,
		book3_button, exam_button, hamburger_button,
	]
	for btn in buttons:
		btn.mouse_entered.connect(_on_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_hover.bind(btn, false))
		btn.button_down.connect(_on_press.bind(btn))
		btn.button_up.connect(_on_release.bind(btn))

func _on_hover(btn: Button, hovering: bool) -> void:
	# Gentle grow on hover, springy ease.
	var s := 1.05 if hovering else 1.0
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(s, s), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	# Swap the gloss panel style in sync with the button.
	if btn == hamburger_button and _hamburger_gloss:
		_hamburger_gloss.add_theme_stylebox_override(
			"panel", _hg_styles["hover" if hovering else "normal"])

func _on_press(btn: Button) -> void:
	# Quick squish on press.
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	if btn == hamburger_button and _hamburger_gloss:
		_hamburger_gloss.add_theme_stylebox_override("panel", _hg_styles["press"])

func _on_release(btn: Button) -> void:
	# Spring back to full size.
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	if btn == hamburger_button and _hamburger_gloss:
		_hamburger_gloss.add_theme_stylebox_override("panel", _hg_styles["normal"])

############################################################
# FLOATING GLYPHS (ambient, never steal touches)
############################################################
func _create_floating_letters() -> void:
	var vp := get_viewport().get_visible_rect().size
	for i in range(8):
		var label := Label.new()
		label.text = FLOATING_GLYPHS[randi() % FLOATING_GLYPHS.size()]
		label.add_theme_font_size_override("font_size", randi_range(48, 96))
		# Primary color, extremely subtle on light background
		label.add_theme_color_override("font_color", Color("#2563EB"))
		label.modulate.a = randf_range(0.04, 0.08)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		
		# Parented to MainLayout so the glyphs slide together with the UI
		main_layout.add_child(label)
		main_layout.move_child(label, 0)   # behind the UI elements
		_floating_letters.append(label)
		_animate_glyph(label)

func _animate_glyph(label: Label) -> void:
	var vp := get_viewport().get_visible_rect().size
	var dur := randf_range(9.0, 16.0)
	var tw := create_tween()
	
	# Slow sine drift on y, x and rotation, all in parallel.
	tw.tween_property(label, "position:y", randf_range(-120, vp.y + 120), dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(label, "position:x",
		label.position.x + randf_range(-220, 220), dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(label, "rotation_degrees",
		randf_range(-30, 30), dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# When the drift finishes, respawn at the bottom and loop forever.
	tw.finished.connect(func():
		label.position = Vector2(randf_range(0, vp.x), vp.y + 60)
		label.rotation_degrees = 0
		_animate_glyph(label)
	)

############################################################
# AMBIENT LIFE (starts after the intro so it never fights it)
############################################################
func _start_ambient() -> void:
	# The logo breathes, very slowly.
	var tw := create_tween().set_loops()
	tw.tween_property(app_title, "scale", Vector2(1.03, 1.03), 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(app_title, "scale", Vector2.ONE, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# Optional glow layer pulses if present in the scene.
	_ambient_bg = get_node_or_null("Background")
	if _ambient_bg is Control:
		var gw := create_tween().set_loops()
		gw.tween_property(_ambient_bg, "modulate", Color(0.95, 0.97, 1.0, 1.0), 4.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		gw.tween_property(_ambient_bg, "modulate", Color(1.0, 1.0, 1.0, 1.0), 4.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

############################################################
# CINEMATIC STAGGERED INTRO
############################################################
func _play_intro_animation() -> void:
	app_title.scale = Vector2(0.4, 0.4)
	app_title.modulate.a = 0.0

	var staggered: Array[Control] = [
		app_subtitle, continue_button, choose_label,
		book1_button, book2_button, book3_button,
		exam_button, hamburger_button,
	]
	for c in staggered:
		if c.visible:
			c.scale = Vector2(0.7, 0.7)
			c.modulate.a = 0.0

	await get_tree().process_frame
	if not is_inside_tree():
		return

	app_title.pivot_offset = app_title.size / 2.0
	for c in staggered:
		c.pivot_offset = c.size / 2.0

	var title_tw := create_tween()
	title_tw.parallel().tween_property(app_title, "scale", Vector2.ONE, 0.9) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_tw.parallel().tween_property(app_title, "modulate:a", 1.0, 0.5)

	var i := 0
	for c in staggered:
		if not c.visible:
			continue
		var start_delay := 0.45 + i * 0.09
		var tw := create_tween()
		tw.tween_interval(start_delay)
		tw.tween_property(c, "scale", Vector2.ONE, 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "modulate:a", 1.0, 0.35)
		i += 1

	await get_tree().create_timer(0.45 + staggered.size() * 0.09 + 0.55).timeout
	if not is_inside_tree():
		return

	_finalize_shine_sizes()
	_start_ambient()

func _skip_intro_animation() -> void:
	# Returning visit: everything just appears in its final state.
	app_title.scale = Vector2.ONE
	app_title.modulate.a = 1.0
	
	var staggered: Array[Control] = [
		app_subtitle, continue_button, choose_label,
		book1_button, book2_button, book3_button,
		exam_button, hamburger_button,
	]
	for c in staggered:
		c.scale = Vector2.ONE
		c.modulate.a = 1.0

############################################################
# TEXT / VISIBILITY
############################################################
func _setup_book_buttons() -> void:
	book1_button.text = "Vision 1 — دهم"
	book2_button.text = "Vision 2 — یازدهم"
	book3_button.text = "Vision 3 — دوازدهم"
	exam_button.text = "سوالات امتحانات نهایی"

func _setup_continue_button() -> void:
	# Only show Continue if there is actually somewhere to continue to.
	if Global.has_last_scene():
		continue_button.text = "▶ از اینجا ادامه دهید"
		continue_button.visible = true
	else:
		continue_button.visible = false

############################################################
# NAVIGATION
############################################################
func _on_continue_pressed() -> void:
	if _navigating:
		return
	var last := Global.get_last_scene()
	if last == "":
		return
	_navigating = true
	Global.button_bounce(continue_button)
	# Let the bounce read before the screen moves.
	await get_tree().create_timer(0.14).timeout
	TransitionManager.slide_change_scene(last, TransitionManager.Slide.FORWARD)

func _on_book_pressed(book_number: int) -> void:
	if _navigating:
		return
	_navigating = true
	Global.current_book = book_number
	
	# Find the tapped button so the bounce plays on the right tile.
	var btn: Button = book1_button
	match book_number:
		2: btn = book2_button
		3: btn = book3_button
		
	Global.button_bounce(btn)
	await get_tree().create_timer(0.14).timeout
	# Slide the whole screen left; the shared background stays put.
	TransitionManager.slide_change_scene(SCENE_BOOK_MENU, TransitionManager.Slide.FORWARD)

func _on_exam_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Global.button_bounce(exam_button)
	await get_tree().create_timer(0.14).timeout
	TransitionManager.slide_change_scene(SCENE_FINAL_EXAMS, TransitionManager.Slide.FORWARD)

func _on_side_menu_about_me_pressed() -> void:
	# Same guard pattern as saved_words_button's handler
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_ABOUT_ME)

# --- Side-menu destinations keep the classic FADE transition ---
func _on_side_menu_saved_words_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	Global.flashcard_mode = "saved"
	TransitionManager.change_scene(SCENE_SAVED_WORDS)

func _on_side_menu_leitner_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	# Came from MainMenu -> Back in WordReview returns here
	Global.word_review_return = SCENE_MAIN_MENU
	TransitionManager.change_scene(SCENE_LEITNER)

func _on_side_menu_settings_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_SETTINGS)

func _on_side_menu_purchase_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	TransitionManager.change_scene(SCENE_PURCHASE)

############################################################
# ANDROID BACK (double-tap to exit)
############################################################
func _on_android_back_pressed() -> void:
	var current_time := Time.get_unix_time_from_system()
	# Second press within the timeout window -> quit the app.
	if back_pressed_time > 0 and current_time - back_pressed_time < double_back_timeout:
		get_tree().quit()
	else:
		# First press -> warn the user and start the window.
		back_pressed_time = current_time
		_show_back_message()

func _show_back_message() -> void:
	var message := Label.new()
	message.text = "Press back again to exit"
	message.add_theme_font_size_override("font_size", 40)
	message.add_theme_color_override("font_color", Color("#FFFFFF"))
	message.add_theme_color_override("font_outline_color", Color("#0F172A"))
	message.add_theme_constant_override("outline_size", 4)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.anchor_left = 0.0; message.anchor_top = 0.0
	message.anchor_right = 1.0; message.anchor_bottom = 1.0
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message)

	var bg := ColorRect.new()
	bg.color = Color("#0F172A", 0.75)
	bg.anchor_left = 0.0; bg.anchor_top = 0.0
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return

	var tw := create_tween()
	tw.parallel().tween_property(bg, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(message, "modulate:a", 0.0, 0.3)
	await tw.finished
	if not is_inside_tree():
		return

	bg.queue_free()
	message.queue_free()
