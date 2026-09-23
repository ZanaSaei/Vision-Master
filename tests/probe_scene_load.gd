extends Node
## ============================================================
##  SCENE LOAD PROBE — diagnostic utility (not part of the test suite).
##
##  Loads every app scene while printing a marker to STDERR before each load,
##  so the engine's own load-time diagnostics interleave with the markers in
##  the captured stderr and you can see exactly WHICH scene produced a warning.
##
##  Run it when a scene-related warning appears without a file name:
##    godot --path <project> res://tests/ProbeSceneLoad.tscn --quit-after 600
##  then read stderr. A healthy project prints only PROBE_* lines.
##
##  It exists because TestSceneTheming can assert THAT the scenes are clean but
##  cannot name the culprit — stderr interleaving is what pins it down.
## ============================================================

func _ready() -> void:
	var paths := _collect("res://scenes")
	paths.sort()
	printerr("PROBE_BEGIN scenes=", paths.size())
	for path in paths:
		printerr("PROBE_LOAD ", path)
		var packed = load(path)
		if packed == null:
			printerr("PROBE_NULL ", path)
	printerr("PROBE_END")


func _collect(dir: String) -> Array:
	var out: Array = []
	var handle := DirAccess.open(dir)
	if handle == null:
		return out
	handle.list_dir_begin()
	var entry := handle.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = handle.get_next()
			continue
		var full := dir.path_join(entry)
		if handle.current_is_dir():
			out.append_array(_collect(full))
		elif entry.ends_with(".tscn") and not entry.to_lower().contains("test"):
			out.append(full)
		entry = handle.get_next()
	handle.list_dir_end()
	return out
