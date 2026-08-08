class_name ExerciseGrader
extends RefCounted

## Pure, stateless grading logic. Easily testable without instantiating nodes.

class Result:
	var is_correct: bool
	var correct_count: int
	var total_count: int
	var feedback_text: String
	var feedback_color: Color

static func grade_item(user_answer: Variant, item: ExerciseData.Item) -> Result:
	var res := Result.new()
	res.total_count = 1
	
	var is_correct := compare_answer(
		user_answer, 
		item.answer, 
		item.compiled_patterns, 
		item.required_words, 
		item.forbidden_words
	)
	
	res.is_correct = is_correct
	res.correct_count = 1 if is_correct else 0
	
	if is_correct:
		res.feedback_text = "Correct!"
		res.feedback_color = ExerciseTheme.COLORS.success
	else:
		var ans_text := item.answer_display if item.answer_display != "" else str(item.answer)
		res.feedback_text = "Correct answer: " + ans_text
		if item.explanation_en != "":
			res.feedback_text += "\n" + item.explanation_en
		res.feedback_color = ExerciseTheme.COLORS.error
		
	return res

static func compare_answer(user_answer: Variant, correct_answer: Variant, patterns: Array[RegEx] = [], required: Array = [], forbidden: Array = []) -> bool:
	if user_answer == null or correct_answer == null:
		return false
		
	var user_str := str(user_answer)
	var norm := ExerciseData.normalize(user_str)
	
	# Check Regex Patterns
	for rx in patterns:
		if rx.search(user_str):
			return true
			
	# Check Required/Forbidden Words
	if not required.is_empty():
		var req_ok := true
		for w in required:
			if not norm.contains(ExerciseData.normalize(str(w))):
				req_ok = false
				break
		if req_ok:
			for w in forbidden:
				if norm.contains(ExerciseData.normalize(str(w))):
					req_ok = false
					break
		if req_ok:
			return true
			
	# Direct Comparison
	return ExerciseData.normalize(str(user_answer)) == ExerciseData.normalize(str(correct_answer))

# ==========================================
# ADD THIS TO ExerciseGrader.gd
# ==========================================

static func format_answer(answer: Variant) -> String:
	if answer is Array:
		var parts: Array = []
		for a in answer:
			parts.append(format_answer(a))
		return " / ".join(parts)
	if answer is bool:
		return "True" if answer else "False"
	if answer is Dictionary:
		return ExerciseData.get_en_text(answer)
	if answer == null:
		return ""
	return str(answer)
