extends Node
# ============================================================
#  SFX — autoload singleton for short UI sound effects.
#  Files live in res://assets/audio/ui/.
#  Call anywhere as: Sfx.click(), Sfx.correct(), Sfx.wrong(),
#  Sfx.complete(), Sfx.reward(), or Sfx.play("file.wav").
#
#  Registered as the "Sfx" autoload in project.godot.
#  Uses a small pool of AudioStreamPlayers so overlapping
#  sounds don't cut each other off.
# ============================================================

const DIR := "res://assets/audio/ui/"
const MAX_PLAYERS := 8   # cap the pool so it can never grow unbounded

var _players: Array[AudioStreamPlayer] = []


func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	if _players.size() >= MAX_PLAYERS:
		# Reuse the oldest player instead of growing the pool forever.
		return _players[0]
	var player := AudioStreamPlayer.new()
	add_child(player)
	_players.append(player)
	return player


func play(sfx_name: String) -> void:
	if sfx_name.is_empty():
		return
	if not Global.sound_enabled:
		return
	var path := DIR + sfx_name
	if not ResourceLoader.exists(path):
		push_warning("SFX not found: " + path)
		return
	var player := _get_player()
	player.stream = load(path)
	# Guard so the headless test runner (node not yet in the tree)
	# doesn't emit a playback error.
	if player.is_inside_tree():
		player.play()


func click() -> void:
	play("button_click.wav")


func correct() -> void:
	play("correct.wav")


func wrong() -> void:
	play("wrong.mp3")


func complete() -> void:
	play("complete.wav")


func reward() -> void:
	play("reward.wav")