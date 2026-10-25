extends CanvasLayer
############################################################
# TRANSITION MANAGER
#   change_scene()       -> fade transition for existing callers.
#   slide_change_scene() -> longer push for hierarchical drill-down/back.
#   tab_change_scene()   -> quick horizontal push between peer tab scenes.
#                          Tab changes do not fade or scale the screens.
# The persistent solid fill is a separate low canvas layer and never slides.
############################################################

# Direction of a slide transition.
# FORWARD = going deeper (main -> book -> lesson -> section)
# BACK    = going up one level
enum Slide { FORWARD, BACK }

signal tab_transition_started
signal tab_transition_finished(success: bool)

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
const TAB_SLIDE_TIME   := 0.18    # brief, direct movement for peer tabs

var _tab_change_busy: bool = false

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
	# Fade overlay sits above the persistent bottom navigation bar (layer 1)
	# so a full-screen fade still covers the bar.
	layer = 100

	# Build the transition overlay in code so no scene editing is required.
	color_rect = ColorRect.new()
	color_rect.color = transition_color
	color_rect.visible = false
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	color_rect.anchor_left = 0.0
	color_rect.anchor_top = 0.0
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(color_rect)

	# Lock taps across the scene swap without retaining scene-local references.
	tab_transition_started.connect(_lock_navigation_bars)
	tab_transition_finished.connect(_unlock_navigation_bars)


func _unlock_navigation_bars(_success: bool) -> void:
	_set_navigation_bars_busy(false)


func _lock_navigation_bars() -> void:
	_set_navigation_bars_busy(true)


func _set_navigation_bars_busy(busy: bool) -> void:
	var scene_tree: SceneTree = get_tree()
	var navigation_bars: Array[Node] = scene_tree.get_nodes_in_group("bottom_navigation")
	for navigation_node: Node in navigation_bars:
		if navigation_node is VisionNavigationBar:
			var navigation_bar: VisionNavigationBar = navigation_node as VisionNavigationBar
			navigation_bar.set_navigation_busy(busy)


func _find_navigation_bar(root: Node) -> VisionNavigationBar:
	if root == null:
		return null
	if root is VisionNavigationBar:
		return root as VisionNavigationBar
	for child: Node in root.get_children():
		var navigation_bar: VisionNavigationBar = _find_navigation_bar(child)
		if navigation_bar != null:
			return navigation_bar
	return null


############################################################
# THREADED SCENE PRELOADING
#   change_scene_to_file() loads AND instantiates the whole scene on the
#   main thread — on mobile this is a visible frame hitch on navigation.
#   Instead the destination PackedScene is requested on a worker thread
#   while the exit animation is still covering the screen, and the swap
#   is then a cheap change_scene_to_packed(). Falls back to the
#   synchronous path if threading is unavailable or the load fails.
############################################################

## Kick off a background load of `scene_path`. No-op when cached or empty.
func _begin_preload(scene_path: String) -> void:
	if scene_path == "" or ResourceLoader.has_cached(scene_path):
		return
	ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)


## Await the threaded load started by _begin_preload (or fall back to a
## synchronous load). Returns null when the scene can't be loaded.
func _threaded_get(scene_path: String) -> PackedScene:
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return null
	if ResourceLoader.has_cached(scene_path):
		return load(scene_path) as PackedScene
	var state := ResourceLoader.load_threaded_get_status(scene_path)
	while state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		state = ResourceLoader.load_threaded_get_status(scene_path)
	if state == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(scene_path) as PackedScene
	return null


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
		# Load the destination on a worker thread while the fade-out
		# animation covers it, so the swap below never stalls a frame.
		_begin_preload(target)
		await _fade_out(black)
		# 2. Swap the scene while nothing is visible.
		var packed: PackedScene = await _threaded_get(target)
		if packed != null:
			get_tree().change_scene_to_packed(packed)
		else:
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
# TAB PUSH — quick horizontal transition between bottom tabs.
# FORWARD moves the old screen LEFT; BACK moves it RIGHT.
# Unlike the hierarchical slide, this is a direct push with no scaling.
############################################################
func tab_change_scene(scene_path: String, direction: Slide) -> void:
	if scene_path.is_empty() or _tab_change_busy or _fade_busy or _slide_busy:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("tab_change_scene: can't load '%s'." % scene_path)
		return
	_tab_change_busy = true
	tab_transition_started.emit()
	_lock_navigation_bars()
	# Kick the destination load off on a worker thread immediately, so the
	# outgoing slide animation runs during the load instead of the tap
	# frame stalling on a synchronous load.
	_begin_preload(scene_path)
	var scene_tree: SceneTree = get_tree()
	var travel: float = maxf(get_viewport().get_visible_rect().size.x, 1.0)
	var exit_offset: float = -travel if direction == Slide.FORWARD else travel
	var old_scene: Node = scene_tree.current_scene
	var old_nodes: Array = _slidable_nodes(old_scene)

	# Only scene content participates; the shared background and the persistent
	# bottom navigation (its own canvas layer) remain perfectly stationary.
	if not old_nodes.is_empty():
		var outgoing_tween: Tween = _create_tab_slide_tween(
			old_nodes, exit_offset, false
		)
		await outgoing_tween.finished

	# The worker-thread load started above has had the whole exit animation
	# to finish; pick it up (or fall back to the synchronous path).
	var packed: PackedScene = await _threaded_get(scene_path)
	var error_code: int = OK
	if packed != null:
		error_code = scene_tree.change_scene_to_packed(packed)
	else:
		error_code = scene_tree.change_scene_to_file(scene_path)
	if error_code != OK:
		push_error(
			"tab_change_scene: can't load '%s' (%s)."
			% [scene_path, error_string(error_code)]
		)
		if not old_nodes.is_empty():
			var restore_tween: Tween = _create_tab_slide_tween(
				old_nodes, -exit_offset, true
			)
			await restore_tween.finished
		_finish_tab_transition(false)
		return

	# Change scenes through a deferred call. Once the native swap emits
	# scene_changed, park the incoming content before the next rendered frame.
	await scene_tree.scene_changed
	var incoming_scene: Node = scene_tree.current_scene
	if incoming_scene == null:
		push_error("tab_change_scene: the new current scene is unavailable.")
		_finish_tab_transition(false)
		return

	var incoming_nodes: Array = _slidable_nodes(incoming_scene)
	for incoming_node: Node in incoming_nodes:
		_shift_tab_node_x(incoming_node, -exit_offset)

	if not incoming_nodes.is_empty():
		var incoming_tween: Tween = _create_tab_slide_tween(
			incoming_nodes, exit_offset, true
		)
		await incoming_tween.finished

	_finish_tab_transition(true)


func _create_tab_slide_tween(
	nodes: Array,
	horizontal_offset: float,
	entering: bool
) -> Tween:
	var movement_tween: Tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_CUBIC)
	movement_tween.set_ease(Tween.EASE_OUT if entering else Tween.EASE_IN)
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		if node is Control:
			var control_node: Control = node as Control
			var target_left: float = control_node.offset_left + horizontal_offset
			var target_right: float = control_node.offset_right + horizontal_offset
			movement_tween.parallel().tween_property(
				control_node, "offset_left", target_left, TAB_SLIDE_TIME
			)
			movement_tween.parallel().tween_property(
				control_node, "offset_right", target_right, TAB_SLIDE_TIME
			)
		elif node is Node2D:
			var node_2d: Node2D = node as Node2D
			movement_tween.parallel().tween_property(
				node_2d, "position:x", node_2d.position.x + horizontal_offset, TAB_SLIDE_TIME
			)
	return movement_tween


func _shift_tab_node_x(node: Node, offset_x: float) -> void:
	if node is Control:
		var control_node: Control = node as Control
		control_node.offset_left += offset_x
		control_node.offset_right += offset_x
	elif node is Node2D:
		var node_2d: Node2D = node as Node2D
		node_2d.position.x += offset_x


func _finish_tab_transition(success: bool) -> void:
	_tab_change_busy = false
	if color_rect != null:
		color_rect.visible = false
	# Unlocks the persistent bottom navigation (see _unlock_navigation_bars).
	tab_transition_finished.emit(success)


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
############################################################
# INSTANT — threaded but transition-free scene swap.
# Legacy call sites used change_scene_to_file() directly, which loads AND
# instantiates the scene synchronously on the tap frame (a visible hitch).
# change_scene_now() starts the load on a worker thread immediately and
# swaps as soon as the packed scene is ready, with no visual transition —
# identical behaviour minus the stall. Returns false only when the scene
# could not be loaded at all.
############################################################
func change_scene_now(scene_path: String) -> bool:
	if not ResourceLoader.exists(scene_path):
		push_error("change_scene_now: scene not found — " + scene_path)
		return false
	_begin_preload(scene_path)
	var packed: PackedScene = await _threaded_get(scene_path)
	if packed != null:
		get_tree().change_scene_to_packed(packed)
		return true
	# Worker path failed (rare): fall back to the direct call so the tap
	# still goes somewhere instead of dead-ending the user.
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("change_scene_now: couldn't open '%s' (%s)."
			% [scene_path, error_string(err)])
		return false
	return true


func slide_change_scene(scene_path: String, direction: Slide) -> void:
	# Ignore any tap that arrives while a slide is already running.
	if _slide_busy:
		return
	_slide_busy = true
	# Start loading the destination on a worker thread right away: the whole
	# Phase-1 exit animation then runs concurrently with the load instead of
	# the load stalling the Phase-2 swap.
	_begin_preload(scene_path)

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
	var packed: PackedScene = await _threaded_get(scene_path)
	var err := OK
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		err = get_tree().change_scene_to_file(scene_path)
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
## Root-level scene content slides as a unit. Persistent overlays and the
## solid app background live on separate canvas layers and remain stationary.
## CanvasLayers are skipped: they are independent overlays.
## The bottom navigation bar is persistent chrome: it must stay
## perfectly still while the scene content pushes past it, so it is
## skipped too (its selection is carried across the swap explicitly).
func _slidable_nodes(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	for child in root.get_children():
		# Overlays/HUDs on their own canvas stay put.
		if child is CanvasLayer:
			continue
		# The bottom navigation bar never moves during a transition.
		if child is VisionNavigationBar:
			continue
		# Only nodes with a position property can be tweened this way.
		if child is Control or child is Node2D:
			out.append(child)
	return out
