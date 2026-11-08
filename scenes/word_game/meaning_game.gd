extends Control
# ============================================================
# بازی معنی — Meaning Game (host scene)
#
# The game itself lives in res://scenes/word_game/MeaningQuiz.tscn and is shown
# here as the MeaningQuiz instance below. This scene exists only to keep the
# hub's «بازی معنی» button path working: the game owns its own header bar and
# its own back navigation, so this host deliberately adds nothing on top and
# must NOT extend BackButtonHandler (that would handle the Android back twice).
# ============================================================
