extends CanvasLayer
############################################################
# TRANSITION MANAGER
# Two transition styles:
#   change_scene()       -> fade to black. Still used by the
#                           side-menu destinations (Saved Words,
#                           Settings, Purchase) and any scene
#                           outside the menu flow.
#   slide_change_scene() -> horizontal push used by the menu
#                           flow (Main <-> Book <-> Lesson and
#                           their drill-downs). Content exits
#                           LEFT when going deeper, RIGHT when
#                           going back. The shared background
#                           (MenuBackground autoload) is never
#                           touched by either transition.
############################################################

# Direction of a slide transition.
# FORWARD = going deeper (main -> book -> lesson -> section)
# BACK    = going up one level
enum Slide { FORWARD, BACK }

# --- Fade settings (unchanged) ---
var transition_color := Color.BLACK
var fade_duration := 0.2          # duration of one fade leg, seconds
var color_rect: ColorRect         # full-screen black overlay used by the fade

# --- Slide settings ---
const SLIDE_EXIT_TIME  := 0.40    # how fast the old screen leaves
const SLIDE_ENTER_TIME := 0.50    # how fast the new screen settles in
const SLIDE_MARGIN     := 240.0   # extra travel so glows/shadows fully clear
const EXIT_SCALE       := 0.94    # old screen shrinks a touch as it leaves
const ENTER_SCALE      := 1.04    # new screen arrives slightly big, settles to 1

# Guards against double-taps starting a second slide mid-transition.
var _slide_busy := false
# Same guard for the fade transition (change_scene).
var _fade_busy := false
# Scene change requested while a fade is already running: parked here and
# started as soon as the in-flight change settles, instead of being dropped.
var _pending_scene: String = ""
# Destination of the in-flight fade, so a repeat request for it (double-tap)
# can be recognised and ignored.
var _active_scene: String = ""


func _ready() -> void:
	# Build the fade overlay in code so no scene editing is required.
	color_rect = ColorRect.new()
	color_rect.color = transition_color
	color_rect.visible = false
	# Block touches while the screen is black.
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# Anchor to all four edges so it always fills the viewport.
	color_rect.anchor_left = 0.0
	color_rect.anchor_top = 0.0
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(color_rect)


############################################################
# FADE — classic transition, unchanged.
# Side-menu buttons keep using this, per your requirement.
############################################################
func change_scene(scene_path: String) -> void:
	# Guard: a second tap while a fade is running would start an
	# overlapping fade and double-swap the scene. Park the request
	# instead of dropping it: a screen may legitimately navigate from
	# inside its own _ready() while the fade that delivered it is still
	# running (Saved Words checks the word list and routes straight on
	# to the flashcards). Dropping that call used to strand the user on
	# a pass-through screen. A repeat of the in-flight target is just a
	# double-tap and is ignored.
	if _fade_busy:
		if scene_path != _active_scene and scene_path != _pending_scene:
			_pending_scene = scene_path
		return

	_fade_busy = true
	var target := scene_path
	# True once the overlay is fully opaque. A chained swap runs while the
	# screen is still black, so its fade-out must not reset the overlay to
	# transparent first — that would flash the outgoing screen for a frame.
	var black := false

	while true:
		_active_scene = target
		await _fade_out(black)
		# 2. Swap the scene while nothing is visible.
		get_tree().change_scene_to_file(target)
		# 3. Give the new scene two frames to finish layout before revealing.
		await get_tree().process_frame
		await get_tree().process_frame
		black = true

		# The new screen may already have queued its own navigation (the
		# Saved Words pass-through above). Chain straight into it while the
		# screen is still black instead of revealing a screen nobody wants.
		if _pending_scene != "" and _pending_scene != target:
			target = _pending_scene
			_pending_scene = ""
			continue

		_pending_scene = ""
		# 4. Fade back in.
		await _fade_in()
		black = false
		# A request that arrived during the fade-in still needs a cycle of
		# its own; anything else (including a repeat of this target) is done.
		if _pending_scene == "" or _pending_scene == target:
			_pending_scene = ""
			break
		target = _pending_scene
		_pending_scene = ""

	_active_scene = ""
	_fade_busy = false


## Fades the overlay to opaque. `already_black` is set when a chained swap
## starts while the overlay is already opaque: the overlay stays black and
## only the transparent reset is skipped, so the outgoing screen never flashes.
func _fade_out(already_black: bool = false) -> void:
	color_rect.visible = true
	if not already_black:
		color_rect.color = Color(0, 0, 0, 0)   # start fully transparent
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, fade_duration)
	await tween.finished


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	color_rect.visible = false             # hide so it never eats touches


############################################################
# SLIDE — the menu-flow transition.
# FORWARD: old content exits LEFT,  new content enters from RIGHT
# BACK:    old content exits RIGHT, new content enters from LEFT
#
# Flash-free by design: the incoming screen is parked off-screen
# in the SAME frame it is swapped in (before anything renders),
# layout is then allowed to settle while it is invisible, and
# only then does it slide home.
############################################################
func slide_change_scene(scene_path: String, direction: Slide) -> void:
	# Ignore any tap that arrives while a slide is already running.
	if _slide_busy:
		return
	_slide_busy = true

	# Total horizontal distance: full screen width + margin for shadows.
	var travel := get_viewport().get_visible_rect().size.x + SLIDE_MARGIN
	# Negative = move left (forward), positive = move right (back).
	var exit_offset := -travel if direction == Slide.FORWARD else travel

	# --- Phase 1: push the current screen out. ---
	var old_nodes := _slidable_nodes(get_tree().current_scene)
	if old_nodes.size() > 0:
		# Centre pivots so the exit shrink reads as "pushed backwards".
		# Sizes are valid here — this scene has been live for a while.
		for n in old_nodes:
			if n is Control:
				n.pivot_offset = n.size / 2.0

		var tw_out := create_tween()
		# Ease-in: accelerate off-screen so the corners visibly sweep out.
		tw_out.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		for n in old_nodes:
			# Every node travels the same delta — the screen moves as one.
			tw_out.parallel().tween_property(
				n, "position:x", n.position.x + exit_offset, SLIDE_EXIT_TIME)
			# Slight shrink while leaving (Controls only — they have real
			# sizes to centre on; Node2D backgrounds just slide).
			if n is Control:
				tw_out.parallel().tween_property(
					n, "scale", Vector2(EXIT_SCALE, EXIT_SCALE), SLIDE_EXIT_TIME)
		await tw_out.finished

	# --- Phase 2: swap scenes while the old content is off-screen. ---
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		# Scene failed to load — slide the old screen back home and bail.
		push_error("slide_change_scene: can't load " + scene_path)
		var tw_back := create_tween()
		tw_back.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		for n in old_nodes:
			tw_back.parallel().tween_property(
				n, "position:x", n.position.x - exit_offset, SLIDE_ENTER_TIME)
			if n is Control:
				tw_back.parallel().tween_property(n, "scale", Vector2.ONE, SLIDE_ENTER_TIME)
		await tw_back.finished
		_slide_busy = false
		return

	# --- Phase 3: park the new content off-screen IMMEDIATELY. ---
	# No await before this! change_scene_to_file() returns in the same
	# frame, before rendering — so the incoming screen never gets a
	# chance to flash at its resting position. (This is what fixes the
	# "buttons visible for a millisecond" flicker, in both directions.)
	var new_nodes := _slidable_nodes(get_tree().current_scene)
	for n in new_nodes:
		# Push each node to the entering side (opposite of the exit).
		n.position.x -= exit_offset

	# Let the scene finish layout while it is safely invisible.
	await get_tree().process_frame
	await get_tree().process_frame

	# --- Phase 4: slide the new screen home. ---
	if new_nodes.size() > 0:
		var tw_in := create_tween()
		# Ease-out: arrive fast, settle gently.
		tw_in.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		for n in new_nodes:
			# Resting x is read AFTER layout (current x + the offset we
			# applied), so container/anchor settling can't desync it.
			tw_in.parallel().tween_property(
				n, "position:x", n.position.x + exit_offset, SLIDE_ENTER_TIME)
			# Sizes are valid now, so centre pivots are safe; arrive
			# slightly oversized and settle to the exact size.
			if n is Control:
				n.pivot_offset = n.size / 2.0
				n.scale = Vector2(ENTER_SCALE, ENTER_SCALE)
				tw_in.parallel().tween_property(
					n, "scale", Vector2.ONE, SLIDE_ENTER_TIME)
		await tw_in.finished

	# Transition fully done — accept new navigation taps.
	_slide_busy = false


## Returns every root child that should participate in the slide.
## NOTE: scene-local AnimatedBackground nodes DO slide now — the
## shared menu background lives in the MenuBackground autoload
## (a CanvasLayer, never a scene child), so any AnimatedBackground
## still inside a scene belongs to that scene and must travel with
## its content. This is what makes lesson -> section read as one
## continuous push instead of a background pop at the swap moment.
## CanvasLayers are skipped: they are independent overlays.
func _slidable_nodes(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	for child in root.get_children():
		# Overlays/HUDs on their own canvas stay put.
		if child is CanvasLayer:
			continue
		# Only nodes with a position property can be tweened this way.
		if child is Control or child is Node2D:
			out.append(child)
	return out
