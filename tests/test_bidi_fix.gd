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
	# Latin run must now be wrapped in LRI (0x2066) ... PDI (0x2069).
	assert(out.contains(char(0x2066) + "will" + char(0x2069)))
	assert(out.contains(char(0x2066) + "not" + char(0x2069)))


func test_fa_dominant_multichar_run_kept_together() -> void:
	var s := "ساختار درست: be going to اول می‌آید"
	var out := GrammarTheme.bidi_fix(s)
	assert(out.contains(char(0x2066) + "be going to" + char(0x2069)))


func test_latin_dominant_unchanged() -> void:
	var s := "This book is as interesting as that one. (جالب)"
	assert(GrammarTheme.bidi_fix(s) == s)


func test_empty_unchanged() -> void:
	assert(GrammarTheme.bidi_fix("") == "")
