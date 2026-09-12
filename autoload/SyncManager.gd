extends Node
class_name SyncManager

# ============================================================
#  SYNC MANAGER — autoload singleton ("Sync")
#  Keeps the local progression (owned by Global, stored in user://)
#  and the server copy in step.
#
#  Local remains the source of truth while offline. When logged in:
#    * on login / launch:  pull server → merge into local → push merged
#    * on local change:    debounced push (after a merge)
#
#  Merge policy (both sides are kept, never silently lost):
#    * grammar_xp / unlocked units  → per-key max
#    * completed units              → per-key set union
#    * saved / review words         → union by (word, book, lesson);
#                                     review keeps the further-along entry
# ============================================================

signal sync_started()
signal sync_finished(success: bool)

const PUSH_DEBOUNCE := 3.0

var _api: Node
var _global: Node
var _push_timer: Timer
var _dirty: bool = false
var _syncing: bool = false


func _ready() -> void:
	_api = get_node_or_null("/root/API")
	_global = get_node_or_null("/root/Global")

	_push_timer = Timer.new()
	_push_timer.one_shot = true
	_push_timer.wait_time = PUSH_DEBOUNCE
	_push_timer.timeout.connect(_flush)
	add_child(_push_timer)

	if _api != null:
		_api.logged_in.connect(_on_logged_in)
		_api.logged_out.connect(_on_logged_out)

	if _global != null and _global.has_signal("progress_dirty"):
		_global.progress_dirty.connect(_on_progress_dirty)

	# A persisted session means we should reconcile with the server on launch.
	if _api != null and _api.has_method("is_logged_in") and _api.is_logged_in():
		call_deferred("sync_now")


func is_syncing() -> bool:
	return _syncing


## Pull → merge → push. Safe to call repeatedly; no-ops when not logged in.
func sync_now() -> void:
	if _syncing or _api == null or not _api.is_logged_in():
		return
	_syncing = true
	sync_started.emit()
	_api.fetch_progress(func(ok: bool, server: Dictionary) -> void:
		if not ok:
			_syncing = false
			sync_finished.emit(false)
			return
		var local: Dictionary = _global.get_progress_snapshot() if _global != null else {}
		var merged := merge(local, server)
		if _global != null:
			_global.apply_progress_snapshot(merged)
		_api.push_progress(merged, func(pushed: bool) -> void:
			_syncing = false
			_dirty = false if pushed else _dirty
			sync_finished.emit(pushed)))


func _on_logged_in(_user: Dictionary) -> void:
	sync_now()


func _on_logged_out() -> void:
	_dirty = false
	if _push_timer != null:
		_push_timer.stop()


func _on_progress_dirty() -> void:
	_dirty = true
	_push_timer.start()


func _flush() -> void:
	if not _dirty:
		return
	if _api == null or not _api.is_logged_in():
		_dirty = false
		return
	if _syncing:
		# A sync is in flight; try again shortly.
		_push_timer.start()
		return
	sync_now()


# ------------------------------------------------------------
# MERGE
# ------------------------------------------------------------

## Merge a local and a server snapshot into one, keeping both sides' progress.
func merge(local: Dictionary, server: Dictionary) -> Dictionary:
	if server == null or server.is_empty():
		return local.duplicate(true)
	if local == null or local.is_empty():
		return server.duplicate(true)

	var out := local.duplicate(true)

	if str(out.get("last_scene", "")) == "":
		out["last_scene"] = str(server.get("last_scene", ""))

	out["grammar_xp"] = _merge_max_dict(
		local.get("grammar_xp", {}), server.get("grammar_xp", {}))
	out["grammar_unlocked_units"] = _merge_max_dict(
		local.get("grammar_unlocked_units", {}), server.get("grammar_unlocked_units", {}))
	out["grammar_completed_units"] = _merge_union_dict(
		local.get("grammar_completed_units", {}), server.get("grammar_completed_units", {}))

	out["saved_words"] = _merge_word_list(
		local.get("saved_words", []), server.get("saved_words", []))
	out["review_words"] = _merge_review_list(
		local.get("review_words", []), server.get("review_words", []))

	out["updated_at"] = int(Time.get_unix_time_from_system())
	return out


func _merge_max_dict(a: Variant, b: Variant) -> Dictionary:
	var out: Dictionary = {}
	if a is Dictionary:
		out = (a as Dictionary).duplicate(true)
	if b is Dictionary:
		for key in (b as Dictionary):
			var other := int((b as Dictionary)[key])
			var mine := int(out.get(key, 0))
			out[key] = maxi(mine, other)
	return out


func _merge_union_dict(a: Variant, b: Variant) -> Dictionary:
	var out: Dictionary = {}
	if a is Dictionary:
		for key in (a as Dictionary):
			out[key] = _as_array((a as Dictionary)[key])
	if b is Dictionary:
		for key in (b as Dictionary):
			var incoming := _as_array((b as Dictionary)[key])
			if not out.has(key):
				out[key] = incoming
				continue
			var existing: Array = out[key]
			for item in incoming:
				if not existing.has(item):
					existing.append(item)
	return out


func _as_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate()
	return []


func _merge_word_key(entry: Dictionary) -> String:
	return "%s|%d|%d" % [
		str(entry.get("word", "")),
		int(entry.get("book", 0)),
		int(entry.get("lesson", 0)),
	]


func _merge_word_list(a: Variant, b: Variant) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if a is Array:
		for entry in (a as Array):
			if entry is Dictionary:
				var key := _merge_word_key(entry)
				if not seen.has(key):
					seen[key] = true
					out.append(entry)
	if b is Array:
		for entry in (b as Array):
			if not (entry is Dictionary):
				continue
			var key := _merge_word_key(entry)
			if not seen.has(key):
				seen[key] = true
				out.append(entry)
	return out


func _merge_review_list(a: Variant, b: Variant) -> Array:
	# Merge by key, and when both sides have a word keep the one that has been
	# reviewed further (higher srs_reps) so SRS progress is never rolled back.
	var by_key: Dictionary = {}
	var order: Array = []

	var ingest := func(list: Variant) -> void:
		if not (list is Array):
			return
		for entry in (list as Array):
			if not (entry is Dictionary):
				continue
			var key := _merge_word_key(entry)
			if not by_key.has(key):
				by_key[key] = entry
				order.append(key)
			else:
				var mine: Dictionary = by_key[key]
				if int(entry.get("srs_reps", 0)) > int(mine.get("srs_reps", 0)):
					by_key[key] = entry

	ingest.call(a)
	ingest.call(b)

	var out: Array = []
	for key in order:
		out.append(by_key[key])
	return out
