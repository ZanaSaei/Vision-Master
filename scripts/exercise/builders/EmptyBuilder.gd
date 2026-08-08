class_name EmptyBuilder
extends ExerciseBuilder

## Used for non-interactive types like passage/reading.
## The Engine renders the passage text; this builder adds no gradable items.

func build(parent: VBoxContainer, data: ExerciseData, items: Array[ExerciseData.Item], gesture_handler: ExerciseGestureHandler) -> void:
	# Intentionally empty — non-interactive exercises have no gradable content.
	pass
