class_name ExerciseTypeRegistry
extends RefCounted

## Maps exercise type strings to their corresponding Builder instances.
## Uses the Strategy Pattern to decouple the Engine from specific exercise implementations.

static var _builders: Dictionary = {}

static func _static_init() -> void:
	# Register all your builders here. 
	# Ensure every builder file has a matching class_name (e.g., class_name MultipleChoiceBuilder)
	register("multiple_choice", MultipleChoiceBuilder.new())
	register("true_false", TrueFalseBuilder.new())
	register("matching", MatchingBuilder.new())
	register("fill_blank", FillBlankBuilder.new())
	register("cloze", ClozeBuilder.new())
	register("ordering", OrderingBuilder.new())
	register("categorize", CategorizeBuilder.new())
	
	# Open-ended types can share the same builder logic
	var open_ended_builder := OpenEndedBuilder.new()
	register("open_ended", open_ended_builder)
	register("pronunciation", open_ended_builder)
	register("writing", open_ended_builder)
	
	register("word_bank", WordBankBuilder.new())
	register("sentence_ordering", SentenceOrderingBuilder.new())
	register("sentence_unscramble", SentenceOrderingBuilder.new())
	register("letter_scramble", LetterScrambleBuilder.new())
	register("table_fill", TableFillBuilder.new())
	register("table_fill_advanced", TableFillAdvancedBuilder.new())
	register("text_highlight", TextHighlightBuilder.new())
	register("text_highlight_multi", TextHighlightMultiBuilder.new())
	register("transformation", TransformationBuilder.new())
	register("error_correction", ErrorCorrectionBuilder.new())
	register("word_building", WordBuildingBuilder.new())
	register("word_search", WordSearchBuilder.new())
	register("word_find", WordSearchBuilder.new())
	register("chart_fill", ChartFillBuilder.new())
	register("odd_one_out", OddOneOutBuilder.new())
	register("grammar_choice", GrammarChoiceBuilder.new())
	register("passive_transformation", PassiveTransformationBuilder.new())
	register("grammar_identification", GrammarIdentificationBuilder.new())
	register("question_formation", QuestionFormationBuilder.new())
	register("token_label", TokenLabelBuilder.new())
	register("image_choice", ImageChoiceBuilder.new())
	register("image_match", ImageMatchBuilder.new())
	register("image_hotspot", ImageHotspotBuilder.new())
	
	# Non-interactive types can use an EmptyBuilder or be handled directly by the Engine
	register("passage", EmptyBuilder.new())
	register("reading", EmptyBuilder.new())

static func register(type: String, builder: ExerciseBuilder) -> void:
	_builders[type] = builder

static func get_builder(type: String) -> ExerciseBuilder:
	if _builders.has(type):
		return _builders[type]
		
	# Fallback to open_ended if type is unknown to prevent crashes
	if _builders.has("open_ended"):
		push_warning("ExerciseTypeRegistry: Unknown type '%s', falling back to open_ended." % type)
		return _builders["open_ended"]
		
	return null
