extends "res://autoload/BackButtonHandler.gd"
class_name OfficialChallengeGame

const DailyChallengeStateStore = preload("res://autoload/DailyChallengeState.gd")

const HUB_SCENE: String = "res://scenes/word_game/WordGameHub.tscn"
const GAME_NAMES: Dictionary = {"wordle": "Wordle", "wordef": "Wordef", "unscramble": "Unscramble"}
const GAME_LIMITS: Dictionary = {"wordle": 180.0, "wordef": 90.0, "unscramble": 180.0}

var _game_type: String = ""
var _attempt_id: String = ""
var _public: Dictionary = {}
var _root: VBoxContainer
var _status: Label
var _body: VBoxContainer
var _busy: bool = false
var _finished: bool = false
var _remaining: float = 0.0
var _timer: Timer
var _wordle_guesses: int = 0
var _wordle_length: int = 5
var _wordef_index: int = -1
var _wordef_question: Dictionary = {}
var _solved_words: Array[bool] = [false, false, false, false, false]
var _score_panel: ChallengeScorePanel

func _ready() -> void:
	_game_type = DailyChallengeState.selected_game
	_attempt_id = DailyChallengeState.current_attempt_id
	_public = DailyChallengeState.current_public_content.duplicate(true)
	_wire_header()
	if _attempt_id.is_empty() or not GAME_NAMES.has(_game_type):
		_show_fatal("اطلاعات تلاش رسمی پیدا نشد.")
		return
	_build_shell()
	if DailyChallengeState.current_attempt_status != "in_progress":
		_show_settled_attempt()
		return
	_remaining = float(GAME_LIMITS.get(_game_type, 180.0))
	var start_time: String = str(DailyChallengeState.current_attempt_started_at)
	if start_time != "":
		var elapsed: int = int(Time.get_unix_time_from_system() - float(Time.get_unix_time_from_datetime_string(start_time)))
		_remaining = maxf(0.0, _remaining - float(maxi(0, elapsed)))
	_timer = Timer.new()
	_timer.wait_time = 0.2
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)
	_timer.start()
	match _game_type:
		"wordle":
			_wordle_length = int(_public.get("wordLength", 5))
			_build_wordle()
			_restore_wordle_state()
		"wordef":
			_restore_wordef_state()
		"unscramble":
			_build_unscramble()
			_restore_unscramble_state()

func _build_shell() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = MenuStyle.c("bg")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 250)
	margin.add_theme_constant_override("margin_bottom", 240)
	scroll.add_child(margin)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 18)
	margin.add_child(_root)
	var timer_label: Label = _label("", 28, true)
	timer_label.name = "TimerLabel"
	_root.add_child(timer_label)
	_score_panel = preload("res://scenes/word_game/ScorePanel.tscn").instantiate() as ChallengeScorePanel
	_score_panel.visible = false
	_root.add_child(_score_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	_root.add_child(_body)
	_status = _label("بارگذاری بازی…", 24, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_status)
	_raise_header()

## The screen wears the app-wide header bar authored in
## OfficialChallengeGame.tscn — the same bar the lesson screens carry — so the
## back arrow plus the centered title replace the old in-page title row.
func _wire_header() -> void:
	var header: Control = get_node_or_null("HeaderBar") as Control
	if header == null:
		return
	var title: Label = header.get_node_or_null("HeaderContent/HeaderTitle") as Label
	if title != null:
		title.text = "چالش رسمی · %s" % str(GAME_NAMES.get(_game_type, ""))
	var back: Button = header.get_node_or_null("HeaderContent/BackButton") as Button
	if back != null:
		back.pressed.connect(_confirm_exit)

## Puts the bar on top of the tree so the built page scrolls underneath it.
func _raise_header() -> void:
	var header: Control = get_node_or_null("HeaderBar") as Control
	if header != null:
		move_child(header, get_child_count() - 1)

func _restore_wordle_state() -> void:
	var state: Dictionary = DailyChallengeState.current_attempt_state
	var guesses: Array = state.get("guesses", [])
	_wordle_guesses = guesses.size()
	var history: Label = _body.get_node_or_null("WordleFeedback") as Label
	var input: LineEdit = _body.get_node_or_null("WordleInput") as LineEdit
	if history == null or input == null:
		return
	for raw: Variant in guesses:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var symbols: String = ""
		var feedback: Array = entry.get("feedback", [])
		for cell: Variant in feedback:
			symbols += "🟩" if int(cell) == 2 else ("🟨" if int(cell) == 1 else "⬛")
		history.text += ("\n" if history.text != "" else "") + "%s  %s" % [str(entry.get("guess", "")).to_upper(), symbols]
		if feedback.size() == _wordle_length:
			var solved: bool = true
			for cell: Variant in feedback:
				if int(cell) != 2:
					solved = false
			if solved:
				_finished = true
	if _wordle_guesses >= 6:
		_finished = true
	if _finished:
		input.editable = false

func _build_wordle() -> void:
	_body.add_child(_label("واژهٔ %d حرفی را در شش حدس پیدا کنید." % _wordle_length, 30, true))
	var input: LineEdit = LineEdit.new()
	input.name = "WordleInput"
	input.placeholder_text = "واژهٔ انگلیسی"
	input.max_length = _wordle_length
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", 38)
	input.add_theme_font_override("font", MenuStyle.vazir())
	input.text_submitted.connect(_on_wordle_submitted)
	_body.add_child(input)
	var submit: Button = MenuStyle.make_button("ثبت حدس", "primary", 96)
	submit.pressed.connect(_on_wordle_submit_button)
	_body.add_child(submit)
	var guesses: Label = _label("", 30, true)
	guesses.name = "WordleFeedback"
	_body.add_child(guesses)

func _on_wordle_submit_button() -> void:
	var input: LineEdit = _body.get_node_or_null("WordleInput") as LineEdit
	if input != null:
		_on_wordle_submitted(input.text)

func _on_wordle_submitted(value: String) -> void:
	if _busy or _finished:
		return
	var guess: String = value.strip_edges().to_lower()
	if guess.length() != _wordle_length:
		_status.text = "حدس باید دقیقاً %d حرف داشته باشد." % _wordle_length
		return
	_busy = true
	_status.text = "در حال بررسی حدس توسط سرور…"
	API.submit_wordle_guess(_attempt_id, guess, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if not ok:
			if str(data.get("error", "")) == "timeout":
				_finish_attempt("زمان رسمی به پایان رسیده است.")
			else:
				_status.text = _friendly_error(data)
			return
		if not bool(data.get("valid", false)):
			_status.text = "این واژه در فهرست معتبر نیست."
			return
		_wordle_guesses += 1
		var feedback: Array = data.get("feedback", [])
		var symbols: String = ""
		for cell: Variant in feedback:
			symbols += "🟩" if int(cell) == 2 else ("🟨" if int(cell) == 1 else "⬛")
		var history: Label = _body.get_node("WordleFeedback") as Label
		history.text += ("\n" if history.text != "" else "") + "%s  %s" % [guess.to_upper(), symbols]
		var input: LineEdit = _body.get_node("WordleInput") as LineEdit
		input.clear()
		if bool(data.get("solved", false)):
			_finish_attempt("واژه را پیدا کردید!")
		elif _wordle_guesses >= 6:
			_finish_attempt("حدس‌ها تمام شد.")
		else:
			_status.text = "حدس پذیرفته شد."
	)

func _restore_wordef_state() -> void:
	var state: Dictionary = DailyChallengeState.current_attempt_state
	var answers: Array = state.get("answers", [])
	if answers.size() >= int(_public.get("questions", []).size()) and not answers.is_empty():
		_finish_attempt("همهٔ پرسش‌ها قبلاً پاسخ داده شده‌اند.")
	else:
		_load_next_wordef()

func _load_next_wordef() -> void:
	if _busy or _finished:
		return
	_busy = true
	API.next_wordef_question(_attempt_id, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if not ok:
			if str(data.get("error", "")) == "timeout":
				_finish_attempt("زمان رسمی بازی به پایان رسیده است.")
			else:
				_status.text = _friendly_error(data)
			return
		if bool(data.get("done", false)):
			_finish_attempt("همهٔ پرسش‌ها پاسخ داده شدند.")
			return
		_wordef_index = int(data.get("index", -1))
		_wordef_question = data.get("question", {})
		_render_wordef_question()
	)

func _render_wordef_question() -> void:
	_clear_body()
	var question: Dictionary = _wordef_question
	var text: String = str(question.get("prompt", ""))
	var kind: String = str(question.get("kind", "meaning"))
	var question_type: String = "معنی" if kind == "meaning" else ("مترادف" if kind == "synonym" else "متضاد")
	_body.add_child(_label("پرسش %s · %s" % [str(_wordef_index + 1), question_type], 28, true))
	_body.add_child(_label(str(question.get("word", "")), 46, true))
	_body.add_child(_label(text, 26, true))
	for option_raw: Variant in question.get("options", []):
		var option: String = str(option_raw)
		var answer_button: Button = MenuStyle.make_button(option, "secondary", 100)
		answer_button.pressed.connect(_submit_wordef_answer.bind(option))
		_body.add_child(answer_button)

func _submit_wordef_answer(option: String) -> void:
	if _busy or _finished:
		return
	_busy = true
	_status.text = "در حال ثبت پاسخ…"
	API.answer_wordef_question(_attempt_id, _wordef_index, option, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if not ok:
			if str(data.get("error", "")) == "timeout":
				_finish_attempt("زمان رسمی بازی به پایان رسیده است.")
			else:
				_status.text = _friendly_error(data)
			return
		if bool(data.get("timedOut", false)):
			_status.text = "زمان این پرسش تمام شد."
		else:
			_status.text = "پاسخ درست بود." if bool(data.get("correct", false)) else "پاسخ ثبت شد."
		_load_next_wordef()
	)

func _restore_unscramble_state() -> void:
	var state: Dictionary = DailyChallengeState.current_attempt_state
	for raw: Variant in state.get("solved", []):
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var index: int = int(entry.get("index", -1))
		if index < 0 or index >= _solved_words.size():
			continue
		_solved_words[index] = true
		var panel: PanelContainer = _body.get_node_or_null("Word%d" % index) as PanelContainer
		if panel != null:
			panel.modulate = Color(0.72, 1.0, 0.75, 1.0)
			var answer: LineEdit = panel.find_child("Answer", true, false) as LineEdit
			if answer != null:
				answer.editable = false

func _build_unscramble() -> void:
	var words: Array = _public.get("words", [])
	if words.size() != 5:
		_status.text = "محتوای این بازی از سرور کامل دریافت نشد."
		return
	for i: int in range(words.size()):
		var row_data: Variant = words[i]
		if not row_data is Dictionary:
			continue
		var word_data: Dictionary = row_data
		var panel: PanelContainer = PanelContainer.new()
		panel.name = "Word%d" % i
		panel.add_theme_stylebox_override("panel", MenuStyle.card_style(MenuStyle.border(), 20, false, false))
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		panel.add_child(column)
		column.add_child(_label("واژهٔ %d: %s" % [i + 1, str(word_data.get("scrambledWord", ""))], 32, true))
		var clue: Label = _label("راهنما هنوز باز نشده است.", 20, true)
		clue.name = "Clue"
		column.add_child(clue)
		var input: LineEdit = LineEdit.new()
		input.name = "Answer"
		input.placeholder_text = "واژهٔ مرتب‌شده"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(input)
		var actions: HBoxContainer = HBoxContainer.new()
		column.add_child(actions)
		var solve: Button = MenuStyle.make_button("بررسی", "primary", 74)
		solve.pressed.connect(_solve_unscramble.bind(i, input, panel))
		actions.add_child(solve)
		var hint: Button = MenuStyle.make_button("راهنما", "secondary", 74)
		hint.pressed.connect(_request_clue.bind(i, clue))
		actions.add_child(hint)
		_body.add_child(panel)

func _request_clue(index: int, label: Label) -> void:
	if _busy or _finished:
		return
	_busy = true
	API.reveal_unscramble_clue(_attempt_id, index, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if not ok:
			if str(data.get("error", "")) == "timeout":
				_finish_attempt("زمان رسمی بازی به پایان رسیده است.")
			else:
				_status.text = _friendly_error(data)
			return
		label.text = str(data.get("clueFa", data.get("clue", "راهنما موجود نیست.")))
		_status.text = "راهنما ثبت شد؛ جریمهٔ آن را سرور هنگام محاسبه اعمال می‌کند."
	)

func _solve_unscramble(index: int, input: LineEdit, panel: PanelContainer) -> void:
	if _busy or _finished:
		return
	var answer: String = input.text.strip_edges()
	if answer.is_empty():
		_status.text = "ابتدا پاسخ را بنویسید."
		return
	_busy = true
	API.solve_unscramble_word(_attempt_id, index, answer, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if not ok:
			if str(data.get("error", "")) == "timeout":
				_finish_attempt("زمان رسمی بازی به پایان رسیده است.")
			else:
				_status.text = _friendly_error(data)
			return
		if not bool(data.get("correct", false)):
			_status.text = "پاسخ درست نیست؛ دوباره تلاش کنید."
			return
		_solved_words[index] = true
		panel.modulate = Color(0.72, 1.0, 0.75, 1.0)
		input.editable = false
		_status.text = "درست بود! زمان و امتیاز را سرور ثبت کرد."
		var complete: bool = true
		for solved: bool in _solved_words:
			complete = complete and solved
		if complete:
			_finish_attempt("هر پنج واژه حل شد!")
	)

func _on_timer_tick() -> void:
	_remaining = maxf(0.0, _remaining - _timer.wait_time)
	var timer_label: Label = _root.get_node_or_null("TimerLabel") as Label
	if timer_label != null:
		timer_label.text = "زمان تقریبی: %s ثانیه" % JalaliCalendar.persian_digits(str(int(ceil(_remaining))))
	if _remaining <= 0.0 and not _finished and not _busy:
		_finish_attempt("زمان به پایان رسید؛ امتیاز بر اساس داده‌های ثبت‌شده محاسبه می‌شود.")

func _show_settled_attempt() -> void:
	_finished = true
	_busy = true
	if DailyChallengeState.current_attempt_status == "completed":
		_status.text = "در حال دریافت نتیجهٔ ثبت‌شده…"
		API.settle_challenge_attempt(_attempt_id, func(ok: bool, data: Dictionary) -> void:
			_busy = false
			if not ok:
				_status.text = _friendly_error(data)
				return
			var result: Dictionary = data.get("result", {})
			var score: int = int(result.get("adjustedScore", 0))
			_score_panel.visible = true
			_score_panel.set_scores(score, 0, "نتیجهٔ ثبت‌شده")
			if DailyChallengeState.current_attempt_counted:
				API.fetch_challenge_summary(DailyChallengeState.selected_date, func(summary_ok: bool, summary: Dictionary) -> void:
					if summary_ok and is_instance_valid(_score_panel):
						_score_panel.set_scores(score, int(summary.get("lifetimeTotal", 0)), "نتیجهٔ ثبت‌شده")
				)
			_status.text = "این تلاش قبلاً تکمیل شده است؛ نتیجهٔ رسمی: %s" % JalaliCalendar.persian_digits(str(score))
			var back: Button = MenuStyle.make_button("بازگشت به تقویم", "secondary", 90)
			back.pressed.connect(_return_to_calendar)
			_root.add_child(back)
		)
	else:
		_busy = false
		_finished = true
		_status.text = "این تلاش قبلاً بدون امتیاز بسته شده است."
		var back: Button = MenuStyle.make_button("بازگشت به تقویم", "secondary", 90)
		back.pressed.connect(_return_to_calendar)
		_root.add_child(back)

func _finish_attempt(message: String) -> void:
	if _finished:
		return
	_finished = true
	_busy = true
	if _timer != null:
		_timer.stop()
	_status.text = message + " در حال محاسبهٔ نتیجه توسط سرور…"
	API.settle_challenge_attempt(_attempt_id, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if not ok:
			_finished = false
			if str(data.get("error", "")) == "not_finished":
				_status.text = "بازی هنوز به پایان نرسیده است. اگر از صفحه خارج شوید، تلاش رسمی بدون امتیاز بسته می‌شود؛ دوباره تلاش کنید یا خروج را تأیید کنید."
			else:
				_status.text = _friendly_error(data) + " نتیجه روی سرور باقی مانده؛ دوباره تلاش کنید."
			return
		var result: Dictionary = data.get("result", {})
		var score: int = int(result.get("adjustedScore", 0))
		_score_panel.visible = true
		if DailyChallengeState.current_attempt_counted:
			_score_panel.set_scores(score, 0, "امتیاز رسمی این بازی")
			API.fetch_challenge_summary(DailyChallengeState.selected_date, func(summary_ok: bool, summary: Dictionary) -> void:
				if summary_ok and is_instance_valid(_score_panel):
					_score_panel.set_scores(score, int(summary.get("lifetimeTotal", 0)), "امتیاز رسمی این بازی")
			)
		else:
			_score_panel.set_scores(score, 0, "امتیاز تمرین")
		_status.text = "%s امتیاز %s: %s · نسخهٔ امتیازدهی %s" % [message, "رسمی" if DailyChallengeState.current_attempt_counted else "تمرین", JalaliCalendar.persian_digits(str(score)), str(result.get("scoringVersion", "—"))]
		if not DailyChallengeState.current_attempt_counted:
			_status.text += "\nامتیاز تمرین در رتبه‌بندی ثبت نمی‌شود."
		var back: Button = MenuStyle.make_button("بازگشت به تقویم", "secondary", 90)
		back.pressed.connect(_return_to_calendar)
		_root.add_child(back)
	)

func _confirm_exit() -> void:
	if _finished:
		_return_to_calendar()
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "پایان تلاش رسمی"
	dialog.dialog_text = "با خروج پیش از تکمیل بازی، تلاش رسمی بدون امتیاز بسته می‌شود. خارج می‌شوید؟"
	dialog.ok_button_text = "خروج بدون امتیاز"
	dialog.cancel_button_text = "ادامه بازی"
	dialog.confirmed.connect(func() -> void: _abandon_attempt(dialog))
	add_child(dialog)
	dialog.popup_centered(Vector2i(720, 320))

func _abandon_attempt(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	if _busy or _finished:
		return
	_busy = true
	_status.text = "در حال بستن تلاش رسمی…"
	API.abandon_challenge_attempt(_attempt_id, func(ok: bool, data: Dictionary) -> void:
		_busy = false
		if not ok:
			_status.text = _friendly_error(data) + " تلاش روی سرور باز ماند."
			return
		_finished = true
		_return_to_calendar()
	)

func _return_to_calendar() -> void:
	DailyChallengeStateStore.clear_attempt()
	TransitionManager.change_scene(HUB_SCENE)

func _show_fatal(message: String) -> void:
	var label: Label = _label(message, 30, true)
	label.set_anchors_preset(Control.PRESET_CENTER)
	add_child(label)
	var back: Button = MenuStyle.make_button("بازگشت", "secondary", 90)
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.pressed.connect(_return_to_calendar)
	add_child(back)

func _friendly_error(data: Dictionary) -> String:
	match str(data.get("error", "")):
		"timeout":
			return "زمان رسمی بازی به پایان رسیده است."
		"invalid_word", "invalid_guess":
			return "واژه در فهرست پاسخ‌های معتبر نیست."
		"closed":
			return "این تلاش دیگر باز نیست."
		_:
			return "ارتباط با سرور ناموفق بود؛ اتصال را بررسی کنید و دوباره تلاش کنید."

func _clear_body() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

func _label(value: String, font_size: int, centered: bool) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", MenuStyle.vazir())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", MenuStyle.text())
	return label

func _on_android_back_pressed() -> void:
	_confirm_exit()