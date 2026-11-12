extends Node

## Verification test for redesigned Daily Challenges & Mock services.

var _failures: int = 0

func _ready() -> void:
	print("[TestDailyChallenge] Running tests...")
	test_mock_calendar_generation()
	test_mock_summary_generation()
	test_mock_wordle_playthrough()
	test_mock_wordef_playthrough()
	test_mock_unscramble_playthrough()
	test_real_daily_wordef_setup()
	test_real_daily_unscramble_setup()
	await test_scene_instantiation()
	
	print("---")
	if _failures == 0:
		print("[TestDailyChallenge] ALL TESTS PASSED!")
	else:
		print("[TestDailyChallenge] %d TEST(S) FAILED!" % _failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)

func test_mock_calendar_generation() -> void:
	DailyChallengeMock.enable_mock()
	_assert(DailyChallengeMock.is_active(), "Mock should be active")
	
	var ctx: Dictionary = {"ok": false, "data": {}}
	DailyChallengeMock.handle_request("GET", "/challenge/calendar", {}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["data"] = data
	)
	
	_assert(bool(ctx["ok"]), "Calendar request should succeed")
	var days: Array = ctx["data"].get("days", [])
	_assert(days.size() == 30, "Calendar should contain 30 days")
	
	var found_today: bool = false
	for d: Variant in days:
		if d is Dictionary and bool(d.get("today", false)):
			found_today = true
			_assert(not bool(d.get("future", false)), "Today should not be future")
	_assert(found_today, "Calendar should mark today correctly")

func test_mock_summary_generation() -> void:
	var ctx: Dictionary = {"ok": false, "data": {}}
	DailyChallengeMock.handle_request("GET", "/challenge/summary?date=2026-11-12", {}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["data"] = data
	)
	
	_assert(bool(ctx["ok"]), "Summary request should succeed")
	var games: Dictionary = ctx["data"].get("games", {})
	_assert(games.has("wordle") and games.has("wordef") and games.has("unscramble"), "Summary should contain all 3 games")

func test_mock_wordle_playthrough() -> void:
	var ctx: Dictionary = {"ok": false, "attempt_id": "", "feedback": [], "solved": false}
	
	# 1. Start Wordle attempt
	DailyChallengeMock.handle_request("POST", "/challenge/attempts", {"gameType": "wordle", "date": "2026-11-12"}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["attempt_id"] = str(data.get("attempt", {}).get("id", ""))
	)
	_assert(bool(ctx["ok"]), "Start wordle attempt should succeed")
	_assert(str(ctx["attempt_id"]) != "", "Should receive valid attempt ID for Wordle")
	
	var att_id: String = str(ctx["attempt_id"])
	
	# 2. Submit wrong guess
	DailyChallengeMock.handle_request("POST", "/challenge/attempts/%s/wordle-guess" % att_id, {"guess": "PLANT"}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["solved"] = bool(data.get("solved", false))
		ctx["feedback"] = data.get("feedback", [])
	)
	_assert(bool(ctx["ok"]), "Submit guess should succeed")
	_assert(not bool(ctx["solved"]), "PLANT is not SMART, should not be solved")
	_assert(ctx["feedback"].size() == 5, "Feedback should have 5 items")
	
	# 3. Submit winning guess "SMART"
	DailyChallengeMock.handle_request("POST", "/challenge/attempts/%s/wordle-guess" % att_id, {"guess": "SMART"}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["solved"] = bool(data.get("solved", false))
	)
	_assert(bool(ctx["ok"]), "Winning guess should succeed")
	_assert(bool(ctx["solved"]), "SMART should be solved!")

func test_mock_wordef_playthrough() -> void:
	var ctx: Dictionary = {"ok": false, "attempt_id": "", "done": false, "correct": false}
	
	DailyChallengeMock.handle_request("POST", "/challenge/attempts", {"gameType": "wordef", "date": "2026-11-12"}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["attempt_id"] = str(data.get("attempt", {}).get("id", ""))
	)
	_assert(str(ctx["attempt_id"]) != "", "Valid Wordef attempt id")
	
	var att_id: String = str(ctx["attempt_id"])
	
	# Next question
	DailyChallengeMock.handle_request("POST", "/challenge/attempts/%s/wordef-next" % att_id, {}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["done"] = bool(data.get("done", false))
	)
	_assert(bool(ctx["ok"]), "Next question should succeed")
	_assert(not bool(ctx["done"]), "Should not be done on first question")
	
	# Answer question
	DailyChallengeMock.handle_request("POST", "/challenge/attempts/%s/wordef-answer" % att_id, {"index": 0, "option": "گسترش دادن"}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["correct"] = bool(data.get("correct", false))
	)
	_assert(bool(ctx["ok"]), "Answer question should succeed")
	_assert(bool(ctx["correct"]), "Option should be correct")

func test_mock_unscramble_playthrough() -> void:
	var ctx: Dictionary = {"ok": false, "attempt_id": "", "clue": "", "correct": false}
	
	DailyChallengeMock.handle_request("POST", "/challenge/attempts", {"gameType": "unscramble", "date": "2026-11-12"}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["attempt_id"] = str(data.get("attempt", {}).get("id", ""))
	)
	_assert(str(ctx["attempt_id"]) != "", "Valid Unscramble attempt id")
	
	var att_id: String = str(ctx["attempt_id"])
	
	# Reveal clue
	DailyChallengeMock.handle_request("POST", "/challenge/attempts/%s/clue" % att_id, {"index": 0}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["clue"] = str(data.get("clueFa", ""))
	)
	_assert(bool(ctx["ok"]), "Reveal clue should succeed")
	_assert(str(ctx["clue"]) != "", "Clue should not be empty")
	
	# Solve word
	DailyChallengeMock.handle_request("POST", "/challenge/attempts/%s/unscramble-solve" % att_id, {"index": 0, "word": "APPLE"}, func(ok: bool, data: Dictionary) -> void:
		ctx["ok"] = ok
		ctx["correct"] = bool(data.get("correct", false))
	)
	_assert(bool(ctx["ok"]), "Solve word should succeed")
	_assert(bool(ctx["correct"]), "Word 'APPLE' should be correct")

func test_real_daily_wordef_setup() -> void:
	DailyChallengeState.selected_game = "wordef"
	DailyChallengeState.selected_date = "2026-11-12"
	var meaning_scene: PackedScene = load("res://scenes/word_game/MeaningGame.tscn")
	_assert(meaning_scene != null, "MeaningGame.tscn should load")
	var inst: Node = meaning_scene.instantiate()
	add_child(inst)
	var quiz: Node = inst.get_node_or_null("Game")
	_assert(quiz != null, "MeaningGame should have Game child")
	_assert(quiz.get("_is_daily_challenge") == true, "MeaningQuiz should enter daily challenge mode")
	_assert(quiz.get("_mode") == "quiz", "MeaningQuiz should bypass book select and enter quiz mode immediately")
	var questions: Array = quiz.get("_questions")
	_assert(questions.size() == 5, "Daily Wordef should have exactly 5 questions (got %d)" % questions.size())
	inst.queue_free()
	DailyChallengeState.selected_game = ""


func test_real_daily_unscramble_setup() -> void:
	DailyChallengeState.selected_game = "unscramble"
	DailyChallengeState.selected_date = "2026-11-12"
	var spelling_scene: PackedScene = load("res://scenes/word_game/SpellingGame.tscn")
	_assert(spelling_scene != null, "SpellingGame.tscn should load")
	var inst: Node = spelling_scene.instantiate()
	add_child(inst)
	_assert(ScrambledGameManager.is_competition(), "ScrambledGameManager should be in COMPETITION mode")
	_assert(ScrambledGameManager.word_count() == 5, "Daily Unscramble should have 5 words (got %d)" % ScrambledGameManager.word_count())
	inst.queue_free()
	DailyChallengeState.selected_game = ""


func test_scene_instantiation() -> void:
	var daily_packed: PackedScene = load("res://scenes/word_game/DailyWordGame.tscn")
	_assert(daily_packed != null, "DailyWordGame.tscn should load")
	var daily_inst: Node = daily_packed.instantiate()
	_assert(daily_inst != null, "DailyWordGame should instantiate")
	daily_inst.queue_free()

	var demo_packed: PackedScene = load("res://scenes/word_game/DailyChallengeDemo.tscn")
	_assert(demo_packed != null, "DailyChallengeDemo.tscn should load")
	var demo_inst: Node = demo_packed.instantiate()
	_assert(demo_inst != null, "DailyChallengeDemo should instantiate")
	add_child(demo_inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var view: Node = demo_inst.get("_active_daily_view")
	_assert(view != null, "DailyChallengeDemo should mount DailyWordGame")
	if view != null:
		var badge: Label = view.get("_user_badge_label")
		_assert(badge != null, "User badge label should exist")
		_assert(not badge.is_layout_rtl(), "User badge label layout_direction must be LTR so HORIZONTAL_ALIGNMENT_RIGHT aligns right")
		_assert(badge.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "User badge label should be right aligned")
		_assert(badge.text_direction == Control.TEXT_DIRECTION_RTL, "User badge label text direction should be RTL")
		_assert(badge.position.x > 0.0, "User badge label should be positioned on the right side of the banner")
	demo_inst.queue_free()
