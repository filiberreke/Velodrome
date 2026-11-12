extends Node
const MenuStyle := preload("res://menu_theme.gd")
# Strava OAuth2 + Uploads API client. Config contains YOUR secrets; never ship a filled-in copy.
signal status_changed(message: String)
signal activity_created(activity_id: String)
const TOKEN_URL := "https://www.strava.com/oauth/token"
const UPLOAD_URL := "https://www.strava.com/api/v3/uploads"
const CONFIG_PATH := "res://config/strava_config.cfg"
const TOKEN_STORE := "user://config/strava_tokens.cfg"
var upload_path := ""
var upload_name := "Velodrome"
var upload_description := ""
var config := ConfigFile.new()
var tokens := ConfigFile.new()
var pending_code := ""
var pending_dialog: ConfirmationDialog
var working := false

func _emit(message: String) -> void:
	print("Strava: ", message)
	status_changed.emit(message)

func _http(method: int, url: String, headers: PackedStringArray, payload: PackedByteArray) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	var err: Error = req.request_raw(url, headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "message": "Netwerkverzoek mislukt (%d)" % err}
	var response: Array = await req.request_completed
	req.queue_free()
	var http_status: int = int(response[1])
	var raw: String = (response[3] as PackedByteArray).get_string_from_utf8()
	var json: Variant = JSON.parse_string(raw)
	var data: Dictionary = json if json is Dictionary else {}
	return {"ok": http_status >= 200 and http_status < 300, "code": http_status, "data": data, "message": raw.left(300)}

func _config_value(name: String) -> String:
	return str(config.get_value("strava", name, "")).strip_edges()

func _ready() -> void:
	preload("res://config_paths.gd").load_project(config, "strava_config.cfg")
	preload("res://config_paths.gd").load_user(tokens, "strava_tokens.cfg")

func begin_export(path: String, title: String = "Velodrome", description: String = "") -> void:
	preload("res://config_paths.gd").load_project(config, "strava_config.cfg")
	if working:
		_emit("Een upload is al bezig.")
		return
	upload_path = path
	upload_name = title.strip_edges() if not title.strip_edges().is_empty() else "Velodrome"
	upload_description = description
	if not FileAccess.file_exists(path):
		_emit("FIT-bestand ontbreekt. Exporteer eerst de rit.")
		return
	if _config_value("client_id").is_empty() or _config_value("client_secret").is_empty():
		_emit("Vul eerst client_id en client_secret in config/strava_config.cfg in.")
		return
	var refresh: String = str(tokens.get_value("tokens", "refresh_token", ""))
	if refresh.is_empty():
		refresh = _config_value("refresh_token")
	if refresh.is_empty():
		_show_authorize()
	else:
		_upload_with_refresh(refresh)

# Explicit reauthorization: ignore previously saved read-only refresh tokens.
func reconnect() -> void:
	preload("res://config_paths.gd").load_project(config, "strava_config.cfg")
	if working:
		_emit("Wacht tot de huidige Strava-aanvraag is afgerond.")
		return
	if _config_value("client_id").is_empty() or _config_value("client_secret").is_empty():
		_emit("Vul eerst client_id en client_secret in config/strava_config.cfg in.")
		return
	# No tokens are transmitted or shared here. A fresh OAuth approval replaces them.
	_show_authorize()

func _show_authorize() -> void:
	var redirect: String = _config_value("redirect_uri")
	if redirect.is_empty():
		redirect = "http://localhost"
	# Avoid Godot percent-format collisions with percent-encoded query values (e.g. %2C).
	# Reload config so edits made while the game is running are picked up.
	var client_id: String = _config_value("client_id")
	if not client_id.is_valid_int() or int(client_id) <= 0:
		_emit("Strava Client ID ontbreekt of is ongeldig. Vul het numerieke client_id in config/strava_config.cfg in.")
		return
	var params := PackedStringArray([
		"client_id=" + client_id.uri_encode(),
		"redirect_uri=" + redirect.uri_encode(),
		"response_type=code",
		"approval_prompt=force",
		"scope=" + "read,activity:write".uri_encode(),
	])
	var url: String = "https://www.strava.com/oauth/authorize?" + "&".join(params)
	var open_result: Error = OS.shell_open(url)
	if open_result != OK:
		_emit("Kan Strava niet openen in de browser. Controleer je standaardbrowser.")
		return
	var dialog := _build_authorization_dialog()
	dialog.popup_centered(Vector2i(800, 400))

func _build_authorization_dialog() -> ConfirmationDialog:
	pending_dialog = ConfirmationDialog.new()
	pending_dialog.theme = MenuStyle.create()
	pending_dialog.title = "Strava koppelen"
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(650, 320)
	body.add_theme_constant_override("separation", 20)
	pending_dialog.add_child(body)
	var instructions := Label.new()
	instructions.text = "1. Kopieer config/strava_config.example.cfg\n   naar config/strava_config.cfg en vul je gegevens in.\n   Client ID en Client Secret: strava.com/settings/api\n   redirect_uri: http://localhost · callbackdomein: localhost\n2. Geef Strava toestemming om activiteiten te uploaden.\n3. Kopieer de volledige localhost-URL uit je browser.\n4. Plak die hieronder en kies Koppel en upload.\n\nEen onbereikbare localhost-pagina is normaal\nbij deze handmatige koppeling."
	body.add_child(instructions)
	pending_dialog.ok_button_text = "Koppel en upload"
	pending_dialog.cancel_button_text = "Annuleren"
	var input := LineEdit.new()
	input.placeholder_text = "Autorisatiecode of volledige callback-URL"
	input.custom_minimum_size = Vector2(650, 48)
	body.add_child(input)
	add_child(pending_dialog)
	pending_dialog.confirmed.connect(func():
		var code: String = input.text.strip_edges()
		if code.contains("code="):
			code = code.get_slice("code=", 1).get_slice("&", 0).uri_decode()
		if code.is_empty():
			_emit("Geen autorisatiecode opgegeven.")
		elif input.text.contains("error="):
			_emit("Strava-toestemming werd geweigerd. Probeer opnieuw te koppelen.")
		elif input.text.contains("scope=") and not input.text.uri_decode().contains("activity:write"):
			_emit("Strava gaf geen activity:write toestemming. Koppel opnieuw en keur uploads goed.")
		else:
			_exchange_code(code)
	)
	MenuStyle.primary(pending_dialog.get_ok_button())
	pending_dialog.confirmed.connect(pending_dialog.queue_free)
	pending_dialog.canceled.connect(pending_dialog.queue_free)
	input.grab_focus.call_deferred()
	return pending_dialog

func _save_tokens(data: Dictionary) -> void:
	if data.has("refresh_token"):
		tokens.set_value("tokens", "refresh_token", str(data["refresh_token"]))
	if data.has("access_token"):
		tokens.set_value("tokens", "access_token", str(data["access_token"]))
	if data.has("expires_at"):
		tokens.set_value("tokens", "expires_at", int(data["expires_at"]))
	tokens.save(preload("res://config_paths.gd").user_path("strava_tokens.cfg"))

func _form(data: Dictionary) -> PackedByteArray:
	var parts := PackedStringArray()
	for key in data:
		parts.append("%s=%s" % [str(key).uri_encode(), str(data[key]).uri_encode()])
	return "&".join(parts).to_utf8_buffer()

func _exchange_code(code: String) -> void:
	working = true
	_emit("Strava: account koppelen...")
	var result: Dictionary = await _http(HTTPClient.METHOD_POST, TOKEN_URL, PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), _form({"client_id": _config_value("client_id"), "client_secret": _config_value("client_secret"), "code": code, "grant_type": "authorization_code"}))
	if not result["ok"]:
		working = false
		_emit("Strava-koppeling mislukt (HTTP %d): %s" % [result.get("code", 0), result["message"]])
		return
	_save_tokens(result["data"])
	working = false
	_upload_with_refresh(str(result["data"].get("refresh_token", "")))

func _upload_with_refresh(refresh: String) -> void:
	working = true
	_emit("Strava: toegangstoken vernieuwen...")
	var result: Dictionary = await _http(HTTPClient.METHOD_POST, TOKEN_URL, PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), _form({"client_id": _config_value("client_id"), "client_secret": _config_value("client_secret"), "refresh_token": refresh, "grant_type": "refresh_token"}))
	if not result["ok"]:
		working = false
		_emit("Strava-token geweigerd (HTTP %d): %s" % [result.get("code", 0), result["message"]])
		return
	_save_tokens(result["data"])
	var token: String = str(result["data"].get("access_token", ""))
	if token.is_empty():
		working = false
		_emit("Geen toegangstoken ontvangen.")
		return
	await _send_fit(token)
	working = false

func _send_fit(access_token: String) -> void:
	var file := FileAccess.open(upload_path, FileAccess.READ)
	if file == null:
		_emit("Kan FIT-bestand niet openen.")
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var boundary := "----Velodrome250FITUploadBoundary"
	var body := PackedByteArray()
	var form_parts := {"data_type": "fit", "sport_type": "VirtualRide", "name": upload_name, "description": upload_description}
	for key in form_parts:
		body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, key, form_parts[key]]).to_utf8_buffer())
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"velodrome250.fit\"\r\nContent-Type: application/octet-stream\r\n\r\n" % boundary).to_utf8_buffer())
	body.append_array(bytes)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	_emit("Strava: FIT uploaden...")
	var result: Dictionary = await _http(HTTPClient.METHOD_POST, UPLOAD_URL, PackedStringArray(["Authorization: Bearer " + access_token, "Content-Type: multipart/form-data; boundary=" + boundary]), body)
	if not result["ok"]:
		if int(result.get("code", 0)) in [401, 403] and "activity:write_permission" in str(result["message"]):
			_emit("Strava mist activity:write. Klik op 'STRAVA OPNIEUW KOPPELEN' onder de uitslag.")
		else:
			_emit("Strava-upload afgewezen (HTTP %d): %s" % [result.get("code", 0), result["message"]])
		return
	var upload_id: int = int(result["data"].get("id", 0))
	if upload_id == 0:
		_emit("Upload ontvangen, maar Strava gaf geen upload-ID terug.")
		return
	_emit("Upload ontvangen; Strava verwerkt de activiteit...")
	for attempt in range(8):
		await get_tree().create_timer(2.0).timeout
		var state: Dictionary = await _http(HTTPClient.METHOD_GET, UPLOAD_URL + "/" + str(upload_id), PackedStringArray(["Authorization: Bearer " + access_token]), PackedByteArray())
		if not state["ok"]:
			_emit("Statuscontrole mislukt (HTTP %d)" % state.get("code", 0))
			return
		var data: Dictionary = state["data"]
		if int(data.get("activity_id", 0)) > 0:
			var activity_id: String = str(data["activity_id"])
			_emit("Strava-activiteit geplaatst! ID: " + activity_id)
			activity_created.emit(activity_id)
			return
		if str(data.get("error", "")) != "":
			_emit("Strava kon de rit niet verwerken: " + str(data["error"]))
			return
	_emit("Strava verwerkt nog. Controleer je activiteitenlijst later.")
