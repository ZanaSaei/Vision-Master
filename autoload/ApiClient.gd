extends Node
class_name ApiClient

# ============================================================
#  API CLIENT — autoload singleton ("API")
#  Talks to the Vision Master backend:
#    * phone OTP auth (request/verify/refresh/logout)
#    * subscription status (/me)
#    * progress sync (GET/PUT /progress)
#  Tokens persist in user://auth.json so the user stays logged in.
#
#  Base URL comes from the project setting `vision_master/api_base_url`
#  so it can be pointed at a dev/staging/prod server without code changes.
# ============================================================

signal logged_in(user: Dictionary)
signal logged_out()
signal subscription_updated(subscription: Dictionary)
signal token_refreshed(success: bool)

const AUTH_PATH := "user://auth.json"

var _base_url: String = ""
var _access_token: String = ""
var _refresh_token: String = ""
var _phone: String = ""
var _user_id: String = ""
var _subscription: Dictionary = {}
var _expiry_unix: int = 0

# Guards against firing several refreshes at once (e.g. many queued downloads
# all receiving 401 at the same time).
var _refresh_in_flight: bool = false


func _ready() -> void:
	_base_url = str(ProjectSettings.get_setting("vision_master/api_base_url", "")).strip_edges()
	if _base_url.ends_with("/"):
		_base_url = _base_url.substr(0, _base_url.length() - 1)
	if _base_url == "":
		# Informational: the app runs fully offline until a server URL is set.
		print("[API] vision_master/api_base_url is not set — server features are disabled.")
	_load_auth()


# ------------------------------------------------------------
# STATE
# ------------------------------------------------------------

func is_configured() -> bool:
	return _base_url != ""


func is_logged_in() -> bool:
	return _access_token != "" or _refresh_token != ""


func get_access_token() -> String:
	return _access_token


func get_phone() -> String:
	return _phone


func get_user_id() -> String:
	return _user_id


func get_subscription() -> Dictionary:
	return _subscription.duplicate(true)


# ------------------------------------------------------------
# AUTH
# ------------------------------------------------------------

## Ask the server to text a one-time code to `phone`.
## callback(ok: bool, error: String, retry_after: int)
func request_otp(phone: String, callback: Callable) -> void:
	_post("/auth/request-otp", {"phone": phone}, false,
		func(result: int, code: int, body: Dictionary) -> void:
			if _ok(result, code):
				callback.call(true, "", 0)
			else:
				callback.call(false, _error_of(body, code), int(body.get("retry_after", 0)))
	)


## Verify the code and log in. callback(ok: bool, error: String)
func verify_otp(phone: String, code: String, callback: Callable) -> void:
	_post("/auth/verify-otp", {"phone": phone, "code": code}, false,
		func(result: int, http_code: int, body: Dictionary) -> void:
			if not _ok(result, http_code):
				callback.call(false, _error_of(body, http_code))
				return
			_store_tokens(body)
			_phone = str(body.get("phone", phone))
			_user_id = str(body.get("user_id", ""))
			_subscription = body.get("subscription", {})
			_save_auth()
			logged_in.emit({"phone": _phone, "user_id": _user_id, "subscription": _subscription})
			subscription_updated.emit(_subscription)
			callback.call(true, "")
	)


## Log out locally and best-effort revoke the refresh token on the server.
func logout() -> void:
	if _refresh_token != "":
		_post("/auth/logout", {"refresh_token": _refresh_token}, false,
			func(_r: int, _c: int, _b: Dictionary) -> void: pass)
	_access_token = ""
	_refresh_token = ""
	_phone = ""
	_user_id = ""
	_subscription = {}
	_expiry_unix = 0
	_clear_auth()
	logged_out.emit()


## Refresh the access token. Emits `token_refreshed(success)`.
func refresh_tokens() -> void:
	if _refresh_in_flight:
		return
	if _refresh_token == "":
		token_refreshed.emit(false)
		return
	_refresh_in_flight = true
	_post("/auth/refresh", {"refresh_token": _refresh_token}, false,
		func(result: int, code: int, body: Dictionary) -> void:
			_refresh_in_flight = false
			if _ok(result, code) and body.has("access_token"):
				_store_tokens(body)
				_save_auth()
				token_refreshed.emit(true)
			else:
				token_refreshed.emit(false)
	)


## Ensure we have a non-expired access token; if not, refresh first.
## callback(ok: bool) runs after the token is (or is not) available.
func ensure_token(callback: Callable) -> void:
	if is_logged_in() and _token_valid():
		callback.call(true)
		return
	if _refresh_token == "":
		callback.call(false)
		return
	# One-shot so a single refresh answer wakes every waiting caller and then
	# disconnects itself.
	token_refreshed.connect(_on_ensure_token_done.bind(callback), CONNECT_ONE_SHOT)
	refresh_tokens()


func _on_ensure_token_done(success: bool, callback: Callable) -> void:
	callback.call(success)


## Fetch the current user + subscription from the server.
## callback(ok: bool, data: Dictionary)
func fetch_me(callback: Callable) -> void:
	_authed_get("/me",
		func(result: int, code: int, body: Dictionary) -> void:
			if _ok(result, code):
				_phone = str(body.get("phone", _phone))
				_user_id = str(body.get("user_id", _user_id))
				_subscription = body.get("subscription", _subscription)
				_save_auth()
				subscription_updated.emit(_subscription)
			callback.call(_ok(result, code), body)
	)


# ------------------------------------------------------------
# PROGRESS
# ------------------------------------------------------------

## Pull the server progress blob. callback(ok: bool, data: Dictionary)
func fetch_progress(callback: Callable) -> void:
	_authed_get("/progress",
		func(result: int, code: int, body: Dictionary) -> void:
			if _ok(result, code):
				callback.call(true, body.get("data", {}))
			else:
				callback.call(false, {})
	)


## Push a progress blob. callback(ok: bool)
func push_progress(data: Dictionary, callback: Callable = Callable()) -> void:
	_authed_put("/progress", {"data": data},
		func(result: int, code: int, _body: Dictionary) -> void:
			if callback.is_valid():
				callback.call(_ok(result, code))
	)


# ------------------------------------------------------------
# LOW-LEVEL HTTP
# ------------------------------------------------------------

func _ok(result: int, code: int) -> bool:
	return result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300


func _error_of(body: Dictionary, code: int) -> String:
	var err := str(body.get("error", ""))
	if err != "":
		return err
	return "http_%d" % code


func _token_valid() -> bool:
	return _access_token != "" and (Time.get_unix_time_from_system() + 30.0) < float(_expiry_unix)


func _authed_get(path: String, callback: Callable) -> void:
	_with_token(func(header: PackedStringArray) -> void:
		_request(HTTPClient.METHOD_GET, path, null, header, true, callback))


func _authed_put(path: String, body: Dictionary, callback: Callable) -> void:
	_with_token(func(header: PackedStringArray) -> void:
		_request(HTTPClient.METHOD_PUT, path, body, header, true, callback))


func _with_token(run: Callable) -> void:
	if not is_logged_in():
		run.call(PackedStringArray())
		return
	ensure_token(func(ok: bool) -> void:
		if ok:
			run.call(PackedStringArray(["Authorization: Bearer " + _access_token]))
		else:
			run.call(PackedStringArray()))


func _post(path: String, body: Dictionary, need_auth: bool, callback: Callable) -> void:
	var header := PackedStringArray()
	if need_auth and _access_token != "":
		header.append("Authorization: Bearer " + _access_token)
	_request(HTTPClient.METHOD_POST, path, body, header, false, callback)


## Generic request. On 401 with `allow_refresh`, refreshes once then retries.
func _request(method: int, path: String, body: Variant, header: PackedStringArray,
		allow_refresh: bool, callback: Callable) -> void:
	if _base_url == "":
		callback.call(HTTPRequest.RESULT_CANT_CONNECT, 0, {"error": "no_base_url"})
		return
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	headers.append_array(header)
	http.request_completed.connect(
		func(result: int, code: int, _h: PackedStringArray, bytes: PackedByteArray) -> void:
			http.queue_free()
			var parsed: Dictionary = _parse_dictionary(bytes)
			if code == 401 and allow_refresh and _refresh_token != "":
				# Refresh once, then retry the same request with the new token.
				token_refreshed.connect(
					_retry_after_refresh.bind(method, path, body, callback), CONNECT_ONE_SHOT)
				refresh_tokens()
				return
			callback.call(result, code, parsed)
	)
	var payload := ""
	if body != null:
		payload = JSON.stringify(body)
	var err := http.request(_base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		callback.call(HTTPRequest.RESULT_CANT_CONNECT, 0, {"error": error_string(err)})


func _parse_dictionary(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	return {}


func _retry_after_refresh(success: bool, method: int, path: String, body: Variant, callback: Callable) -> void:
	if success:
		var header := PackedStringArray(["Authorization: Bearer " + _access_token])
		_request(method, path, body, header, false, callback)
	else:
		callback.call(HTTPRequest.RESULT_SUCCESS, 401, {"error": "unauthorized"})


# ------------------------------------------------------------
# TOKEN PERSISTENCE
# ------------------------------------------------------------

func _store_tokens(body: Dictionary) -> void:
	_access_token = str(body.get("access_token", _access_token))
	if body.has("refresh_token"):
		_refresh_token = str(body.get("refresh_token", _refresh_token))
	var ttl := int(body.get("expires_in", 3600))
	_expiry_unix = int(Time.get_unix_time_from_system()) + ttl


func _save_auth() -> void:
	var data := {
		"access_token": _access_token,
		"refresh_token": _refresh_token,
		"expiry_unix": _expiry_unix,
		"phone": _phone,
		"user_id": _user_id,
		"subscription": _subscription,
	}
	var file := FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if file == null:
		push_error("API: could not write %s" % AUTH_PATH)
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _load_auth() -> void:
	if not FileAccess.file_exists(AUTH_PATH):
		return
	var file := FileAccess.open(AUTH_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	_access_token = str(data.get("access_token", ""))
	_refresh_token = str(data.get("refresh_token", ""))
	_expiry_unix = int(data.get("expiry_unix", 0))
	_phone = str(data.get("phone", ""))
	_user_id = str(data.get("user_id", ""))
	_subscription = data.get("subscription", {})


func _clear_auth() -> void:
	if FileAccess.file_exists(AUTH_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_PATH))
