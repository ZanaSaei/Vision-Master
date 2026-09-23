extends Control
# ============================================================
# بازی املا — Spelling Game (host scene)
#
# The game itself lives in res://scenes/word_game/scrambled/ and is shown here
# as the ScrambledWords instance below. This scene exists only to keep the
# hub's «بازی املا» button path working: the game owns its own header bar and
# its own back navigation, so this host deliberately adds nothing on top and
# must NOT extend BackButtonHandler (that would handle the Android back twice).
#
# The script stays the scene root on purpose: it is listed in
# ThemeService.SELF_THEMED_SCRIPTS, so the app-wide theme walk skips the whole
# subtree and the game keeps its own candy-coloured styling.
# ============================================================
