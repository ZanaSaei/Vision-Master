class_name GrammarExercise
extends Control


signal answer_selected(correct: bool, explanation: String)
signal exercise_completed


var exercise_data: Dictionary = {}
var current_index: int = 0
var answered: bool = false


func setup(data: Dictionary) -> void:
	exercise_data = data
	current_index = 0
	answered = false


func get_item_count() -> int:
	if exercise_data.has("questions"):
		return exercise_data["questions"].size()

	if exercise_data.has("items"):
		return exercise_data["items"].size()

	return 0


func submit_result(
		correct: bool,
		explanation: String = ""
	) -> void:
	answer_selected.emit(
		correct,
		explanation
	)


func complete() -> void:
	exercise_completed.emit()


func continue_to_next() -> void:
	current_index += 1

	if current_index >= get_item_count():
		complete()
