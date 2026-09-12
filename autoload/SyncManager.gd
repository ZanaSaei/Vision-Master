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

## Version of the progress snapshot shape we currently emit. Old blobs (v0/v1)
## lacking a version are upgraded through `migrate()` before merge so a legacy
## install never ships an incompatible blob to the server unexpectedly.
const SCHEMA_VERSION := 2


## Merge a local and a server snapshot into one, keeping both sides' progress.
##
## v2 rule: when the payload carries per-key updated_at timestamps and one
## side edited a key *strictly later* than the other, that side wins (true
## last-writer-wins). When both sides wrote at the same time (or no timestamps
## exist yet, as with legacy v1 blobs), we fall back to the safe combiners:
## per-key max for counters, set union for completed units, union/keep-further
## for the word lists — so nothing can ever regress mid-migration.
func merge(local: Dictionary, server: Dictionary) -> Dictionary:
	if server == null or server.is_empty():
		return _stamp_v2(migrate(local))
	if local == null or local.is_empty():
		return _stamp_v2(migrate(server))

	var l: Dictionary = migrate(local)
	var s: Dictionary = migrate(server)
	var out := l.duplicate(true)
	var lts: Dictionary = l.get("key_updated_at", {})
	var sts: Dictionary = s.get("key_updated_at", {})

	# last_scene: prefer whichever side changed it more recently; fall back to
	# "fill from the other side only when local is empty".
	var picked: Variant = _pick_newer("last_scene",
		str(l.get("last_scene", "")), str(s.get("last_scene", "")), lts, sts)
	if picked != null:
		out["last_scene"] = picked
	elif str(out.get("last_scene", "")) == "":
		out["last_scene"] = str(s.get("last_scene", ""))

	# Grammar counters & unlocked units: per-key max, but a strictly newer
	# side overrides the counter entirely (LWW).
	out["grammar_xp"] = _merge_max_lww("grammar_xp",
		l.get("grammar_xp", {}), s.get("grammar_xp", {}), lts, sts)
	out["grammar_unlocked_units"] = _merge_max_lww("grammar_unlocked_units",
		l.get("grammar_unlocked_units", {}), s.get("grammar_unlocked_units", {}), lts, sts)

	# Completed units: set union unless one side is strictly newer.
	out["grammar_completed_units"] = _merge_union_lww("grammar_completed_units",
		l.get("grammar_completed_units", {}), s.get("grammar_completed_units", {}), lts, sts)

	# Word lists: union / keep-further, unless a strictly newer side overrides.
	out["saved_words"] = _merge_words_lww("saved_words",
		l.get("saved_words", []), s.get("saved_words", []), lts, sts)
	out["review_words"] = _merge_words_lww("review_words",
		l.get("review_words", []), s.get("review_words", []), lts, sts)

	return _stamp_v2(out)


## Upgrade an older/differently-shaped blob to the current schema. v1 already
## matches our field names, so for now this normalises a few legacy shapes and
## stamps the version. Future migrations (e.g. splitting review_words) belong
## here and run ahead of every merge + every push.
func migrate(data: Dictionary) -> Dictionary:
	if data == null or data.is_empty():
		return {}
	var out := data.duplicate(true)
	# Ensure word entries at least carry word/book/lesson so the merge keys and
	# the SRS logic never hit a bare dict from a very old build.
	for list_key in ["saved_words", "review_words"]:
		if out.get(list_key, null) is Array:
			var rows: Array = out[list_key]
			for row in rows:
				if row is Dictionary:
					row["word"] = str(row.get("word", ""))
					row["book"] = int(row.get("book", 0))
					row["lesson"] = int(row.get("lesson", 0))
	out[SCHEMA_VERSION_KEY] = SCHEMA_VERSION
	return out


func _stamp_v2(blob: Dictionary) -> Dictionary:
	if blob.is_empty():
		return {}
	var out := blob.duplicate(true)
	out[SCHEMA_VERSION_KEY] = SCHEMA_VERSION
	out["updated_at"] = int(Time.get_unix_time_from_system())
	# Fold per-key timestamps into a shallow map so _pick_newer can read both
	# sides without duplicating the counts arrays.
	if not out.has("key_updated_at"):
		out["key_updated_at"] = {}
	return out


## Last-writer-wins picker. Returns the value from the newer side when one side
## edited `key` strictly later, or null on a tie (caller then applies combiner).
func _pick_newer(key: String, vout: Variant, valt: Variant, lts: Dictionary, sts: Dictionary) -> Variant:
	var lt := int(lts.get(key, 0))
	var st := int(sts.get(key, 0))
	if lt > st:
		return vout
	if st > lt:
		return valt
	return null


## Per-key max with an LWW short-circuit (used for counters).
func _merge_max_lww(key: String, a: Variant, b: Variant, lts: Dictionary, sts: Dictionary) -> Dictionary:
	var winner: Variant = _pick_newer(key, a, b, lts, sts)
	if winner != null:
		return (winner as Dictionary).duplicate(true) if winner is Dictionary else {}
	return _merge_max_dict(a, b)


## Set union with LWW short-circuit.
func _merge_union_lww(key: String, a: Variant, b: Variant, lts: Dictionary, sts: Dictionary) -> Dictionary:
	var winner: Variant = _pick_newer(key, a, b, lts, sts)
	if winner != null:
		return (winner as Dictionary).duplicate(true) if winner is Dictionary else {}
	return _merge_union_dict(a, b)


func _merge_words_lww(key: String, a: Variant, b: Variant, lts: Dictionary, sts: Dictionary) -> Array:
	var winner: Variant = _pick_newer(key, a, b, lts, sts)
	if winner is Array:
		return (winner as Array).duplicate(true)
	if key == "review_words":
		return _merge_review_list(a, b)
	return _merge_word_list(a, b)


const SCHEMA_VERSION_KEY := "schema_version"


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
