class_name ScrambledWordController
extends RefCounted
## ============================================================
##  SCRAMBLED WORD CONTROLLER — everything about ONE word of a session.
##
##  Owns the answer, the scrambled starting arrangement and the checks the
##  board runs against them. It is deliberately free of any UI: the board
##  asks it for the letters and whether they are in order, which keeps the
##  trickiest rules testable on their own —
##
##    * a scramble never starts solved when the word allows a different
##      arrangement (a board that is already the answer is no puzzle),
##    * the same seed always produces the same scramble, so the daily
##      challenge deals every player an identical board,
##    * the "near miss" test behind the gentle you-are-almost-there nudge,
##      which never shows the answer.
## ============================================================

## How many shuffles to try before accepting the rare word whose every
## arrangement reads as the answer (a single repeated letter, say).
const SCRAMBLE_TRIES := 24

## The answer in its original spelling.
var word := ""
var meaning := ""
var meaning_fa := ""
var book := 1
var lesson := 1

## The answer, letter by letter, uppercased.
var target: Array = []
## The starting arrangement of the board, letter by letter.
var letters: Array = []
## The seed the current scramble came from (0 = freshly randomised).
var seed_value := 0


## Fills the controller from one word-bank entry and deals its scramble.
func setup(word_data: Dictionary, scramble_seed: int = 0) -> void:
	word = str(word_data.get("word", "")).strip_edges()
	meaning = str(word_data.get("meaning", "")).strip_edges()
	meaning_fa = str(word_data.get("meaning_fa", "")).strip_edges()
	book = int(word_data.get("book", book))
	lesson = int(word_data.get("lesson", lesson))
	target = []
	for ch in word.to_upper():
		target.append(ch)
	rescramble(scramble_seed)


## Rebuilds the starting arrangement. A seed of 0 randomises; any other value
## repeats exactly, which is what makes a daily puzzle comparable.
func rescramble(scramble_seed: int = 0) -> void:
	seed_value = scramble_seed
	letters = target.duplicate()
	if target.size() < 2:
		return

	var rng := RandomNumberGenerator.new()
	if scramble_seed == 0:
		rng.randomize()
	else:
		rng.seed = scramble_seed

	var answer := word.to_upper()
	for attempt in SCRAMBLE_TRIES:
		var candidate := target.duplicate()
		_shuffle(candidate, rng)
		if letters_to_text(candidate) != answer:
			letters = candidate
			return
	# Every arrangement reads as the answer (the word has next to no distinct
	# letters): keep the original order and let the player have an easy win.


func letter_count() -> int:
	return target.size()


## The answer as text, for the moment the word is finally shown.
func solution() -> String:
	return word.to_upper()


## True when the letters currently on the board spell the word.
func is_solved(current: Array) -> bool:
	if current.size() != target.size():
		return false
	for i in target.size():
		if str(current[i]).to_upper() != target[i]:
			return false
	return true


## Positions whose letter does not match the answer yet.
func misplaced(current: Array) -> Array:
	var out: Array = []
	for i in mini(target.size(), current.size()):
		if str(current[i]).to_upper() != target[i]:
			out.append(i)
	return out


## True when only one or two positions are wrong: the point where a gentle
## "nearly there" nudge helps instead of giving the answer away.
func is_near_miss(current: Array) -> bool:
	var wrong := misplaced(current)
	return wrong.size() >= 1 and wrong.size() <= 2


## -------------------------------------------------------------- helpers --
static func letters_to_text(letters_in: Array) -> String:
	var out := ""
	for ch in letters_in:
		out += str(ch)
	return out


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held = list[i]
		list[i] = list[j]
		list[j] = held
