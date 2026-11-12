class_name DailyChallengeMock
extends RefCounted

## Mock server & state provider for Daily Challenges in Vision Master.
## Simulates an active online backend with an authenticated user ("علی رضایی"),
## full 30-day Jalali calendar, live game attempt state, and scoring logic
## for Wordle, Wordef, and Unscramble.

static var _is_active: bool = false
static var _user_name: String = "علی رضایی"
static var _today_iso: String = "2026-11-12"
static var _today_jalali: Dictionary = {"year": 1405, "month": 8, "day": 22}

# In-memory challenge state for the session
static var _calendar_cache: Dictionary = {}
static var _summaries: Dictionary = {}
static var _attempts: Dictionary = {}
static var _lifetime_score: int = 1450
static var _streak_days: int = 5

const WORDEF_QUESTIONS: Array[Dictionary] = [
	{
		"prompt": "کدام گزینه به معنی «توسعه دادن یا گسترش یافتن» است؟",
		"word": "EXPAND",
		"kind": "meaning",
		"options": ["گسترش دادن", "کوچک کردن", "متوقف ساختن", "فراموش کردن"],
		"answer": "گسترش دادن"
	},
	{
		"prompt": "مترادف واژهٔ زیر کدام است؟",
		"word": "RAPID",
		"kind": "synonym",
		"options": ["سریع و چابک", "آهسته و کند", "تاریک", "سنگین"],
		"answer": "سریع و چابک"
	},
	{
		"prompt": "متضاد واژهٔ زیر کدام است؟",
		"word": "ANCIENT",
		"kind": "antonym",
		"options": ["مدرن و امروزی", "کهن و باستانی", "عجیب", "ارزشمند"],
		"answer": "مدرن و امروزی"
	},
	{
		"prompt": "کدام گزینه نزدیک‌ترین معنی برای واژهٔ زیر است؟",
		"word": "BRILLIANT",
		"kind": "meaning",
		"options": ["درخشان و هوشمند", "تیره و مبهم", "سخت‌گیر", "عادی"],
		"answer": "درخشان و هوشمند"
	},
	{
		"prompt": "مترادف واژهٔ زیر کدام است؟",
		"word": "COURAGE",
		"kind": "synonym",
		"options": ["شجاعت و دلیری", "ترس و واهمه", "ناامیدی", "ضعف"],
		"answer": "شجاعت و دلیری"
	}
]

const UNSCRAMBLE_WORDS: Array[Dictionary] = [
	{
		"scrambledWord": "PPALE",
		"solution": "APPLE",
		"clueFa": "یک میوهٔ خوشمزه و قرمز یا سبز"
	},
	{
		"scrambledWord": "NRLEA",
		"solution": "LEARN",
		"clueFa": "یاد گرفتن و فراگیری دانش"
	},
	{
		"scrambledWord": "DLOCU",
		"solution": "CLOUD",
		"clueFa": "توده سفید یا خاکستری در آسمان"
	},
	{
		"scrambledWord": "TAWRE",
		"solution": "WATER",
		"clueFa": "مایهٔ حیات که می‌نوشیم"
	},
	{
		"scrambledWord": "SMRAH",
		"solution": "MARSH",
		"clueFa": "زمین باتلاقی و مرطوب"
	}
]

const WORDLE_TARGET: String = "SMART"

static func is_active() -> bool:
	return _is_active

static func get_demo_username() -> String:
	return _user_name

static func enable_mock() -> void:
	_is_active = true
	_ensure_init_data()
	var api_node: Node = Engine.get_main_loop().root.get_node_or_null("API")
	if api_node != null and api_node.has_method("set_challenge_mock_handler"):
		api_node.call("set_challenge_mock_handler", Callable(DailyChallengeMock, "handle_request"))

static func disable_mock() -> void:
	_is_active = false
	var api_node: Node = Engine.get_main_loop().root.get_node_or_null("API")
	if api_node != null and api_node.has_method("clear_challenge_mock_handler"):
		api_node.call("clear_challenge_mock_handler")

static func reset_today() -> void:
	_ensure_init_data(true)

static func complete_game(date_key: String, game_type: String, score_gain: int = 100) -> void:
	_ensure_init_data()
	var target_date: String = date_key if date_key != "" else _today_iso
	_record_game_finished(target_date, game_type, score_gain)

static func _respond(callback: Callable, ok: bool, data: Dictionary) -> void:
	if callback.is_valid():
		callback.call(ok, data)

static func _ensure_init_data(force_reset: bool = false) -> void:
	if not _calendar_cache.is_empty() and not force_reset:
		return
	
	_lifetime_score = 1450
	_streak_days = 5
	_attempts.clear()
	_summaries.clear()
	
	var days: Array = []
	# Generate 30 days: 20 days in the past, today (day 22), 9 days in the future
	var today_day: int = int(_today_jalali.get("day", 22))
	var today_month: int = int(_today_jalali.get("month", 8))
	var today_year: int = int(_today_jalali.get("year", 1405))
	
	for offset: int in range(-20, 10):
		var target_day: int = today_day + offset
		var target_month: int = today_month
		var target_year: int = today_year
		if target_day <= 0:
			target_month -= 1
			target_day += 30
		elif target_day > 30:
			target_month += 1
			target_day -= 30
		
		var date_key: String = JalaliCalendar.iso_key(target_year, target_month, target_day)
		var is_today: bool = (offset == 0)
		var is_future: bool = (offset > 0)
		
		var completed: int = 0
		var score: int = 0
		
		if not is_future and not is_today:
			if abs(offset) % 3 == 0:
				completed = 3
				score = 300
			elif abs(offset) % 2 == 0:
				completed = 2
				score = 190
			else:
				completed = 1
				score = 95
		elif is_today:
			completed = 0
			score = 0
		
		var day_info: Dictionary = {
			"date": date_key,
			"jalali": {"year": target_year, "month": target_month, "day": target_day},
			"today": is_today,
			"future": is_future,
			"completedGames": completed,
			"totalScore": score
		}
		days.append(day_info)
		
		# Create summary for day
		_summaries[date_key] = {
			"date": date_key,
			"dayTotal": score,
			"lifetimeTotal": _lifetime_score,
			"streak": _streak_days,
			"games": {
				"wordle": {
					"completed": (completed >= 2) if not is_today else false,
					"inProgress": false,
					"counted": true,
					"score": 100 if ((completed >= 2 and not is_today)) else 0
				},
				"wordef": {
					"completed": (completed >= 1) if not is_today else false,
					"inProgress": false,
					"counted": true,
					"score": 100 if (completed >= 1 and not is_today) else 0
				},
				"unscramble": {
					"completed": (completed >= 3) if not is_today else false,
					"inProgress": false,
					"counted": true,
					"score": 100 if ((completed >= 3 and not is_today)) else 0
				}
			}
		}
	
	_calendar_cache = {
		"today": _today_iso,
		"jalali": _today_jalali,
		"days": days
	}

static func handle_request(method: String, path: String, body: Dictionary, callback: Callable) -> bool:
	if not _is_active:
		return false
	_ensure_init_data()
	
	# Route dispatch
	if path == "/challenge/calendar":
		_respond(callback, true, _calendar_cache.duplicate(true))
		return true
		
	if path.begins_with("/challenge/summary"):
		var date_key: String = _today_iso
		if "date=" in path:
			date_key = path.substr(path.find("date=") + 5).strip_edges()
		if not _summaries.has(date_key):
			_summaries[date_key] = {
				"date": date_key,
				"dayTotal": 0,
				"lifetimeTotal": _lifetime_score,
				"streak": _streak_days,
				"games": {
					"wordle": {"completed": false, "inProgress": false, "counted": true, "score": 0},
					"wordef": {"completed": false, "inProgress": false, "counted": true, "score": 0},
					"unscramble": {"completed": false, "inProgress": false, "counted": true, "score": 0}
				}
			}
		_respond(callback, true, _summaries[date_key].duplicate(true))
		return true
		
	if path == "/challenge/attempts" and method == "POST":
		var game_type: String = str(body.get("gameType", "wordle"))
		var date_key: String = str(body.get("date", _today_iso))
		var attempt_id: String = "mock_att_%s_%d" % [game_type, Time.get_ticks_msec()]
		
		var public_content: Dictionary = {}
		match game_type:
			"wordle":
				public_content = {"wordLength": 5}
			"wordef":
				public_content = {"questions": WORDEF_QUESTIONS}
			"unscramble":
				public_content = {"words": UNSCRAMBLE_WORDS}
		
		var attempt_record: Dictionary = {
			"id": attempt_id,
			"gameType": game_type,
			"date": date_key,
			"status": "in_progress",
			"counted": true,
			"startedAt": Time.get_datetime_string_from_system(true, true),
			"state": {},
			"publicContent": public_content,
			"wordleGuesses": [],
			"wordefIndex": 0,
			"wordefCorrect": 0,
			"unscrambleSolved": [false, false, false, false, false]
		}
		_attempts[attempt_id] = attempt_record
		
		# Update summary to inProgress
		if _summaries.has(date_key):
			var games: Dictionary = _summaries[date_key].get("games", {})
			if games.has(game_type):
				games[game_type]["inProgress"] = true
		
		_respond(callback, true, {
			"attempt": {
				"id": attempt_id,
				"status": "in_progress",
				"counted": true,
				"startedAt": attempt_record["startedAt"],
				"state": {}
			},
			"publicContent": public_content
		})
		return true
		
	if path.begins_with("/challenge/attempts/") and path.ends_with("/wordle-guess"):
		var attempt_id: String = _extract_attempt_id(path)
		var guess: String = str(body.get("guess", "")).to_upper().strip_edges()
		var target: String = WORDLE_TARGET
		
		var feedback: Array = [0, 0, 0, 0, 0]
		var target_chars: Array = []
		for c: String in target:
			target_chars.append(c)
			
		# First pass for exact matches (2 = green)
		for i: int in range(5):
			if i < guess.length() and guess[i] == target[i]:
				feedback[i] = 2
				target_chars[i] = ""
				
		# Second pass for present matches (1 = yellow)
		for i: int in range(5):
			if feedback[i] != 2 and i < guess.length():
				var letter: String = guess[i]
				var found_pos: int = target_chars.find(letter)
				if found_pos != -1:
					feedback[i] = 1
					target_chars[found_pos] = ""
					
		var is_solved: bool = (guess == target)
		if _attempts.has(attempt_id):
			_attempts[attempt_id]["wordleGuesses"].append(guess)
			if is_solved:
				_attempts[attempt_id]["status"] = "completed"
				_record_game_finished(_attempts[attempt_id]["date"], "wordle", 100)
				
		_respond(callback, true, {
			"valid": true,
			"feedback": feedback,
			"solved": is_solved
		})
		return true
		
	if path.begins_with("/challenge/attempts/") and path.ends_with("/wordef-next"):
		var attempt_id: String = _extract_attempt_id(path)
		var att: Dictionary = _attempts.get(attempt_id, {})
		var idx: int = int(att.get("wordefIndex", 0))
		if idx >= WORDEF_QUESTIONS.size():
			_respond(callback, true, {"done": true})
			return true
		var q: Dictionary = WORDEF_QUESTIONS[idx]
		_respond(callback, true, {
			"done": false,
			"index": idx,
			"question": q
		})
		return true
		
	if path.begins_with("/challenge/attempts/") and path.ends_with("/wordef-answer"):
		var attempt_id: String = _extract_attempt_id(path)
		var idx: int = int(body.get("index", 0))
		var chosen: String = str(body.get("option", ""))
		var correct: bool = false
		if idx >= 0 and idx < WORDEF_QUESTIONS.size():
			correct = (chosen == str(WORDEF_QUESTIONS[idx].get("answer", "")))
		if _attempts.has(attempt_id):
			_attempts[attempt_id]["wordefIndex"] = idx + 1
			if correct:
				_attempts[attempt_id]["wordefCorrect"] = int(_attempts[attempt_id].get("wordefCorrect", 0)) + 1
			if idx + 1 >= WORDEF_QUESTIONS.size():
				_attempts[attempt_id]["status"] = "completed"
				_record_game_finished(_attempts[attempt_id]["date"], "wordef", 100)
		_respond(callback, true, {
			"correct": correct,
			"timedOut": false
		})
		return true
		
	if path.begins_with("/challenge/attempts/") and path.ends_with("/clue"):
		var idx: int = int(body.get("index", 0))
		var clue_text: String = "راهنما برای این واژه موجود نیست."
		if idx >= 0 and idx < UNSCRAMBLE_WORDS.size():
			clue_text = str(UNSCRAMBLE_WORDS[idx].get("clueFa", ""))
		_respond(callback, true, {
			"clueFa": clue_text,
			"clue": clue_text
		})
		return true
		
	if path.begins_with("/challenge/attempts/") and path.ends_with("/unscramble-solve"):
		var attempt_id: String = _extract_attempt_id(path)
		var idx: int = int(body.get("index", 0))
		var word: String = str(body.get("word", "")).to_upper().strip_edges()
		var correct: bool = false
		if idx >= 0 and idx < UNSCRAMBLE_WORDS.size():
			correct = (word == str(UNSCRAMBLE_WORDS[idx].get("solution", "")).to_upper())
		if correct and _attempts.has(attempt_id):
			var solved_arr: Array = _attempts[attempt_id].get("unscrambleSolved", [])
			if idx < solved_arr.size():
				solved_arr[idx] = true
			var all_done: bool = true
			for s: bool in solved_arr:
				all_done = all_done and s
			if all_done:
				_attempts[attempt_id]["status"] = "completed"
				_record_game_finished(_attempts[attempt_id]["date"], "unscramble", 100)
		_respond(callback, true, {
			"correct": correct
		})
		return true
		
	if path.begins_with("/challenge/attempts/") and path.ends_with("/submit"):
		var attempt_id: String = _extract_attempt_id(path)
		if _attempts.has(attempt_id):
			var att: Dictionary = _attempts[attempt_id]
			att["status"] = "completed"
			var game_type: String = str(att.get("gameType", "wordle"))
			var date_key: String = str(att.get("date", _today_iso))
			_record_game_finished(date_key, game_type, 100)
		_respond(callback, true, {
			"ok": true,
			"status": "completed",
			"score": 100
		})
		return true
		
	if path.begins_with("/challenge/attempts/") and path.ends_with("/abandon"):
		var attempt_id: String = _extract_attempt_id(path)
		if _attempts.has(attempt_id):
			_attempts[attempt_id]["status"] = "abandoned"
		_respond(callback, true, {"ok": true})
		return true
		
	if path.begins_with("/challenge/attempts/"):
		var attempt_id: String = _extract_attempt_id(path)
		var att: Dictionary = _attempts.get(attempt_id, {})
		_respond(callback, true, {"attempt": att})
		return true
		
	if path.begins_with("/challenge/leaderboard"):
		var is_daily: bool = "daily" in path
		var entries: Array = [
			{"rank": 1, "username": "سارا محمدی", "score": 300 if is_daily else 4200, "isUser": false},
			{"rank": 2, "username": "امیرحسین رضوی", "score": 300 if is_daily else 3950, "isUser": false},
			{"rank": 3, "username": "روژین کاظمی", "score": 290 if is_daily else 3600, "isUser": false},
			{"rank": 12, "username": _user_name, "score": 100 if is_daily else _lifetime_score, "isUser": true}
		]
		_respond(callback, true, {"entries": entries, "total": 120})
		return true
		
	return false

static func _extract_attempt_id(path: String) -> String:
	var clean: String = path.substr("/challenge/attempts/".length())
	var slash_pos: int = clean.find("/")
	if slash_pos != -1:
		return clean.substr(0, slash_pos)
	return clean

static func _record_game_finished(date_key: String, game_type: String, score_gain: int) -> void:
	if not _summaries.has(date_key):
		return
	var summary: Dictionary = _summaries[date_key]
	var games: Dictionary = summary.get("games", {})
	if games.has(game_type):
		var game_dict: Dictionary = games[game_type]
		if not bool(game_dict.get("completed", false)):
			game_dict["completed"] = true
			game_dict["inProgress"] = false
			game_dict["score"] = score_gain
			summary["dayTotal"] = int(summary.get("dayTotal", 0)) + score_gain
			_lifetime_score += score_gain
			summary["lifetimeTotal"] = _lifetime_score
	
	# Update calendar cache day cell
	var days: Array = _calendar_cache.get("days", [])
	for raw: Variant in days:
		if raw is Dictionary and str(raw.get("date", "")) == date_key:
			var cell: Dictionary = raw
			var count: int = 0
			var day_score: int = 0
			for g: String in games:
				if bool(games[g].get("completed", false)):
					count += 1
					day_score += int(games[g].get("score", 0))
			cell["completedGames"] = count
			cell["totalScore"] = day_score
