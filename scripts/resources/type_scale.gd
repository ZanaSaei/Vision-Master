class_name TypeScale
extends Resource
## ============================================================
##  TYPE SCALE — the app's font sizes and families as a Resource.
##
##  Screens used to carry literals such as
##  `add_theme_font_size_override("font_size", 58)` in dozens of places, so a
##  typography change meant a hunt through the whole codebase. Every size the
##  UI uses now lives here and is read through the shared instance at
##  res://resources/typography/type_scale.tres, which a designer can retune in
##  the Inspector without touching a script.
##
##  Colour deliberately stays OUT of this resource: text colour is a theme
##  concern (Dark / Light), while size and family are not.
## ============================================================

# ── Latin family ───────────────────────────────────────────────
## Regular weight — body copy, paragraphs, list items.
@export var font_regular: FontFile
## Bold / display weight — titles, headings, emphasis.
@export var font_display: FontFile

# ── Persian family ────────────────────────────────────────────
## Persian text is set in Vazirmatn so RTL shaping is correct.
@export var font_farsi: FontFile

# ── Steps ─────────────────────────────────────────────────────
@export_group("Sizes")
## Hero number / score on a results screen.
@export_range(16, 160, 1) var hero: int = 92
## Screen title (page heading).
@export_range(16, 120, 1) var title: int = 62
## Section heading inside a page.
@export_range(12, 100, 1) var heading: int = 52
## Button / label text.
@export_range(12, 90, 1) var label: int = 38
## Default body text.
@export_range(12, 90, 1) var body: int = 34
## Secondary body text (captions under a heading).
@export_range(10, 80, 1) var small: int = 30
## Hint / badge text.
@export_range(8, 70, 1) var tiny: int = 26
## Long-form reading text (paragraph body, passages).
@export_range(12, 100, 1) var reading: int = 55
## Persian translation body text.
@export_range(12, 100, 1) var translation: int = 45

## Line height multiplier applied to reading text.
@export_range(1.0, 2.5, 0.05) var reading_line_spacing: float = 1.35


## The shared instance. All app UI should read sizes from this rather than
## carrying literals, so one edit in the Inspector retypes the whole app.
static func shared() -> TypeScale:
	return load("res://resources/typography/type_scale.tres") as TypeScale
