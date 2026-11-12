extends Control
class_name DailyChallengeDemo

## Interactive Demo & Test Scene for Vision Master's Daily Challenge.
## Simulates an authenticated user with internet connection and active session,
## loads the redesigned DailyWordGame scene, and provides test toolbar actions.

const DAILY_SCENE_PATH: String = "res://scenes/word_game/DailyWordGame.tscn"
const HUB_SCENE: String = "res://scenes/word_game/WordGameHub.tscn"
const DailyChallengeStateStore = preload("res://autoload/DailyChallengeState.gd")
const DailyChallengeMockHelper = preload("res://scenes/word_game/daily_challenge_mock.gd")

const GAME_SCENES: Dictionary = {
	"wordle": "res://scenes/word_game/WordOfDay.tscn",
	"wordef": "res://scenes/word_game/MeaningGame.tscn",
	"unscramble": "res://scenes/word_game/SpellingGame.tscn"
}

@onready var _scene_container: Control = $SceneContainer
@onready var _toolbar_panel: PanelContainer = $FloatingToolbar/Panel
@onready var _toggle_toolbar_btn: Button = $FloatingToolbar/ToggleBtn
@onready var _btn_online: Button = $FloatingToolbar/Panel/Margin/VBox/Row1/OnlineBtn
@onready var _btn_offline: Button = $FloatingToolbar/Panel/Margin/VBox/Row1/OfflineBtn
@onready var _btn_reset_today: Button = $FloatingToolbar/Panel/Margin/VBox/Row1/ResetBtn
@onready var _btn_play_wordle: Button = $FloatingToolbar/Panel/Margin/VBox/Row2/PlayWordleBtn
@onready var _btn_play_wordef: Button = $FloatingToolbar/Panel/Margin/VBox/Row2/PlayWordefBtn
@onready var _btn_play_unscramble: Button = $FloatingToolbar/Panel/Margin/VBox/Row2/PlayUnscrambleBtn
@onready var _btn_back_hub: Button = $FloatingToolbar/Panel/Margin/VBox/Row2/BackHubBtn

var _active_daily_view: Node = null

func _ready() -> void:
	# Configure demo environment
	DailyChallengeStateStore.return_scene = scene_file_path
	DailyChallengeMockHelper.enable_mock()
	
	_setup_toolbar_styling()
	_connect_toolbar_events()
	_load_daily_scene()

func _setup_toolbar_styling() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.set_corner_radius_all(18)
	panel_style.bg_color = Color(0.12, 0.14, 0.18, 0.94)
	panel_style.border_color = Color(0.95, 0.72, 0.15, 0.7)
	panel_style.set_border_width_all(2)
	panel_style.shadow_size = 12
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	_toolbar_panel.add_theme_stylebox_override("panel", panel_style)
	
	var toggle_style: StyleBoxFlat = StyleBoxFlat.new()
	toggle_style.set_corner_radius_all(14)
	toggle_style.bg_color = Color(0.18, 0.22, 0.28, 0.95)
	toggle_style.border_color = Color(0.95, 0.72, 0.15, 0.9)
	toggle_style.set_border_width_all(2)
	_toggle_toolbar_btn.add_theme_stylebox_override("normal", toggle_style)
	_toggle_toolbar_btn.add_theme_stylebox_override("hover", toggle_style)
	_toggle_toolbar_btn.add_theme_stylebox_override("pressed", toggle_style)

func _connect_toolbar_events() -> void:
	_toggle_toolbar_btn.pressed.connect(func() -> void:
		_toolbar_panel.visible = not _toolbar_panel.visible
		_toggle_toolbar_btn.text = "🛠️ ابزارهای تست و دمو (بستن)" if _toolbar_panel.visible else "🛠️ ابزارهای تست و دمو (باز کردن)"
	)
	
	_btn_online.pressed.connect(_on_set_online)
	_btn_offline.pressed.connect(_on_set_offline)
	_btn_reset_today.pressed.connect(_on_reset_today)
	_btn_play_wordle.pressed.connect(_on_quick_play.bind("wordle"))
	_btn_play_wordef.pressed.connect(_on_quick_play.bind("wordef"))
	_btn_play_unscramble.pressed.connect(_on_quick_play.bind("unscramble"))
	_btn_back_hub.pressed.connect(_on_back_to_hub)

func _load_daily_scene() -> void:
	if _active_daily_view != null:
		_scene_container.remove_child(_active_daily_view)
		_active_daily_view.queue_free()
		_active_daily_view = null
	
	var scene_res: PackedScene = load(DAILY_SCENE_PATH)
	if scene_res != null:
		_active_daily_view = scene_res.instantiate()
		_scene_container.add_child(_active_daily_view)

func _on_set_online() -> void:
	DailyChallengeMockHelper.enable_mock()
	_load_daily_scene()

func _on_set_offline() -> void:
	DailyChallengeMockHelper.disable_mock()
	_load_daily_scene()

func _on_reset_today() -> void:
	if FileAccess.file_exists("user://wordle_save.json"):
		DirAccess.remove_absolute("user://wordle_save.json")
	DailyChallengeMockHelper.reset_today()
	_load_daily_scene()

func _on_quick_play(game_type: String) -> void:
	DailyChallengeMockHelper.enable_mock()
	var today_date: String = "2026-11-12"
	DailyChallengeStateStore.return_scene = scene_file_path
	DailyChallengeStateStore.set_selected_date(today_date)
	DailyChallengeStateStore.selected_game = game_type
	
	API.start_challenge_attempt(today_date, game_type, "", func(ok: bool, data: Dictionary) -> void:
		if ok:
			var attempt: Dictionary = data.get("attempt", {})
			var reserved_id: String = str(attempt.get("id", ""))
			DailyChallengeStateStore.begin_attempt(
				game_type,
				reserved_id,
				true,
				data.get("publicContent", {}),
				str(attempt.get("startedAt", "")),
				attempt.get("state", {}),
				str(attempt.get("status", "in_progress"))
			)
		var dest_scene: String = GAME_SCENES.get(game_type, "")
		if dest_scene != "":
			TransitionManager.change_scene(dest_scene)
	)

func _on_back_to_hub() -> void:
	TransitionManager.change_scene(HUB_SCENE)
