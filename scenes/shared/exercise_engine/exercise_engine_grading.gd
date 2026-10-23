# ============================================================
# ExerciseEngine - GRADING layer.
# Part of the split ExerciseEngine module (see the leaf file
# ExerciseEngine.gd in this folder for the layout map).
# Holds: _exit_tree, answer checking / comparison, scoring,
# retry, open-ended reveal + save.
# ============================================================
class_name ExerciseEngineGrading
extends "res://scenes/shared/exercise_engine/exercise_engine_builders.gd"

func _exit_tree() -> void:
	# Stop the audio and free the panel if this engine created it.
	if _audio_panel != null and is_instance_valid(_audio_panel):
		if _audio_panel.is_playing():
			_audio_panel.stop_and_close()
		if _audio_panel_owned:
			_audio_panel.queue_free()
	# Stop following live theme changes.
	if _theme_hook_active and _global() != null:
		_theme_hook_active = false
		var g: Node = _global()
		var theme_changed_signal: Signal = g.get("theme_changed")
		if theme_changed_signal.is_connected(_apply_theme):
			theme_changed_signal.disconnect(_apply_theme)

# ============================================================
# GRADING
# ============================================================
func _on_check_pressed() -> void:
	if _is_graded:
		_reset_for_retry()
		return
	_grade_all()


# Public API used by harnesses (e.g. the grammar exam) that want to grade
# every item without touching the engine's own check button. Unlike
# _on_check_pressed this never enters the retry/rebuild path, so it can be
# called again after the learner corrects an answer to re-grade in place.
func grade_all() -> void:
	if _is_graded:
		_is_graded = false
	_grade_all()


func _grade_all() -> void:
	# Word Search uses its own visual grading.
	if str(_exercise.get("type", "")) in ["word_search", "word_find"]:
		_grade_word_search()
		return
	var correct := 0
	var total := 0
	for item in _items:
		if not item.has("get"):
			continue
		total += 1
		var user_answer = item["get"].call()
		var is_correct := _is_item_correct(item, user_answer)
		# Count BEFORE the feedback check: some types (e.g. inline cloze) carry
		# no per-item feedback label but must still be scored.
		if is_correct:
			correct += 1
		var fb: Label = item.get("feedback", null)
		if fb == null:
			continue
		fb.visible = true
		# Prefer the human-readable answer text. Fall back to the formatted
		# raw answer only when no display text exists.
		# Prefer the human-readable answer text; fall back to the raw
		# answer only when no display text exists.
		var answer_text: String = str(item.get("answer_display", ""))
		if answer_text == "":
			answer_text = _format_answer(item.get("answer"))
		var item_type := str(item.get("type", ""))
		# If the user left a text field empty, show the Farsi "Empty" label.
		var user_str := str(user_answer).strip_edges()
		if user_str == "" and item_type in ["fill_blank", "chart_fill", "transformation", "letter_scramble", "error_correction", "passive_transformation", "question_formation"]:
			fb.text = _t_fa("empty")
			fb.set_meta("text_fa", fb.text)
			fb.add_theme_color_override("font_color", _c_warning())
			continue
		if is_correct:
			if item_type in ["text_highlight", "text_highlight_multi", "word_search_cell"]:
				fb.text = "✓"
			else:
				# Feedback label is always Farsi.
				fb.text = _t_fa("correct")
				fb.set_meta("text_fa", fb.text)
			fb.add_theme_color_override("font_color", _c_success())
		else:
			if item_type in ["text_highlight", "text_highlight_multi", "word_search_cell"]:
				fb.text = "✗"
			else:
				var expl_en := str(item.get("explanation_en", ""))
				var expl_fa := str(item.get("explanation_fa", ""))
				# Label in Farsi, but the correct answer itself stays English.
				fb.text = _t_fa("correct_answer_prefix") + answer_text
				if expl_en != "":
					fb.text += "\n" + expl_en
				# Farsi mirror, kept for the translate-toggle convention.
				var fa_text := _t_fa("correct_answer_prefix") + answer_text
				if expl_fa != "":
					fa_text += "\n" + expl_fa
				elif expl_en != "":
					fa_text += "\n" + expl_en
				fb.set_meta("text_fa", fa_text)
			fb.add_theme_color_override("font_color", _c_error())
	_is_graded = true
	# Inline cloze recolors its blank slots instead of using per-item labels.
	if str(_exercise.get("type", "")) == "cloze":
		_apply_cloze_feedback()
	if _score_banner:
		_score_banner.visible = true
		if total > 0 and correct == total:
			_score_banner.text = _t_fa("excellent_score") % [correct, total]
			_score_banner.set_meta("text_fa", _score_banner.text)
			_score_banner.add_theme_color_override("font_color", _c_success())
		else:
			_score_banner.text = _t_fa("got_score") % [correct, total]
			_score_banner.set_meta("text_fa", _score_banner.text)
			_score_banner.add_theme_color_override("font_color", C_PRIMARY)
	if _note_label:
		_note_label.visible = true
	if _check_btn:
		_check_btn.text = _t("try_again")
		_apply_fa_meta(_check_btn, "try_again")
	exercise_checked.emit(str(_exercise.get("exercise_id", "")), correct, total)

func _is_item_correct(item: Dictionary, user_answer: Variant) -> bool:
	var item_type := str(item.get("type", ""))
	# Multi-line categorization cell: the user types one word per line. It is
	# correct if every non-empty line is an accepted answer word (case-insensitive).
	if item_type == "textarea":
		var accepted: Array = []
		for w in item.get("answer", []):
			accepted.append(_normalize(str(w)))
		var u := str(user_answer)
		var any_line := false
		for ln in u.split("\n"):
			var s := _normalize(ln)
			if s == "":
				continue
			any_line = true
			if not accepted.has(s):
				return false
		return any_line
	if item_type == "image_hotspot":
		var u: Array = []
		if user_answer is Array:
			for x in user_answer:
				u.append(str(x))
		var c: Array = []
		var ans = item.get("answer", [])
		if ans is Array:
			for x in ans:
				c.append(str(x))
		else:
			c.append(str(ans))
		u.sort()
		c.sort()
		return _compare(u, c)
	# 1) Exact match against the accepted answer(s).
	if _compare(user_answer, item.get("answer")):
		return true
	var user_str := str(user_answer)
	var norm := _normalize(user_str)
	# 2) Optional regex patterns (harmless when the list is empty).
	var patterns: Array = item.get("answer_patterns", [])
	for pat in patterns:
		var rx := RegEx.new()
		if rx.compile(str(pat)) == OK:
			if rx.search(user_str):
				return true
	# 3) Optional required/forbidden words.
	# IMPORTANT: skip this block when the list is empty. Before this fix,
	# an empty required_words list left req_ok = true, so EVERY typed
	# answer was accepted as correct.
	var required: Array = item.get("required_words", [])
	if not required.is_empty():
		var req_ok := true
		for w in required:
			if not norm.contains(_normalize(str(w))):
				req_ok = false
				break
		if req_ok:
			for w in item.get("forbidden_words", []):
				if norm.contains(_normalize(str(w))):
					req_ok = false
					break
		if req_ok:
			return true
	return false

func _compare(user_answer: Variant, correct_answer: Variant) -> bool:
	if user_answer == null:
		return false
	if correct_answer == null:
		return false

	if correct_answer is Array:
		# An empty list means no correct answer was defined for this item.
		# Treat it as wrong instead of accepting anything non-empty.
		if correct_answer.is_empty():
			return false
		if user_answer is Array:
			if user_answer.size() != correct_answer.size():
				return false
			for i in user_answer.size():
				if not _compare(user_answer[i], correct_answer[i]):
					return false
			return true
		var normalized := _normalize(str(user_answer))
		for accepted in correct_answer:
			if _normalize(str(accepted)) == normalized:
				return true
		return false

	if user_answer is Array:
		return false

	if correct_answer is bool:
		if user_answer is bool:
			return user_answer == correct_answer
		var s := _normalize(str(user_answer))
		if s in ["true", "t", "yes", "y"]:
			return correct_answer == true
		if s in ["false", "f", "no", "n"]:
			return correct_answer == false
		return false

	if correct_answer is int and user_answer is String and user_answer.is_valid_int():
		return int(user_answer) == int(correct_answer)

	if user_answer is String and correct_answer is String:
		return _normalize(user_answer) == _normalize(correct_answer)

	return user_answer == correct_answer

func _format_answer(answer: Variant) -> String:
	if answer is Array:
		var parts: Array = []
		for a in answer:
			parts.append(_format_answer(a))
		return _join_string_array(parts, " / ")
	if answer is bool:
		return "True" if answer else "False"
	if answer is Dictionary:
		return _get_en_text(answer)
	if answer == null:
		return ""
	return str(answer)


# Resets the ALREADY-BUILT exercise in place for another attempt.
#
# This used to call build(_exercise, false), which deleted and recreated every
# node in the exercise. That caused visible flicker, reset the workbook page's
# scroll position and re-ran the whole build cost on every "Try Again".
#
# Instead we now walk the records collected during build() and reset each
# control to the state it had right after construction:
#   * every per-item feedback label is cleared and hidden,
#   * every item's own "reset" callback (registered by its _build_* method)
#     restores its answers / selections / dropdowns / inputs,
#   * cloze and word-search, which grade through their own visuals rather than
#     per-item feedback, are handled explicitly,
#   * the score banner and Check button are restored to their initial look.
# The UI tree, node references, scroll position and behaviour are untouched.
func _reset_for_retry() -> void:
	_is_graded = false

	if _score_banner:
		_score_banner.visible = false

	# A note that is hidden at build time (graded exercises) is revealed after
	# grading; put it back to its initial visibility.
	if _note_label:
		_note_label.visible = _is_open_ended or _is_non_interactive

	# Reset each item's own controls/answers and clear its feedback label.
	for item in _items:
		var fb: Variant = item.get("feedback", null)
		if fb is Label and is_instance_valid(fb):
			(fb as Label).text = ""
			(fb as Label).visible = false
		var reset: Variant = item.get("reset", null)
		if reset is Callable and (reset as Callable).is_valid():
			(reset as Callable).call()

	# Inline cloze recolors its blank slots instead of using per-item labels.
	if str(_exercise.get("type", "")) == "cloze":
		_reset_cloze_for_retry()

	# Word search freezes and recolors its word buttons on grading.
	if str(_exercise.get("type", "")) in ["word_search", "word_find"]:
		_reset_word_search_for_retry()

	if _check_btn:
		_check_btn.text = _t("check_answer")
		_apply_fa_meta(_check_btn, "check_answer")


# Clears every inline cloze blank and re-renders the passage so the numbered
# placeholders reappear. The passage control itself is NOT rebuilt.
func _reset_cloze_for_retry() -> void:
	_cloze_graded_all = false
	_cloze_active = -1
	for i in _cloze_choices.size():
		_cloze_choices[i] = ""
		if i < _cloze_graded.size():
			_cloze_graded[i] = false
	if _cloze_popup != null:
		_cloze_popup.hide()
	_refresh_cloze_bbcode()


# Word search disables and recolors its word buttons during grading; put them
# back to their neutral, tappable idle state.
func _reset_word_search_for_retry() -> void:
	for item in _items:
		if str(item.get("type", "")) != "word_search_word":
			continue
		var btn: Button = item.get("word_button", null)
		if btn == null or not is_instance_valid(btn):
			continue
		btn.disabled = false
		btn.button_pressed = false
		_style_word_search_word_button(btn, "idle")


func _on_reveal_sample() -> void:
	var is_showing := false
	for item in _items:
		if item.has("sample_label") and item["sample_label"] != null:
			item["sample_label"].visible = not item["sample_label"].visible
			if item["sample_label"].visible:
				is_showing = true

	if _reveal_btn:
		if is_showing:
			_reveal_btn.text = _t("hide_sample_answer")
			_apply_fa_meta(_reveal_btn, "hide_sample_answer")
			# Gray color for Hide
			_set_button_color(_reveal_btn, _c_text_dim())
		else:
			_reveal_btn.text = _t("show_sample_answer")
			_apply_fa_meta(_reveal_btn, "show_sample_answer")
			# Orange color for Show
			_set_button_color(_reveal_btn, C_ORANGE)


func _on_open_ended_done() -> void:
	# Save the user's answers to disk
	_save_open_ended_answers()

	if _note_label:
		_note_label.visible = true

	if _done_btn:
		_done_btn.text = _t("saved")
		_apply_fa_meta(_done_btn, "saved")
		_is_saved = true
		# Gray color for Saved state
		_set_button_color(_done_btn, _c_text_dim())

	exercise_checked.emit(str(_exercise.get("exercise_id", "")), 1, 1)