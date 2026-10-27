extends Node
## ============================================================
##  BACKGROUND BRIDGE — regression test for the scene-swap flash.
##
##  change_scene_to_packed()/change_scene_to_file() free the running scene and
##  only build the incoming one afterwards, so at least one frame renders with
##  current_scene == null. Nothing but the flat theme fill is behind the
##  persistent bars in that frame, which read on screen as a beige "splash"
##  between two full-screen artworks.
##
##  TransitionManager keeps the outgoing artwork on its own low canvas layer
##  (BG_BRIDGE_LAYER) across exactly that window. These tests pin down the
##  three properties that make it work, and the selection rule that decides
##  which artwork gets held.
##
##  Run with run_tests on this file.
## ============================================================

const Transitions := preload("res://autoload/TransitionManager.gd")

const BLURRED_COVER := "res://assets/images/ui/book_scene/Vision1_blur.png"
const CLEAR_COVER := "res://assets/images/ui/book_scene/Vision1.png"


func test_hold_paints_the_outgoing_still_beneath_every_scene() -> void:
	var manager: Node = _manager()
	var still: Texture2D = load(BLURRED_COVER)
	manager.hold_background(still)

	var bridge: TextureRect = manager._bg_bridge
	_check(bridge != null, "the bridge exists")
	# Synchronous on purpose: the still has to be on screen before the swap is
	# requested, or the swap frame is already lost.
	_check(bridge.visible, "holding puts the still on screen without waiting a frame")
	_check(bridge.texture == still, "the held still is the outgoing artwork")
	_check(is_equal_approx(bridge.modulate.a, 1.0), "the held still is fully opaque")

	var layer := bridge.get_parent() as CanvasLayer
	_check(
		layer != null and layer.layer == Transitions.BG_BRIDGE_LAYER,
		"the still sits on its own canvas layer"
	)
	_check(
		Transitions.BG_BRIDGE_LAYER < -1 and Transitions.BG_BRIDGE_LAYER > -100,
		"that layer is above the solid theme fill and below scene artwork"
	)

	# Anchors are resolved on the next layout pass; then it must cover it all.
	await get_tree().process_frame
	_check(
		bridge.size.is_equal_approx(get_viewport().get_visible_rect().size),
		"the still covers the whole viewport"
	)
	await manager.release_background()


func test_release_drops_the_still_after_the_swap_is_deferred() -> void:
	var manager: Node = _manager()
	manager.hold_background(load(BLURRED_COVER))
	var bridge: TextureRect = manager._bg_bridge
	_check(bridge.visible, "the still is up before the swap")

	# release_background() waits two frames because the swap itself is
	# deferred: dropping the still in the same frame would expose the very
	# empty frame it exists to cover.
	manager.release_background()
	_check(bridge.visible, "the still is still up in the frame the swap happens")

	for _i: int in range(3):
		await get_tree().process_frame
	_check(not bridge.visible, "the still is dropped once the new scene is up")


func test_scene_background_finds_only_the_full_screen_still() -> void:
	var manager: Node = _manager()
	var still: Texture2D = load(BLURRED_COVER)
	var cover: Texture2D = load(CLEAR_COVER)
	var screen: Vector2 = get_viewport().get_visible_rect().size

	var fake := Control.new()
	fake.name = "FakeScreen"
	fake.size = screen
	add_child(fake)

	var backdrop := TextureRect.new()
	backdrop.name = "BackgroundA"
	backdrop.texture = still
	backdrop.size = screen
	fake.add_child(backdrop)

	# Card artwork: right name convention, wrong size.
	var card_art := TextureRect.new()
	card_art.name = "CardArt"
	card_art.texture = cover
	card_art.size = Vector2(200.0, 300.0)
	fake.add_child(card_art)

	# Full-screen, but not a background (a veil over the artwork).
	var veil := TextureRect.new()
	veil.name = "Shade"
	veil.texture = cover
	veil.size = screen
	fake.add_child(veil)

	_check(manager._scene_background(fake) == still, "the full-screen backdrop is found")

	backdrop.visible = false
	_check(manager._scene_background(fake) == null, "a hidden backdrop is ignored")
	backdrop.visible = true

	backdrop.modulate.a = 0.0
	_check(manager._scene_background(fake) == null, "a transparent backdrop is ignored")
	backdrop.modulate.a = 1.0

	_check(manager._scene_background(null) == null, "a missing scene is handled")

	fake.queue_free()
	await get_tree().process_frame


func test_handover_covers_every_frame_of_a_real_swap() -> void:
	var manager: Node = _manager()
	var still: Texture2D = load(BLURRED_COVER)
	var bridge: TextureRect = manager._bg_bridge
	var tree := get_tree()

	manager.handover_scene(_make_backdrop_scene(still), still)
	_check(
		bridge.visible and bridge.texture == still,
		"the still is already on screen when the swap is requested"
	)

	# Walk the swap frame by frame and look for any frame the user would be
	# left staring at the flat fill.
	var empty_frames := 0
	var uncovered_frames := 0
	for _i: int in range(30):
		if tree.current_scene == null:
			empty_frames += 1
			if not (bridge.visible and bridge.texture == still):
				uncovered_frames += 1
		elif String(tree.current_scene.name) == "BridgeFixture":
			break
		await tree.process_frame

	_check(
		empty_frames >= 1,
		"the swap does leave frames with no current scene (%d)" % empty_frames
	)
	_check(uncovered_frames == 0, "every one of those frames shows the still")
	_check(
		tree.current_scene != null and String(tree.current_scene.name) == "BridgeFixture",
		"the incoming scene is in the tree"
	)

	for _i: int in range(3):
		await tree.process_frame
	_check(not bridge.visible, "the still is released after the incoming scene drew")


## A stand-in for the incoming screen: a full-screen backdrop still, i.e. the
## same shape every real screen uses.
func _make_backdrop_scene(still: Texture2D) -> PackedScene:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var fixture := Control.new()
	fixture.name = "BridgeFixture"
	fixture.size = screen

	var backdrop := TextureRect.new()
	backdrop.name = "BackgroundA"
	backdrop.texture = still
	# Anchored full-rect so the packed scene fills the window on its own; a
	# direct `size =` write is refused once anchors own the rect.
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fixture.add_child(backdrop)

	var packed := PackedScene.new()
	var error_code: int = packed.pack(fixture)
	fixture.free()
	assert(error_code == OK, "the fixture scene packs")
	return packed


func _manager() -> Node:
	var manager: Node = get_tree().root.get_node_or_null("TransitionManager")
	assert(manager != null, "TransitionManager autoload is available")
	return manager


func _check(condition: bool, label: String) -> void:
	assert(condition, label)
	print("PASS  " + label)
