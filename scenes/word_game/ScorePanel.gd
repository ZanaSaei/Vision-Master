extends PanelContainer
class_name ChallengeScorePanel

@onready var game_score_label: Label = $Padding/Rows/GameScore
@onready var lifetime_score_label: Label = $Padding/Rows/LifetimeScore

func set_scores(game_score: int, lifetime_score: int, game_name: String = "امتیاز این بازی") -> void:
	game_score_label.text = "%s: %s" % [game_name, MenuStyle.persian_digits(str(maxi(0, game_score)))]
	lifetime_score_label.text = "امتیاز کل: %s" % MenuStyle.persian_digits(str(maxi(0, lifetime_score)))
