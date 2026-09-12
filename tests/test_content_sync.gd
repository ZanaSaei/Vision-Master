extends Node

# Headless tests for the server-sync + remote-content layer.
#   - SyncManager.merge: per-key max, set union, word-list union, and
#     "keep the further-along SRS entry" for review words.
#   - ContentManager.resolve: bundled assets resolve to res://, missing ones
#     to "" (so callers degrade gracefully / fall back to TTS).
#
# The two autoload scripts are instantiated directly (not via their singleton
# names) so the tests don't depend on autoload registration.

const SyncScript := preload("res://autoload/SyncManager.gd")
const ContentScript := preload("res://autoload/ContentManager.gd")


func test_sync_merge() -> void:
	var sync = SyncScript.new()

	# Empty sides are identity.
	assert(sync.merge({}, {}) == {})
	assert(sync.merge({"a": 1}, {}) == {"a": 1})

	var local := {
		"last_scene": "",
		"grammar_xp": {"1_1": 10},
		"grammar_unlocked_units": {"1_1": 2},
		"grammar_completed_units": {"1_1": ["u1"]},
		"saved_words": [{"word": "a", "book": 1, "lesson": 1}],
		"review_words": [{"word": "a", "book": 1, "lesson": 1, "srs_reps": 1}],
	}
	var server := {
		"last_scene": "res://scenes/reading/Reading.tscn",
		"grammar_xp": {"1_1": 5, "1_2": 3},
		"grammar_unlocked_units": {"1_1": 1},
		"grammar_completed_units": {"1_1": ["u2"]},
		"saved_words": [
			{"word": "a", "book": 1, "lesson": 1},
			{"word": "b", "book": 1, "lesson": 1},
		],
		"review_words": [{"word": "a", "book": 1, "lesson": 1, "srs_reps": 4}],
	}

	var merged: Dictionary = sync.merge(local, server)

	# grammar_xp / unlocked: per-key max (never regress).
	assert(int(merged["grammar_xp"]["1_1"]) == 10, "xp max keeps the larger value")
	assert(int(merged["grammar_xp"]["1_2"]) == 3, "server-only xp key is kept")
	assert(int(merged["grammar_unlocked_units"]["1_1"]) == 2, "unlocked units take the max")

	# completed units: set union.
	var units: Array = merged["grammar_completed_units"]["1_1"]
	assert("u1" in units and "u2" in units, "completed unit sets are unioned")

	# saved words: union by (word, book, lesson), no duplicates.
	assert(merged["saved_words"].size() == 2, "saved words union without duplicates")

	# review words: keep the further-along SRS entry.
	var reps := 0
	for entry in merged["review_words"]:
		if entry.get("word") == "a":
			reps = int(entry.get("srs_reps", 0))
	assert(reps == 4, "review keeps the higher srs_reps")

	# last_scene: filled from the server only when local is empty.
	assert(str(merged["last_scene"]) == "res://scenes/reading/Reading.tscn", "empty last_scene comes from the server")

	sync.free()
	print("test_sync_merge PASSED")


func test_content_resolve() -> void:
	var content = ContentScript.new()

	# A bundled asset resolves to its res:// path.
	var bundle := "res://assets/fonts/Vazirmatn-Regular.ttf"
	assert(content.resolve(bundle) == bundle, "bundled asset resolves to res://")

	# A not-yet-downloaded asset resolves to "" (callers then degrade / TTS).
	assert(content.resolve("res://assets/audio/Vocabularies/__missing__.mp3") == "", "missing asset resolves to empty")

	# has_asset mirrors resolve.
	assert(content.has_asset(bundle), "has_asset true for bundled")
	assert(not content.has_asset("res://assets/audio/Vocabularies/__missing__.mp3"), "has_asset false for missing")

	# load_image of a missing asset returns null rather than erroring.
	assert(content.load_image("res://assets/images/__missing__.png") == null, "missing image loads null")

	content.free()
	print("test_content_resolve PASSED")
