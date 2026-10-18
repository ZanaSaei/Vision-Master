class_name JalaliCalendar
extends RefCounted

## Port of the well-established Borkowski/Jalaali-JS conversion algorithm.
## Dates for official challenges still remain canonical Gregorian ISO keys;
## this helper is presentation-only and never reads the device clock.

const BREAKS: Array[int] = [-61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178]

static func _div(a: int, b: int) -> int:
	@warning_ignore("integer_division")
	return a / b

static func _mod(a: int, b: int) -> int:
	return a - _div(a, b) * b

static func _jal_cal(jy: int) -> Dictionary:
	var gy: int = jy + 621
	var leap_j: int = -14
	var jp: int = BREAKS[0]
	var jump: int = 0
	var n: int = 0
	if jy < BREAKS[0] or jy >= BREAKS[BREAKS.size() - 1]:
		return {}
	for i: int in range(1, BREAKS.size()):
		var jm: int = BREAKS[i]
		jump = jm - jp
		if jy < jm:
			break
		leap_j += _div(jump, 33) * 8 + _div(_mod(jump, 33), 4)
		jp = jm
	n = jy - jp
	leap_j += _div(n, 33) * 8 + _div(_mod(n, 33) + 3, 4)
	if _mod(jump, 33) == 4 and jump - n == 4:
		leap_j += 1
	var leap_g: int = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150
	var march: int = 20 + leap_j - leap_g
	if jump - n < 6:
		n = n - jump + _div(jump + 4, 33) * 33
	var leap: int = _mod(_mod(n + 1, 33) - 1, 4)
	if leap == -1:
		leap = 4
	return {"leap": leap, "gy": gy, "march": march}

static func _g2d(gy: int, gm: int, gd: int) -> int:
	var d: int = _div((gy + _div(gm - 8, 6) + 100100) * 1461, 4) + _div(153 * _mod(gm + 9, 12) + 2, 5) + gd - 34840408
	d = d - _div(_div(gy + 100100 + _div(gm - 8, 6), 100) * 3, 4) + 752
	return d

static func _d2g(jdn: int) -> Dictionary:
	var j: int = 4 * jdn + 139361631
	j += _div(_div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908
	var i: int = _div(_mod(j, 1461), 4) * 5 + 308
	var gd: int = _div(_mod(i, 153), 5) + 1
	var gm: int = _mod(_div(i, 153), 12) + 1
	var gy: int = _div(j, 1461) - 100100 + _div(8 - gm, 6)
	return {"year": gy, "month": gm, "day": gd}

static func _j2d(jy: int, jm: int, jd: int) -> int:
	var r: Dictionary = _jal_cal(jy)
	if r.is_empty():
		return 0
	return _g2d(int(r.gy), 3, int(r.march)) + (jm - 1) * 31 - _div(jm, 7) * (jm - 7) + jd - 1

static func _d2j(jdn: int) -> Dictionary:
	var gy: int = int(_d2g(jdn).year)
	var jy: int = gy - 621
	var r: Dictionary = _jal_cal(jy)
	if r.is_empty():
		return {}
	var jdn1f: int = _g2d(gy, 3, int(r.march))
	var k: int = jdn - jdn1f
	if k >= 0:
		if k <= 185:
			return {"year": jy, "month": 1 + _div(k, 31), "day": _mod(k, 31) + 1}
		k -= 186
	else:
		jy -= 1
		k += 179
		if int(r.leap) == 1:
			k += 1
	return {"year": jy, "month": 7 + _div(k, 30), "day": _mod(k, 30) + 1}

static func from_gregorian(year: int, month: int, day: int) -> Dictionary:
	return _d2j(_g2d(year, month, day))

static func to_gregorian(year: int, month: int, day: int) -> Dictionary:
	return _d2g(_j2d(year, month, day))

static func month_length(year: int, month: int) -> int:
	if month <= 6:
		return 31
	if month <= 11:
		return 30
	var leap_info: Dictionary = _jal_cal(year)
	return 30 if not leap_info.is_empty() and int(leap_info.leap) == 0 else 29

static func iso_key(year: int, month: int, day: int) -> String:
	var g: Dictionary = to_gregorian(year, month, day)
	return "%04d-%02d-%02d" % [int(g.get("year", 0)), int(g.get("month", 0)), int(g.get("day", 0))]

static func iso_to_jalali(date_key: String) -> Dictionary:
	var parts: PackedStringArray = date_key.split("-")
	if parts.size() != 3:
		return {}
	return from_gregorian(int(parts[0]), int(parts[1]), int(parts[2]))

static func persian_digits(value: String) -> String:
	var output: String = ""
	for character: String in value:
		var code: int = character.unicode_at(0)
		output += char(code + 1728) if code >= 48 and code <= 57 else character
	return output

static func month_name(month: int) -> String:
	var names: Array[String] = ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]
	return names[month - 1] if month >= 1 and month <= 12 else "ماه"