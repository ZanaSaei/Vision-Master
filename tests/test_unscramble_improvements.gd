extends Node

# ============================================================
#  Verification Tests for Unscramble Game Improvements:
#   1. Tap-to-Swap mechanics
#   2. Corrected reveal_letter_at behavior
#   3. Hint card display on hint request
#   4. Pronunciation on solved word and hint card audio button
#   5. Results 3-star rating and next lesson button
# ============================================================

func _ready() -> void:
	print("--- Starting Unscramble Improvement Tests ---")

	# 1. Test Tap-to-Swap on ScrambledTileBoard
	var board := ScrambledTileBoard.new()
	add_child(board)
	board.size = Vector2(1080, 400)

	var ctrl := ScrambledWordController.new()
	ctrl.setup({"word": "CAT", "meaning": "A small domesticated feline", "meaning_fa": "گربه"}, 12345)
	# Force specific order: T, C, A
	ctrl.letters = ["T", "C", "A"]

	board.build(ctrl, false)
	assert(board.tile_count() == 3, "Board should have 3 tiles")
	var initial_text := board.current_text()
	print("Initial board text: %s" % initial_text)

	# Simulate tapping tile 0
	var tile0: ScrambledTile = board._tiles[board._order[0]] as ScrambledTile
	var tile1: ScrambledTile = board._tiles[board._order[1]] as ScrambledTile
	assert(tile0 != null and tile1 != null)

	board._on_tile_tapped(tile0)
	assert(tile0.is_selected(), "Tile 0 should now be selected")
	assert(board._selected_tile == tile0, "_selected_tile should be tile 0")
	print("PASS  Tap-to-Swap: Tile 0 selected successfully")

	# Tap tile 0 again to verify deselection
	board._on_tile_tapped(tile0)
	assert(not tile0.is_selected(), "Tile 0 should now be deselected")
	assert(board._selected_tile == null, "_selected_tile should be null")
	print("PASS  Tap-to-Swap: Tile 0 deselected on second tap")

	# Now select tile 0 and tap tile 1 to SWAP them
	board._on_tile_tapped(tile0)
	var letter0_before: String = tile0.letter
	var letter1_before: String = tile1.letter
	board._on_tile_tapped(tile1)

	assert(not tile0.is_selected(), "Tile 0 should not be selected after swap")
	assert(board._selected_tile == null, "_selected_tile should be null after swap")
	var new_tile0: ScrambledTile = board._tiles[board._order[0]] as ScrambledTile
	var new_tile1: ScrambledTile = board._tiles[board._order[1]] as ScrambledTile
	assert(new_tile0.letter == letter1_before, "Tile 0 should now hold letter %s" % letter1_before)
	assert(new_tile1.letter == letter0_before, "Tile 1 should now hold letter %s" % letter0_before)
	print("PASS  Tap-to-Swap: Tiles swapped positions smoothly (New order: %s)" % board.current_text())

	# 2. Test vibrate_hint_pair (letters do NOT move)
	var text_before_vibrate := board.current_text()
	var vibrated := board.vibrate_hint_pair()
	assert(vibrated, "vibrate_hint_pair should return true on unsolved board")
	assert(board.current_text() == text_before_vibrate, "vibrate_hint_pair must NOT move the letters (stays %s)" % text_before_vibrate)
	print("PASS  Blue Hint: Two letters vibrated without moving any tiles")

	# Test reveal_letter_at logic
	# Currently board has CTA. Target is CAT.
	# Position 1 currently has 'T', but needs 'A'!
	board.reveal_letter_at(1)
	var tile_at_1: ScrambledTile = board._tiles[board._order[1]] as ScrambledTile
	assert(tile_at_1.letter == "A", "reveal_letter_at(1) must move letter 'A' into position 1, found '%s'" % tile_at_1.letter)
	assert(tile_at_1.is_locked(), "Revealed tile should be locked")
	print("PASS  Reveal letter fix: Position 1 correctly received target letter 'A'")

	# Check position 2 now has 'T', which completes "CAT"
	assert(board.current_text() == "CAT", "Board should now spell 'CAT', spells '%s'" % board.current_text())
	print("PASS  Board now correctly spells CAT")

	board.queue_free()

	# 3. Test GameplayActions mode switching & blue/yellow button behavior
	var actions := load("res://scenes/word_game/scrambled/ui/GameplayActions.tscn").instantiate() as ScrambledGameplayActions
	add_child(actions)
	actions._ready()

	# In learning mode: blue button shown initially, yellow button hidden
	actions.setup_mode(false)
	assert(actions._reveal.visible == true, "Blue button must be visible initially in learning mode")
	assert(actions._hint.visible == false, "Yellow button must be hidden initially in learning mode")
	print("PASS  Learning Mode: Blue button visible, yellow button hidden initially")

	# When timer finishes: reveal_hint() is called, blue button removed, yellow button shown
	actions.reveal_hint()
	assert(actions._reveal.visible == false, "Blue button must be removed when yellow button reveals")
	assert(actions._hint.visible == true, "Yellow button must be visible after reveal_hint")
	print("PASS  Learning Mode: Blue button removed and replaced by yellow button after timer")

	# In competition / daily challenge mode: blue button removed entirely, only yellow button shown
	actions.setup_mode(true)
	assert(actions._reveal.visible == false, "Blue button must be removed entirely in daily challenge")
	assert(actions._hint.visible == true, "Yellow button must be shown immediately in daily challenge")
	print("PASS  Daily Challenge: Blue button removed entirely, only yellow button shown")
	actions.queue_free()

	# 4. Test pressing yellow button makes score half in daily challenge
	var points_unhinted := ScrambledScoreManager.points_for(5.0, false)
	var points_hinted := ScrambledScoreManager.points_for(5.0, true)
	assert(points_unhinted == 100, "Unhinted points at 5s should be 100")
	assert(points_hinted == 50, "Hinted points should be half (50)")
	print("PASS  Daily Challenge: Pressing yellow button made score half (%d -> %d)" % [points_unhinted, points_hinted])

	# 5. Test HintCard audio button & Gameplay hint request
	var hint_card := load("res://scenes/word_game/scrambled/ui/HintCard.tscn").instantiate() as ScrambledHintCard
	add_child(hint_card)
	hint_card.show_hint("A feline pet", "گربه", "", "cat")
	assert(hint_card.is_shown(), "HintCard should be shown")
	assert(hint_card._audio_btn != null, "HintCard should have audio button")
	assert(hint_card._audio_btn.visible, "Audio button should be visible when word provided")
	print("PASS  HintCard: Audio pronunciation button is wired and visible")
	hint_card.queue_free()

	# 4. Test Results Screen learning mode enhancements
	ScrambledGameManager.start_learning(1, 1)
	var results := load("res://scenes/word_game/scrambled/Results.tscn").instantiate() as Control
	add_child(results)
	results._ready()

	# Check StarsRow exists in content
	var stars_row: Node = null
	for child in results._content.get_children():
		if child.name == "StarsRow":
			stars_row = child
			break
	assert(stars_row != null, "Results screen must contain StarsRow in learning mode")
	print("PASS  Results Screen: 3-Star Rating row successfully generated")

	# Check Next Lesson button exists
	var next_btn: Node = null
	for child in results._content.get_children():
		var btn: Node = child.get_node_or_null("NextLessonButton")
		if btn != null:
			next_btn = btn
			break
	assert(next_btn != null, "NextLessonButton must be present when next lesson exists")
	print("PASS  Results Screen: NextLessonButton ('درس بعدی ❯') present and wired")

	results.queue_free()
	print("--- All Unscramble Improvement Tests Passed Successfully! ---")
