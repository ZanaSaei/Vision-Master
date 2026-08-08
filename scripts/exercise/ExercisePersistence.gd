class_name ExercisePersistence
extends RefCounted

## Handles reading and writing to user://exercise_saves.json

const SAVE_PATH := "user://exercise_saves.json"

static func load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		return json.data
	return {}

static func save_all(saves: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saves))

static func save_open_ended(exercise_id: String, items: Array[ExerciseData.Item]) -> void:
	if exercise_id == "": return
	var saves := load_all()
	if not saves.has(exercise_id):
		saves[exercise_id] = {}
		
	for i in items.size():
		var item := items[i]
		if item.text_edit != null and is_instance_valid(item.text_edit):
			saves[exercise_id][str(i)] = item.text_edit.text
			
	save_all(saves)

static func load_open_ended(exercise_id: String, items: Array[ExerciseData.Item]) -> void:
	if exercise_id == "": return
	var saves := load_all()
	if not saves.has(exercise_id): return
	
	var ex_saves: Dictionary = saves[exercise_id]
	for i in items.size():
		var item := items[i]
		if item.text_edit != null and is_instance_valid(item.text_edit):
			var key := str(i)
			if ex_saves.has(key):
				item.text_edit.text = str(ex_saves[key])
