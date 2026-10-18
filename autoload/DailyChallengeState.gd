extends Node

## Cross-scene state for official daily challenges. The selected date is
## persisted as a canonical Gregorian key; no local date is calculated here.
static var selected_date: String = ""
static var selected_game: String = ""
static var current_attempt_id: String = ""
static var current_attempt_counted: bool = true
static var current_attempt_started_at: String = ""
static var current_public_content: Dictionary = {}
static var current_attempt_state: Dictionary = {}
static var current_attempt_status: String = ""

const STATE_PATH: String = "user://daily_challenge_state.cfg"

static func set_selected_date(date_key: String) -> void:
	selected_date = date_key
	var config: ConfigFile = ConfigFile.new()
	config.load(STATE_PATH)
	config.set_value("challenge", "selected_date", date_key)
	config.save(STATE_PATH)

static func load_selected_date() -> String:
	if selected_date != "":
		return selected_date
	var config: ConfigFile = ConfigFile.new()
	if config.load(STATE_PATH) == OK:
		selected_date = str(config.get_value("challenge", "selected_date", ""))
	return selected_date

static func begin_attempt(game_type: String, attempt_id: String, counted: bool, public_content: Dictionary, started_at: String = "", attempt_state: Dictionary = {}, attempt_status: String = "in_progress") -> void:
	selected_game = game_type
	current_attempt_id = attempt_id
	current_attempt_counted = counted
	current_attempt_started_at = started_at
	current_public_content = public_content.duplicate(true)
	current_attempt_state = attempt_state.duplicate(true)
	current_attempt_status = attempt_status

static func clear_attempt() -> void:
	current_attempt_id = ""
	selected_game = ""
	current_attempt_started_at = ""
	current_public_content.clear()
	current_attempt_state.clear()
	current_attempt_status = ""
	current_attempt_counted = true
