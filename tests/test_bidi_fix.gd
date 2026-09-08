extends Node
# Tests for GrammarTheme.bidi_fix (mixed Persian/English bidi isolates).


func test_pure_persian_unchanged() -> void:
	var s := "من به تو کمک خواهم کرد."
	assert(GrammarTheme.bidi_fix(s) == s)


func test_pure_english_unchanged() -> void:
	var s := "Subject + will + base verb"
	assert(GrammarTheme.bidi_fix(s) == s)


func test_fa_dominant_gets_isolates() -> void:
	var s := "ساختار: فاعل + will + not + فعل ساده"
	var out := GrammarTheme.bidi_fix(s)
	# The whole English segment "will + not" is ONE LRI..PDI island;
	# bare connectors touching Persian stay outside it.
	assert(out.contains(char(0x2066) + "will + not" + char(0x2069)))


func test_fa_dominant_multichar_run_kept_together() -> void:
	var s := "ساختار درست: be going to اول می‌آید"
	var out := GrammarTheme.bidi_fix(s)
	assert(out.contains(char(0x2066) + "be going to" + char(0x2069)))


func test_latin_dominant_unchanged() -> void:
	var s := "This book is as interesting as that one. (جالب)"
	assert(GrammarTheme.bidi_fix(s) == s)


func test_empty_unchanged() -> void:
	assert(GrammarTheme.bidi_fix("") == "")


func test_multiword_english_phrase_kept_together() -> void:
	# Regression: "May I ....?" used to be scrambled into "?.... I May"
	# because each word got its own isolate and the neutral gaps between
	# them resolved to the RTL paragraph direction.
	var s := "May I ....? برای اجازه گرفتن به کار می رود."
	var out := GrammarTheme.bidi_fix(s)
	assert(out.contains(char(0x2066) + "May I ....?" + char(0x2069)))
	assert(not out.contains(char(0x2066) + "May" + char(0x2069)))


func test_phrase_punctuation_stays_inside_island() -> void:
	var s := "برای پیش‌بینی: I think it will rain. (احتمال)"
	var out := GrammarTheme.bidi_fix(s)
	assert(out.contains(char(0x2066) + "I think it will rain." + char(0x2069)))


func test_leading_english_question() -> void:
	var s := "May I sit down? برای گرفتن اجازه."
	var out := GrammarTheme.bidi_fix(s)
	assert(out.contains(char(0x2066) + "May I sit down?" + char(0x2069)))
