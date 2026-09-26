class_name AppRouter
## ============================================================
##  APP ROUTER — named navigation + typed route arguments.
##
##  Replaces the old pattern of passing state between screens
##  through muddy global fields (Global.flashcard_mode,
##  Global.word_review_return, ...) and hard-coded res:// paths.
##
##  - ROUTES is a single named registry, so screens navigate by a
##    stable route name instead of inline scene strings.
##  - `push()` / `change()` resolve a route and drive the shared
##    TransitionManager (slide for drill-downs, fade for side-menu).
##  - Exit state is carried explicitly in `args` (a typed payload
##    for the destination) instead of hidden globals. `set_args`
##    merges key-by-key so multi-field payloads (mode + return route)
##    composed at different steps never clobber each other.
## ============================================================

const ROUTES := {
	"main_menu":      "res://scenes/main_menu/MainMenu.tscn",
	"book_menu":      "res://scenes/book_menu/BookMenu.tscn",
	"lesson_menu":    "res://scenes/lesson_menu/LessonMenu.tscn",
	"flashcards":     "res://scenes/vocabulary/VocabFlashcards.tscn",
	"saved_words":    "res://scenes/saved_words/SavedWords.tscn",
	"review":         "res://scenes/review/WordReview.tscn",
	"settings":       "res://scenes/settings/Settings.tscn",
	"account":        "res://scenes/auth/Auth.tscn",
	"final_exams":    "res://scenes/exam/FinalExams.tscn",
	"final_exam_list": "res://scenes/exam/FinalExamList.tscn",
	"final_exam":     "res://scenes/exam/FinalExam.tscn",
	"purchase":       "res://scenes/purchase/Purchase.tscn",
	"about_me":       "res://scenes/about_me/AboutMe.tscn",
	"conversation":   "res://scenes/conversation/Conversation.tscn",
	"reading":        "res://scenes/reading/Reading.tscn",
	"grammar_hub":    "res://scenes/grammar/GrammarHub.tscn",
	"dictionary":     "res://scenes/shared/DictionaryPopup.tscn",
}

## Payload for the route currently being pushed (or last pushed).
static var _args: Dictionary = {}
## The route name currently active ("main_menu" etc.).
static var _route_name: String = ""


## Resolve a route name to its .tscn path; unknown names are returned
## untouched so raw scene paths still work as a fallback.
static func resolve(route: String) -> String:
	return str(ROUTES.get(route, route))


## Slide to a route (going deeper in the menu flow), carrying `args`.
static func push(route: String, args: Dictionary = {}) -> void:
	_navigate(route, args)
	TransitionManager.slide_change_scene(resolve(route), TransitionManager.Slide.FORWARD)


## Fade to a route (side-menu destinations), carrying `args`.
static func change(route: String, args: Dictionary = {}) -> void:
	_navigate(route, args)
	TransitionManager.change_scene(resolve(route))


## Fade back to a route (up one level), carrying `args`.
static func back(route: String, args: Dictionary = {}) -> void:
	_navigate(route, args)
	TransitionManager.change_scene(resolve(route))


## Merge `args` into the current payload (overwrite on collision), so a
## destination built up in steps (mode set first, return-route added later)
## never drops a field. Shallow merge is enough for our scalar/array values.
static func set_args(args: Dictionary) -> void:
	for key in args:
		_args[key] = args[key]


## Read a payload field for the destination scene.
static func get_arg(key: String, default: Variant = null) -> Variant:
	return _args.get(key, default)


static func _navigate(route: String, args: Dictionary) -> void:
	_route_name = route
	_args = (args.duplicate(true) if not args.is_empty() else {})


## The active route name ("" until a named navigation happens).
static func route_name() -> String:
	return _route_name