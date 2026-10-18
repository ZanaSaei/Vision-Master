extends Node
class_name JalaliCalendarTests

const CALENDAR: Script = preload("res://scenes/word_game/jalali_calendar.gd")

func test_converts_nowruz_and_round_trips() -> void:
	var converted: Dictionary = CALENDAR.from_gregorian(2026, 3, 21)
	_check(int(converted.get("year", 0)) == 1405, "Nowruz maps to Jalali 1405")
	_check(int(converted.get("month", 0)) == 1 and int(converted.get("day", 0)) == 1, "Nowruz maps to Farvardin 1")
	var gregorian: Dictionary = CALENDAR.to_gregorian(1405, 1, 1)
	_check(int(gregorian.get("year", 0)) == 2026, "Jalali conversion round-trips year")
	_check(int(gregorian.get("month", 0)) == 3 and int(gregorian.get("day", 0)) == 21, "Jalali conversion round-trips day")
	_check(CALENDAR.iso_key(1405, 1, 1) == "2026-03-21", "Canonical Gregorian key is generated")
	_check(CALENDAR.persian_digits("1405-01-01") == "۱۴۰۵-۰۱-۰۱", "Digits localize for display")
	_check(CALENDAR.month_length(1404, 12) == 29, "Esfand length uses leap-year data")

func _check(condition: bool, label: String) -> void:
	assert(condition, label)
	print("PASS  " + label)

