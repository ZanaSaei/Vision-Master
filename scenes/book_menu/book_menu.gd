extends "res://autoload/BackButtonHandler.gd"
############################################################
#BOOK MENU
#Reads Global.current_book to build lesson buttons dynamically.
#Vision 1 has 4 lessons; Vision 2 & 3 have 3 each.
#Navigation uses the SLIDE transition:
#lesson tap -> slide forward (content exits left)
#back tap   -> slide back    (content exits right)
#The animated background lives in the MenuBackground autoload.
############################################################
const SCENE_MAIN_MENU = "res://scenes/main_menu/MainMenu.tscn"
const SCENE_LESSON_MENU = "res://scenes/lesson_menu/LessonMenu.tscn"

# ---------- Font configuration ----------
const FONT_JAKARTA_REGULAR_PATH = "res://assets/fonts/PlusJakartaSans-Regular.ttf"
const FONT_JAKARTA_BOLD_PATH = "res://assets/fonts/PlusJakartaSans-Bold.ttf"

var font_regular: FontFile
var font_bold: FontFile
var _navigating := false

const LESSON_DATA = {
	1: [
		"Lesson 1 — Saving Nature",
		"Lesson 2 — Wonders of Creation",
		"Lesson 3 — The Value of Knowledge",
		"Lesson 4 — Traveling the World",
	],
	2: [
		"Lesson 1 — Understanding People",
		"Lesson 2 — A Healthy Lifestyle",
		"Lesson 3 — Art and Culture",
	],
	3: [
		"Lesson 1 — Sense of Appreciation",
		"Lesson 2 — Look It Up!",
		"Lesson 3 — Renewable Energy",
	],
}

const BOOK_COLORS = {
	1: Color("#2563EB"),   # Blue   — Vision 1
	2: Color("#16A34A"),   # Green  — Vision 2
	3: Color("#EA580C"),   # Orange — Vision 3
}

const BOOK_BG_COLORS = {
	1: Color("#EFF6FF"),
	2: Color("#F0FDF4"),
	3: Color("#FFF7ED"),
}

@onready var back_button: Button              = $PanelContainer/TopBar/BackButton
@onready var top_bar_title: Label             = $PanelContainer/TopBar/TopBarTitle
@onready var lessons_container: VBoxContainer = $MainLayout/InnerLayout/LessonsContainer
@onready var hero_label: Label                = $MainLayout/InnerLayout/HeroLabel

# --- Glossy + border-comet state ---
const CORNER_RADIUS = 26.0
var _lesson_mats: Array[ShaderMaterial] = []
var _lesson_btns: Array[Button]         = []
var _border_shader: Shader = null

func _ready() -> void:
	var legacy_bg := get_node_or_null("AnimatedBackground")
	if legacy_bg:
		legacy_bg.visible = false
		legacy_bg.queue_free()

	back_button.pivot_offset = back_button.size / 2.0

	_load_fonts()
	_apply_fonts_to_labels()
	back_button.button_up.connect(_on_back_button_pressed)

	var book: int = Global.current_book
	top_bar_title.text = "Vision %d" % book
	_build_lesson_buttons(book)

	# Let the layout settle, then feed the shaders their real pixel sizes.
	_finalize_shine_sizes()

	Global.on_theme_changed(_on_theme_changed)
	_apply_theme()


func _apply_theme() -> void:
	if not is_inside_tree():
		return
	# Hero prompt: keep the current black text in dark mode, use the
	# palette text color in light mode.
	hero_label.add_theme_color_override(
		"font_color",
		Color(0, 0, 0, 1) if Global.theme_is_dark() else Global.get_theme_color("text")
	)


func _on_theme_changed(_mode: int) -> void:
	if not is_inside_tree():
		return
	_apply_theme()


func _load_fonts() -> void:
	font_regular = load(FONT_JAKARTA_REGULAR_PATH)
	font_bold = load(FONT_JAKARTA_BOLD_PATH)
	if font_regular == null:
		push_warning("Regular font not found at: " + FONT_JAKARTA_REGULAR_PATH)
	if font_bold == null:
		push_warning("Bold font not found at: " + FONT_JAKARTA_BOLD_PATH)

func _apply_fonts_to_labels() -> void:
	if font_bold != null:
		top_bar_title.add_theme_font_override("font", font_bold)


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
		"// Signed distance function for rounded rectangle",
		"float sd_round_box(vec2 p, vec2 b, float r) {",
		"    vec2 q = abs(p) - b + vec2(r);",
		"    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;",
		"}",
		"",
		"void fragment() {",
		"    vec4 base = COLOR * texture(TEXTURE, UV);",
		"    vec2 half_size = rect_size * 0.5;",
		"    // Convert UV coordinates to pixel coordinates centered on the button",
		"    vec2 uv_centered = UV * rect_size - half_size;",
		"    float r = clamp(corner_radius, 0.0, min(half_size.x, half_size.y) - 1.0);",
		"    float sd = sd_round_box(uv_centered, half_size, r);",
		"",
		"    // Only apply effects to the border area (outer pixels)",
		"    // This prevents the shader from affecting the text area",
		"    float border_mask = 1.0 - smoothstep(-4.0, 2.0, sd);",
		"",
		"    // Create core and halo effects for the border ring",
		"    float core = smoothstep(1.6, 0.0, abs(sd));",
		"    float halo = exp(-abs(sd) / ring_soft);",
		"    float ring = max(core, halo * 0.6) * border_mask;",
		"",
		"    // Calculate angle-based animation for the orbiting comet",
		"    float ang  = atan(uv_centered.y, uv_centered.x);",
		"    float t    = (ang + 3.14159265) / 6.28318530;",
		"    float head = fract(TIME * speed + phase);",
		"    float back = fract(head - t + 1.0);",
		"",
		"    // Create comet tail and hot spot effects",
		"    float tail = pow(smoothstep(tail_len, 0.0, back), 1.4);",
		"    float hot  = smoothstep(0.05, 0.0, back);",
		"    float comet = (tail + hot * 1.6) * border_mask;",
		"",
		"    // Color calculations for the comet and rim",
		"    vec3 tail_col = accent * 1.25;",
		"    vec3 comet_col = mix(tail_col, vec3(1.0), smoothstep(0.12, 0.0, back));",
		"    float rim_base = halo * 0.18 * border_mask;",
		"",
		"    // Combine all effects into final color",
		"    vec3  add   = comet_col * comet * ring + accent * rim_base;",
		"    float add_a = (comet * ring + rim_base) * glow;",
		"    COLOR = vec4(base.rgb + add, clamp(base.a + add_a, 0.0, 1.0));",
		"}",
	])

func _ensure_border_shader() -> void:
	if _border_shader == null:
		_border_shader = Shader.new()
		_border_shader.code = _border_shine_source()

func _apply_glossy_style(btn: Button, accent: Color) -> void:
	if btn.pivot_offset == Vector2.ZERO:
		btn.pivot_offset = btn.size / 2.0

	var fill := Color(accent.r, accent.g, accent.b, 0.34)
	var rim: Color = accent.lerp(Color.WHITE, 0.55)
	rim.a = 0.75
	var glow := Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.55)

	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(CORNER_RADIUS))
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color = rim
	style.shadow_color = glow
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(accent.r, accent.g, accent.b, 0.50)
	hover_style.shadow_size = 22
	btn.add_theme_stylebox_override("hover", hover_style)

	var press_style := style.duplicate() as StyleBoxFlat
	press_style.bg_color = Color(accent.r, accent.g, accent.b, 0.24)
	press_style.shadow_size = 8
	press_style.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("pressed", press_style)

	var focus_style := hover_style.duplicate() as StyleBoxFlat
	focus_style.border_color = accent.lerp(Color.WHITE, 0.8)
	focus_style.border_color.a = 0.9
	btn.add_theme_stylebox_override("focus", focus_style)

func _attach_border_comet(btn: Button, accent: Color, phase: float) -> ShaderMaterial:
	_ensure_border_shader()
	var mat := ShaderMaterial.new()
	mat.shader = _border_shader
	mat.set_shader_parameter("corner_radius", CORNER_RADIUS)
	mat.set_shader_parameter("accent", Vector3(accent.r, accent.g, accent.b))
	mat.set_shader_parameter("phase", phase)
	_set_btn_border_size(mat, btn)
	
	# Create a transparent overlay just for the border comet effect
	var overlay := ColorRect.new()
	overlay.material = mat
	overlay.color = Color.TRANSPARENT  # Transparent - let the glossy background show through
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill the entire button
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass clicks through to button
	
	# Add the overlay as a child of the button, on top of the background but behind text
	btn.add_child(overlay)
	btn.move_child(overlay, 0)  # Move to the very back (behind text)
	
	btn.resized.connect(_set_btn_border_size.bind(mat, btn))
	return mat

func _set_btn_border_size(mat: ShaderMaterial, btn: Button) -> void:
	var rs := btn.size
	if rs.x < 1.0 or rs.y < 1.0:
		rs = Vector2(600.0, 150.0)
	mat.set_shader_parameter("rect_size", rs)

func _finalize_shine_sizes() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(_lesson_mats.size()):
		_set_btn_border_size(_lesson_mats[i], _lesson_btns[i])

func _build_lesson_buttons(book: int) -> void:
	var lessons: Array = LESSON_DATA.get(book, [])
	var accent_color: Color = BOOK_COLORS.get(book, Color("#2563EB"))

	for i in lessons.size():
		var btn := Button.new()
		btn.text = lessons[i]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		_apply_glossy_style(btn, accent_color)

		if font_regular != null:
			btn.add_theme_font_override("font", font_regular)
		btn.add_theme_font_size_override("font_size", 55)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		btn.add_theme_constant_override("outline_size", 2)

		var mat := _attach_border_comet(btn, accent_color, float(i) * 0.18)
		_lesson_mats.append(mat)
		_lesson_btns.append(btn)

		btn.pressed.connect(_on_lesson_pressed.bind(i + 1))
		lessons_container.add_child(btn)

		btn.mouse_entered.connect(_on_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_hover.bind(btn, false))
		btn.button_down.connect(_on_press.bind(btn))
		btn.button_up.connect(_on_release.bind(btn))

func _on_hover(btn: Button, hovering: bool) -> void:
	var s := 1.03 if hovering else 1.0
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(s, s), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_press(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_release(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_lesson_pressed(lesson_number: int) -> void:
	if _navigating:
		return
	_navigating = true
	Global.current_lesson = lesson_number
	TransitionManager.slide_change_scene(SCENE_LESSON_MENU, TransitionManager.Slide.FORWARD)

func _on_back_button_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	var tween := create_tween()
	tween.tween_property(back_button, "scale", Vector2(0.96, 0.96), 0.08)
	await tween.finished
	TransitionManager.slide_change_scene(SCENE_MAIN_MENU, TransitionManager.Slide.BACK)

func _on_android_back_pressed() -> void:
	_on_back_button_pressed()
