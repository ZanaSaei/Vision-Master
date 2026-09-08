# ============================================================
#  convert_grammar_schema.py
#  Converts old-schema grammar files (units -> pages ->
#  learning/question) into the new "group units + activities"
#  schema used by vision1_lesson2.json / vision1_lesson3.json.
# ============================================================
import json, os, sys

BASE = os.path.join(os.path.dirname(__file__), "..", "data", "grammar")

SLUGS = {
    "vision1_lesson4.json": "modals",
    "vision2_lesson1.json": "countable_uncountable_nouns",
    "vision2_lesson2.json": "present_perfect",
    "vision2_lesson3.json": "conditional_type_i",
}
META = {
    "vision1_lesson4.json": ("Vision 1", 1, 4, "Modals", "افعال کمکی وجهی (مدال‌ها)", "🌍", "#10B981"),
    "vision2_lesson1.json": ("Vision 2", 2, 1, "Countable and Uncountable Nouns", "اسم‌های قابل‌شمارش و غیرقابل‌شمارش", "👥", "#0EA5E9"),
    "vision2_lesson2.json": ("Vision 2", 2, 2, "Present Perfect", "حال کامل", "🍏", "#22C55E"),
    "vision2_lesson3.json": ("Vision 2", 2, 3, "Conditional Type I", "جمله شرطی نوع اول", "🎭", "#A855F7"),
}


def convert_page(page):
    pid = page["page_id"]
    ptype = page.get("type")
    if ptype == "learning":
        lrn = page.get("learning", {})
        act = {
            "id": pid,
            "type": "learn",
            "title_fa": lrn.get("title_fa", ""),
            "title_en": "",
            "explanation": lrn.get("explanation_fa", ""),
            "cards": lrn.get("examples", []),
        }
        hw = lrn.get("highlight_word")
        if hw:
            act["highlight_word"] = hw
        return act

    q = page.get("q", {})
    qt = q.get("type")
    hint = q.get("fa_hint", "")
    if qt == "multiple_choice":
        return {
            "id": pid,
            "type": "multiple_choice",
            "title_fa": "",
            "title_en": "",
            "instruction_fa": q.get("prompt_fa", ""),
            "questions": [{
                "question": q.get("prompt_fa", ""),
                "options": q.get("options", []),
                "correct": q.get("correct_index", 0),
                "hint_fa": hint,
                "explanation_fa": hint,
            }],
        }
    if qt == "fill_missing":
        tokens = q.get("correct_tokens", [])
        answers = [" ".join(tokens)] if len(tokens) > 1 else tokens
        return {
            "id": pid,
            "type": "fill_blank",
            "title_fa": "",
            "title_en": "",
            "instruction_fa": q.get("prompt_fa", ""),
            "items": [{
                "text": q.get("sentence_template", ""),
                "answers": answers,
                "hint_fa": hint,
                "explanation_fa": hint,
            }],
        }
    if qt == "true_false":
        return {
            "id": pid,
            "type": "true_false",
            "title_fa": "",
            "title_en": "",
            "instruction_fa": "درست یا غلط",
            "items": [{
                "statement": q.get("statement", ""),
                "answer": q.get("correct_answer", False),
                "hint_fa": hint,
                "explanation_fa": hint,
            }],
        }
    if qt == "matching":
        items = [{"left": l, "right": r} for l, r in q.get("pairs", [])]
        act = {
            "id": pid,
            "type": "matching",
            "title_fa": "",
            "title_en": "",
            "instruction_fa": q.get("prompt_fa", ""),
            "items": items,
        }
        if hint:
            act["hint_fa"] = hint
        return act
    if qt == "unscramble":
        return {
            "id": pid,
            "type": "unscramble",
            "title_fa": "",
            "title_en": "",
            "instruction_fa": q.get("prompt_fa", ""),
            "items": [{
                "words": q.get("words", []),
                "answer": q.get("answer", ""),
                "hint_fa": hint,
            }],
        }
    raise ValueError("Unknown q type %r in page %s" % (qt, pid))


def convert(path):
    fname = os.path.basename(path)
    book, booknum, lessonnum, ten, tfa, icon, color = META[fname]
    with open(path, encoding="utf-8") as f:
        old = json.load(f)

    units = []
    for u in old["units"]:
        acts = [convert_page(p) for p in u["pages"]]
        units.append({
            "activities": acts,
            "activity_count": len(acts),
            "id": u["unit_id"],
            "title_en": "",
            "title_fa": u["unit_title_fa"],
            "type": "group",
        })

    lesson = {
        "_group_note": "Each source unit becomes a 'group' unit whose 'activities' are its pages converted to learn/exercise activities. GrammarLesson plays them in sequence.",
        "book": book,
        "icon": icon,
        "id": "vision%d_lesson%d_%s" % (booknum, lessonnum, SLUGS[fname]),
        "lesson_number": lessonnum,
        "source": old.get("source", ""),
        "theme_color": color,
        "title_en": ten,
        "title_fa": tfa,
        "units": units,
        "xp_per_unit": 10,
    }
    return {"lesson": lesson}


def main():
    for fname in SLUGS:
        path = os.path.join(BASE, fname)
        result = convert(path)
        n_units = len(result["lesson"]["units"])
        n_acts = sum(u["activity_count"] for u in result["lesson"]["units"])
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(result, f, ensure_ascii=False, indent="\t")
            f.write("\n")
        print("Converted %s: %d units, %d activities" % (fname, n_units, n_acts))


if __name__ == "__main__":
    main()
