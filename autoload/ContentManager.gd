extends Node
class_name ContentManager

# ============================================================
#  CONTENT MANAGER — autoload singleton ("Content")
#  Single gateway for the heavy media (audio + lesson images) that is
#  NOT shipped in the APK. It knows, for any logical `res://assets/...`
#  path, whether it is bundled or must come from user://content/.
#
#  Responsibilities:
#    * resolve/load audio & images from either location
#    * fetch the server manifest
#    * download per-lesson on demand, or everything ("download all")
#    * track what is already downloaded (user://content/index.json)
#
#  Offline-first: if a file is missing and cannot be fetched, callers get a
#  null stream/texture and degrade gracefully (e.g. TTS fallback for words).
# ============================================================

signal manifest_ready()
signal download_progress(done_count: int, total_count: int, done_bytes: int, total_bytes: int)
signal download_finished(success: bool)
signal lesson_ready(book: int, lesson: int)

const LOCAL_DIR := "user://content/"
const INDEX_PATH := "user://content/index.json"
const MANIFEST_PATH := "user://content/manifest.json"

var _manifest: Dictionary = {}
var _index: Dictionary = {}

var _queue: Array = []
var _active: bool = false
var _failed: Array = []
var _auth_dead: bool = false
var _awaiting_token: bool = false

var _http: HTTPRequest
var _manifest_http: HTTPRequest

# Download batch progress counters.
var _dl_total_count: int = 0
var _dl_done_count: int = 0
var _dl_total_bytes: int = 0
var _dl_done_bytes: int = 0

var _pending_lessons: Array = []


func _ready() -> void:
	_load_index()
	_load_cached_manifest()

	_http = HTTPRequest.new()
	_http.timeout = 60.0
	_http.request_completed.connect(_on_download_completed)
	add_child(_http)

	_manifest_http = HTTPRequest.new()
	_manifest_http.timeout = 20.0
	_manifest_http.request_completed.connect(_on_manifest_completed)
	add_child(_manifest_http)

	var api := _api_node()
	if api != null and api.has_signal("token_refreshed"):
		api.token_refreshed.connect(_on_token_refreshed)


# ------------------------------------------------------------
# RESOLUTION / LOADING
# ------------------------------------------------------------

## Returns a loadable path for a logical `res://assets/...` path, preferring
## the bundled copy, then the downloaded copy, else "" when missing.
func resolve(logical_path: String) -> String:
	if FileAccess.file_exists(logical_path):
		return logical_path
	var rel := _rel(logical_path)
	if rel != "":
		var local := _local_for(rel)
		if FileAccess.file_exists(local):
			return local
	return ""


func has_asset(logical_path: String) -> bool:
	return resolve(logical_path) != ""


## Load an AudioStream from either the bundled or downloaded copy.
func load_audio(logical_path: String) -> AudioStream:
	var path := resolve(logical_path)
	if path == "":
		return null
	if path.begins_with("res://"):
		return load(path) as AudioStream
	match path.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null


## Load a Texture2D from either the bundled or downloaded copy.
func load_image(logical_path: String) -> Texture2D:
	var path := resolve(logical_path)
	if path == "":
		return null
	if path.begins_with("res://"):
		return load(path) as Texture2D
	var image := Image.load_from_file(path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


# ------------------------------------------------------------
# MANIFEST
# ------------------------------------------------------------

func get_manifest() -> Dictionary:
	return _manifest


func has_manifest() -> bool:
	return not _manifest.is_empty()


## Fetch the manifest from the server (requires a logged-in session).
func refresh_manifest() -> void:
	_ensure_logged_in(func(ok: bool) -> void:
		if not ok:
			# Guest / offline: nothing to fetch. Not an error — the app runs
			# from any bundled assets and fetches content once signed in.
			return
		var base := _api_base()
		if base == "":
			push_warning("Content: api_base_url not set.")
			return
		var headers := PackedStringArray(["Authorization: Bearer " + _token()])
		var err := _manifest_http.request(base + "/content/manifest", headers)
		if err != OK:
			push_error("Content: manifest request failed (%d)" % err)
	)


func _on_manifest_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("Content: manifest fetch failed (result %d, HTTP %d)" % [result, code])
		return
	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Content: manifest is not a JSON object.")
		return
	_manifest = parsed
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
	manifest_ready.emit()


# ------------------------------------------------------------
# DOWNLOADS
# ------------------------------------------------------------

func is_lesson_ready(book: int, lesson: int) -> bool:
	for entry in _files_for_lesson(book, lesson):
		if not _entry_present(entry):
			return false
	return true


## Make sure every file for a lesson is present; download the missing ones.
func ensure_lesson(book: int, lesson: int) -> void:
	if not has_manifest():
		# Without a manifest we can't know what to fetch; try once and bail.
		refresh_manifest()
		return
	if is_lesson_ready(book, lesson):
		lesson_ready.emit(book, lesson)
		return
	if not _pending_lessons.has([book, lesson]):
		_pending_lessons.append([book, lesson])
	_reset_if_idle()
	for entry in _files_for_lesson(book, lesson):
		_enqueue(entry)
	_emit_progress()
	_pump()


## Queue every manifest file that isn't downloaded yet.
func download_all() -> void:
	if not has_manifest():
		refresh_manifest()
		return
	_reset_if_idle()
	for entry in _manifest.get("files", []):
		_enqueue(entry)
	_emit_progress()
	_pump()


func retry_failed() -> void:
	if _failed.is_empty():
		return
	_reset_if_idle()
	for entry in _failed:
		_enqueue(entry)
	_failed.clear()
	_emit_progress()
	_pump()


func is_downloading() -> bool:
	return _active or not _queue.is_empty()


func failed_downloads() -> Array:
	return _failed.duplicate()


func _reset_if_idle() -> void:
	if not _active and _queue.is_empty() and _failed.is_empty():
		_dl_total_count = 0
		_dl_done_count = 0
		_dl_total_bytes = 0
		_dl_done_bytes = 0
		_auth_dead = false


func _enqueue(entry: Dictionary) -> void:
	if _entry_present(entry):
		return
	var rel := str(entry.get("path", ""))
	if rel == "":
		return
	for queued in _queue:
		if str(queued.get("path", "")) == rel:
			return
	_queue.append(entry)
	_dl_total_count += 1
	_dl_total_bytes += int(entry.get("size", 0))


func _pump() -> void:
	if _active or _auth_dead:
		return
	if _queue.is_empty():
		_on_queue_drained()
		return
	_active = true
	var entry: Dictionary = _queue[0]
	var url := _api_base() + str(entry.get("url", ""))
	var headers := PackedStringArray(["Authorization: Bearer " + _token()])
	var err := _http.request(url, headers)
	if err != OK:
		push_error("Content: download request failed (%d) for %s" % [err, url])
		_active = false
		_queue.pop_front()
		_failed.append(entry)
		call_deferred("_pump")


func _on_download_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_active = false
	if _queue.is_empty():
		return
	var entry: Dictionary = _queue[0]

	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		if _store_file(entry, body):
			_queue.pop_front()
			_dl_done_count += 1
			_dl_done_bytes += int(entry.get("size", 0))
			_emit_progress()
		else:
			_queue.pop_front()
			_failed.append(entry)
		call_deferred("_pump")
		return

	if code == 401 and not _awaiting_token:
		var api := _api_node()
		if api != null:
			_awaiting_token = true
			api.refresh_tokens()
			return
	# Any other failure: skip this file, remember it, keep going.
	push_warning("Content: download failed (result %d, HTTP %d) for %s" % [result, code, entry.get("path", "")])
	_queue.pop_front()
	_failed.append(entry)
	call_deferred("_pump")


func _on_token_refreshed(success: bool) -> void:
	if not _awaiting_token:
		return
	_awaiting_token = false
	if success:
		call_deferred("_pump")
	else:
		# Session is dead — stop the whole batch rather than N failing requests.
		_auth_dead = true
		download_finished.emit(false)


func _on_queue_drained() -> void:
	_emit_progress()
	_check_pending_lessons()
	download_finished.emit(_failed.is_empty())


# ------------------------------------------------------------
# STORAGE
# ------------------------------------------------------------

func total_downloaded_bytes() -> int:
	var total := 0
	for info in _index.values():
		total += int(info.get("size", 0))
	return total


func clear_downloads() -> void:
	_index.clear()
	_save_index()
	_remove_dir_recursive(ProjectSettings.globalize_path(LOCAL_DIR))


func _store_file(entry: Dictionary, bytes: PackedByteArray) -> bool:
	var rel := str(entry.get("path", ""))
	if rel == "":
		return false
	var local := _local_for(rel)
	var dir := local.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			push_error("Content: cannot create %s (%d)" % [dir, mk])
			return false
	var file := FileAccess.open(local, FileAccess.WRITE)
	if file == null:
		push_error("Content: cannot write %s" % local)
		return false
	file.store_buffer(bytes)
	file.close()
	_index[rel] = {"sha256": str(entry.get("sha256", "")), "size": bytes.size()}
	_save_index()
	return true


func _save_index() -> void:
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Content: cannot write index %s" % INDEX_PATH)
		return
	file.store_string(JSON.stringify(_index))
	file.close()


func _load_index() -> void:
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_index = parsed


func _load_cached_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_manifest = parsed


func _remove_dir_recursive(abs_path: String) -> void:
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		var full := abs_path.path_join(entry_name)
		if dir.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_path)


# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

func _files_for_lesson(book: int, lesson: int) -> Array:
	var out: Array = []
	for entry in _manifest.get("files", []):
		if int(entry.get("book", -1)) == book and int(entry.get("lesson", -1)) == lesson:
			out.append(entry)
	return out


func _entry_present(entry: Dictionary) -> bool:
	var rel := str(entry.get("path", ""))
	if rel == "":
		return false
	return FileAccess.file_exists(_local_for(rel)) or FileAccess.file_exists("res://" + rel)


func _check_pending_lessons() -> void:
	var still: Array = []
	for pair in _pending_lessons:
		if is_lesson_ready(int(pair[0]), int(pair[1])):
			lesson_ready.emit(int(pair[0]), int(pair[1]))
		else:
			still.append(pair)
	_pending_lessons = still


func _emit_progress() -> void:
	download_progress.emit(_dl_done_count, _dl_total_count, _dl_done_bytes, _dl_total_bytes)


func _rel(logical_path: String) -> String:
	if logical_path.begins_with("res://"):
		return logical_path.substr(6)
	return logical_path


func _local_for(rel: String) -> String:
	return LOCAL_DIR + rel


func _api_base() -> String:
	var base := str(ProjectSettings.get_setting("vision_master/api_base_url", "")).strip_edges()
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	return base


func _api_node() -> Node:
	return get_node_or_null("/root/API")


func _token() -> String:
	var api := _api_node()
	if api != null and api.has_method("get_access_token"):
		return str(api.get_access_token())
	return ""


func _ensure_logged_in(callback: Callable) -> void:
	var api := _api_node()
	if api == null or not api.has_method("is_logged_in"):
		callback.call(false)
		return
	if not api.is_logged_in():
		callback.call(false)
		return
	api.ensure_token(callback)
