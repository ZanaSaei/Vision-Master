# ============================================================
# ExerciseEngine - UI chrome localization strings.
# Part of the split ExerciseEngine module (see the leaf file
# ExerciseEngine.gd in this folder for the layout map).
# ============================================================
class_name ExerciseStrings

const UI_STRINGS := {
	"info_prefix":              { "en": "Info: ",                                              "fa": "نکته: " },
	"image_placeholder":        { "en": "Image placeholder",                                    "fa": "تصویر در دسترس نیست" },
	"image_not_found_prefix":   { "en": "Image not found: ",                                    "fa": "تصویر پیدا نشد: " },
	"show_sample_answer":       { "en": "Show Sample Answer",                                   "fa": "نمایش پاسخ نمونه" },
	"hide_sample_answer":       { "en": "Hide Sample Answer",                                   "fa": "پنهان کردن پاسخ نمونه" },
	"save":                     { "en": "Save",                                                 "fa": "ذخیره" },
	"saved":                    { "en": "Saved",                                                 "fa": "ذخیره شد" },
	"check_answer":             { "en": "Check Answer",                                          "fa": "بررسی پاسخ" },
	"try_again":                { "en": "Try Again",                                             "fa": "تلاش دوباره" },
	"type_your_answer":         { "en": "Type your answer...",                                   "fa": "پاسخ خود را بنویسید..." },
	"write_your_answer":        { "en": "Write your answer here...",                             "fa": "پاسخ خود را اینجا بنویسید..." },
	"self_check_label":         { "en": "I practiced this aloud / I completed this.",            "fa": "این تمرین را با صدای بلند انجام دادم / آن را کامل کردم." },
	"sample_answer_prefix":     { "en": "Sample answer: ",                                       "fa": "پاسخ نمونه: " },
	"choose_a_word":            { "en": "Choose a word",                                         "fa": "یک کلمه را انتخاب کنید" },
	"choose":                   { "en": "Choose",                                                "fa": "انتخاب کنید" },
	"no_correct_words":         { "en": "No correct words were defined for this exercise.",      "fa": "کلمهٔ درستی برای این تمرین تعریف نشده است." },
	"all_correct_words":        { "en": "Excellent! All correct words chosen!",                  "fa": "عالی! همهٔ کلمات درست را انتخاب کردی!" },
	"chose_correct_and_wrong":  { "en": "You chose %d/%d correct words and %d wrong words.",     "fa": "%d از %d کلمهٔ درست را انتخاب کردی و %d کلمهٔ اشتباه." },
	"chose_correct":            { "en": "You chose %d/%d correct words.",                        "fa": "%d از %d کلمهٔ درست را انتخاب کردی." },
	"empty":                    { "en": "Empty",                                                 "fa": "خالی" },
	"correct":                  { "en": "Correct!",                                              "fa": "درست است!" },
	"correct_answer_prefix":    { "en": "Correct answer: ",                                      "fa": "پاسخ درست: " },
	"excellent_score":          { "en": "Excellent! %d/%d correct!",                              "fa": "عالی! %d از %d درست بود!" },
	"got_score":                { "en": "You got %d/%d.",                                         "fa": "%d از %d درست بود." },
}

# Static helpers. The engine's _t/_t_fa/_apply_fa_meta wrappers
# (in ExerciseEngineCore) delegate to these.
static func t(key: String, locale: String) -> String:
	var entry: Dictionary = UI_STRINGS.get(key, {})
	return str(entry.get(locale, entry.get("en", key)))

static func t_fa(key: String) -> String:
	var entry: Dictionary = UI_STRINGS.get(key, {})
	return str(entry.get("fa", entry.get("en", key)))

static func apply_fa_meta(ctrl: Object, key: String) -> void:
	if ctrl == null:
		return
	var entry: Dictionary = UI_STRINGS.get(key, {})
	if entry.has("fa"):
		ctrl.set_meta("text_fa", str(entry["fa"]))