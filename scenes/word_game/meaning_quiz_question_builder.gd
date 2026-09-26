class_name MeaningQuizQuestionBuilder
extends RefCounted

const OPTION_COUNT := 4
const MODE_MEANING := "meaning"
const MODE_SYNONYM := "synonym"
const MODE_ANTONYM := "antonym"
const MODE_LABELS := {
	MODE_MEANING: "معنی",
	MODE_SYNONYM: "مترادف",
	MODE_ANTONYM: "متضاد",
}


static func build_questions(words: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var answer_terms: Dictionary = {}
	var word_terms: Dictionary = {}
	var definition_by_word: Dictionary = {}
	var synonyms_by_word: Dictionary = {}
	var antonyms_by_word: Dictionary = {}
	for entry: Dictionary in words:
		var word: String = _clean(str(entry.get("word", "")))
		var definition: String = _clean(str(entry.get("meaning_en", "")))
		if word.is_empty() or definition.is_empty():
			continue
		word_terms[word.to_lower()] = word
		definition_by_word[word.to_lower()] = definition
		var synonyms: Array[String] = _terms(entry.get("synonyms", {}), "en")
		var antonyms: Array[String] = _terms(entry.get("antonyms", {}), "en")
		synonyms_by_word[word.to_lower()] = synonyms
		antonyms_by_word[word.to_lower()] = antonyms
		if synonyms.size() > 0:
			answer_terms[MODE_SYNONYM] = answer_terms.get(MODE_SYNONYM, [])
			for term: String in synonyms:
				_add_unique(answer_terms[MODE_SYNONYM], term)
		if antonyms.size() > 0:
			answer_terms[MODE_ANTONYM] = answer_terms.get(MODE_ANTONYM, [])
			for term: String in antonyms:
				_add_unique(answer_terms[MODE_ANTONYM], term)
		_add_unique(answer_terms.get_or_add(MODE_MEANING, []), definition)

	for entry: Dictionary in words:
		var word: String = _clean(str(entry.get("word", "")))
		var meaning: String = _clean(str(entry.get("meaning_en", "")))
		if word.is_empty() or meaning.is_empty():
			continue
		var options: Array[Dictionary] = []
		var synonyms: Array[String] = _without_word(_terms(entry.get("synonyms", {}), "en"), word)
		var antonyms: Array[String] = _without_word(_terms(entry.get("antonyms", {}), "en"), word)
		if not synonyms.is_empty():
			options.append(_question(MODE_SYNONYM, word, synonyms[0], entry, answer_terms, word_terms, definition_by_word, synonyms_by_word, antonyms_by_word))
		if not antonyms.is_empty():
			options.append(_question(MODE_ANTONYM, word, antonyms[0], entry, answer_terms, word_terms, definition_by_word, synonyms_by_word, antonyms_by_word))
		options.append(_question(MODE_MEANING, word, meaning, entry, answer_terms, word_terms, definition_by_word, synonyms_by_word, antonyms_by_word))
		for question: Dictionary in options:
			if question.get("options", []).size() == OPTION_COUNT:
				records.append(question)
	return records


static func _question(kind: String, word: String, answer: String,
		entry: Dictionary, answer_terms: Dictionary, word_terms: Dictionary,
		definition_by_word: Dictionary, synonyms_by_word: Dictionary,
		antonyms_by_word: Dictionary) -> Dictionary:
	var pool: Array = answer_terms.get(kind, [])
	var correct_word: String = word.to_lower()
	if kind == MODE_SYNONYM:
		pool = []
		for other_word: Variant in synonyms_by_word.keys():
			if str(other_word) != correct_word:
				pool.append_array(synonyms_by_word[other_word])
	elif kind == MODE_ANTONYM:
		pool = []
		for other_word: Variant in antonyms_by_word.keys():
			if str(other_word) != correct_word:
				pool.append_array(antonyms_by_word[other_word])
	else:
		pool = definition_by_word.values()
	if kind == MODE_MEANING and pool.size() < OPTION_COUNT:
		return {}
	if pool.size() < OPTION_COUNT:
		pool = definition_by_word.values()
	var result: Array[String] = [answer]
	var attempts: int = 0
	while result.size() < OPTION_COUNT and attempts < 200:
		attempts += 1
		if pool.is_empty():
			break
		var candidate: String = str(pool[randi_range(0, pool.size() - 1)])
		if candidate.to_lower() == answer.to_lower() or candidate.to_lower() == word.to_lower():
			continue
		_add_unique(result, candidate)
	if result.size() < OPTION_COUNT:
		var words: Array = word_terms.values()
		attempts = 0
		while result.size() < OPTION_COUNT and attempts < 200:
			attempts += 1
			if words.is_empty():
				break
			var candidate: String = str(words[randi_range(0, words.size() - 1)])
			if candidate.to_lower() != word.to_lower() and candidate.to_lower() != answer.to_lower():
				_add_unique(result, candidate)
	if result.size() < OPTION_COUNT:
		return {}
	result.shuffle()
	return {
		"kind": kind,
		"kind_label": str(MODE_LABELS.get(kind, "معنی")),
		"word": word,
		"prompt": answer,
		"answer": answer,
		"options": result,
		"meaning_fa": str(entry.get("meaning_fa", "")),
	}


static func _without_word(terms: Array[String], word: String) -> Array[String]:
	var result: Array[String] = []
	for term: String in terms:
		if term.to_lower() != word.to_lower():
			_add_unique(result, term)
	return result


static func _related_terms(raw_value: Variant, word: String) -> Array[String]:
	var result: Array[String] = []
	if not raw_value is Dictionary:
		return result
	for key: String in ["en", "fa"]:
		var terms: Array[String] = _terms(raw_value, key)
		for term: String in terms:
			if term.to_lower() != word.to_lower():
				_add_unique(result, term)
	return result


static func _terms(raw_value: Variant, language: String) -> Array[String]:
	var result: Array[String] = []
	if not raw_value is Dictionary:
		return result
	var list: Variant = raw_value.get(language, [])
	if not list is Array:
		return result
	for value: Variant in list:
		var term: String = _clean(str(value))
		if not term.is_empty():
			_add_unique(result, term)
	return result


static func _add_unique(list: Array, value: String) -> void:
	var normalized: String = value.strip_edges().to_lower()
	for existing: Variant in list:
		if str(existing).strip_edges().to_lower() == normalized:
			return
	list.append(value.strip_edges())


static func _clean(value: String) -> String:
	var result: String = value.strip_edges()
	while result.ends_with(".") or result.ends_with("!") or result.ends_with("?"):
		result = result.left(result.length() - 1).strip_edges()
	return result
