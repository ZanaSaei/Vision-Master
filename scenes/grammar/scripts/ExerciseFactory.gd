class_name ExerciseFactory
extends RefCounted


static func create_exercise(
		type: String
	) -> GrammarExercise:

	match type:

		"multiple_choice":
			return MultipleChoiceExercise.new()

		"fill_blank":
			return FillBlankExercise.new()

		"true_false":
			return TrueFalseExercise.new()

		"matching":
			return MatchingExercise.new()

		"unscramble":
			return UnscrambleExercise.new()

		_:
			push_error(
				"Unknown exercise type: " + type
			)

			return null
