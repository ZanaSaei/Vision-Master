extends CanvasLayer
############################################################
# MENU BACKGROUND (autoload "MenuBackground")
# One persistent AnimatedBackground shared by MainMenu,
# BookMenu and LessonMenu. It lives on a canvas layer behind
# everything, so it survives change_scene_to_file() and never
# slides or restarts when the three menus swap.
#
# It still plays its own corner animations when the app leaves
# or re-enters the menu family:
#   lesson -> section : corners move away (play_exit), then fade
#   section -> any menu: corners grow back (play_enter)
############################################################

# The single background instance, alive for the whole session.
var background: AnimatedBackground

# True while the background fully covers the screen.
# Guards against replaying enter/exit when nothing actually changed.
var is_showing := true


func _ready() -> void:
	# Draw behind every scene's own canvas (default scene layer is 0).
	layer = -100

	# Create the background once, in code — no .tscn needed.
	# AnimatedBackground is Node2D-based (not a Control): it draws
	# from the origin, covers the viewport on its own, and never
	# blocks UI input.
	background = AnimatedBackground.new()
	add_child(background)

	# One intro at app start, ambient forever after.
	background.play_enter()
	is_showing = true


############################################################
# Corners move away — call BEFORE leaving the menu family
# (lesson menu -> a section scene). Awaitable: the caller
# waits for the animation to finish before fading out.
############################################################
func exit_background() -> void:
	if not is_showing:
		return                     # already exited — nothing to play
	is_showing = false
	await background.play_exit()


############################################################
# Corners grow back — call when a menu is re-entered from a
# section scene. Fire-and-forget: it animates while the menu
# content slides / fades in.
############################################################
func enter_background() -> void:
	if is_showing:
		return                     # already covering the screen
	is_showing = true
	background.play_enter()


############################################################
# Retint the whole animated background for the active theme
# (called by Global, the single theme owner). base_color + wave gradient colors.
############################################################
func apply_theme(bg: Color, wave_top: Color, wave_mid: Color, wave_bottom: Color) -> void:
	if background == null:
		return
	background.apply_theme(bg, wave_top, wave_mid, wave_bottom)
