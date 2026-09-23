class_name WordleEvaluator
extends RefCounted
## ============================================================
##  WORDLE EVALUATOR — guess vs. answer letter evaluation.
##
##  Score codes (per position):
##    Score.ABSENT  — letter not in the answer (gray)
##    Score.PRESENT — letter in the answer, wrong position (yellow)
##    Score.CORRECT — letter in the right position (green)
##
##  Repeated letters are handled exactly like original Wordle's
##  two-pass algorithm:
##    Pass 1 — every position where guess[i] == answer[i] is CORRECT,
##             and that answer letter is "consumed".
##    Pass 2 — remaining positions can only be PRESENT if an unconsumed
##             answer letter matches; each match consumes one.
##  E.g. answer LEVER, guess LEVEL ->
##    L  E  V  E  L
##    G  G  G  G  .  (first four exact; the trailing L is absent because
##                     the answer's single L was not left over)
## ============================================================

enum Score { ABSENT, PRESENT, CORRECT }


## Evaluates `guess` against `answer` (case-insensitive) and returns one
## Score per position of `guess`.
##
## A length mismatch is a caller bug — WordleGame only ever submits rows of
## the answer's length. Rather than indexing past the end of `answer` (which
## would crash the game screen mid-animation) the whole guess is reported
## ABSENT, i.e. "nothing matched".
static func evaluate(answer: String, guess: String) -> Array[int]:
	var answer_u := answer.to_upper()
	var guess_u := guess.to_upper()
	var length := guess_u.length()
	var result: Array[int] = []
	result.resize(length)
	if length == 0 or answer_u.length() != length:
		result.fill(Score.ABSENT)
		return result

	var remaining := {}  # unconsumed answer letters -> count

	# Pass 1: exact matches (green), consume the answer letter.
	for i in length:
		if guess_u[i] == answer_u[i]:
			result[i] = Score.CORRECT
		else:
			result[i] = Score.ABSENT
			var letter := answer_u[i]
			remaining[letter] = int(remaining.get(letter, 0)) + 1

	# Pass 2: misplaced matches (yellow), limited by remaining counts.
	for i in length:
		if result[i] == Score.CORRECT:
			continue
		var letter := guess_u[i]
		var left: int = int(remaining.get(letter, 0))
		if left > 0:
			result[i] = Score.PRESENT
			remaining[letter] = left - 1

	return result


## True when every position is CORRECT.
## An empty evaluation is NOT a win: nothing was guessed, so nothing was
## solved. (Without this guard a zero-length evaluation — which a stale or
## corrupt save could produce — counted as a solved puzzle.)
static func is_win(evaluation: Array) -> bool:
	if evaluation.is_empty():
		return false
	for code in evaluation:
		if code != Score.CORRECT:
			return false
	return true
