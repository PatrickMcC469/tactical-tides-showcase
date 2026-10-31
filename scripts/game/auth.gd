## Account/session manager (autoload `Auth`). Owns the player's Supabase Auth session and exposes a
## stable `user_id` (a real account UUID) plus the `access_token` (JWT) used to prove identity to the
## referee. Two ways in:
##   - sign_in_anonymous(): a real account with no login, created on first launch. Unlocks the
##     server-side coin wallet + friends immediately. Device-local until linked to Google.
##   - sign_in_with_google(id_token): exchanges a Google ID token (from the native Sign-In plugin,
##     bundled at export) for a Supabase session. Same account can later LINK anonymous -> Google so
##     progress carries across devices.
## The refresh token is persisted to user:// so the player stays signed in across launches; on start
## we silently refresh it into a fresh access token.
##
## Keys: the PUBLISHABLE (anon) key is meant to ship inside client apps — public and safe to bake in.
## The SERVICE key never lives here (that's server-only, see supabase_store.gd).
extends Node

const DEFAULT_URL := "https://YOUR_PROJECT.supabase.co"   # public project URL (safe)

## Supabase *publishable* (anon) key. This is public and designed to ship inside client apps — safe
## to commit. (The SERVICE key is the secret one and never lives here — see supabase_store.gd.)
## SUPABASE_ANON_KEY in the environment overrides this for testing.
const ANON_KEY_FALLBACK := "sb_publishable_vdAlH5L7JlYYMigxFByz_A_90_de_tT"

signal signed_in(user_id: String)
signal signed_out()

var user_id: String = ""        # real account UUID once signed in
var access_token: String = ""   # JWT — proves identity to the referee (Authorization: Bearer)
var is_anonymous: bool = false  # true for a no-login account (prompt to link Google to keep progress)

var _url: String
var _anon_key: String
var _refresh_token: String = ""

const SESSION_PATH := "user://session.json"

func _ready() -> void:
	_url = OS.get_environment("SUPABASE_URL")
	if _url == "":
		_url = DEFAULT_URL
	_url = _url.rstrip("/")
	_anon_key = OS.get_environment("SUPABASE_ANON_KEY")
	if _anon_key == "":
		_anon_key = ANON_KEY_FALLBACK
	_load_stored()   # sync: read any saved refresh token (the actual restore happens in ensure_account)

## True once we can talk to Supabase Auth (publishable key present).
func configured() -> bool:
	return _anon_key != ""

## True when we hold a live session.
func signed() -> bool:
	return access_token != ""

## Base URL + publishable key, for authenticated REST calls (the Wallet reads/claims with these + the
## user's access_token).
func api_url() -> String:
	return _url
func api_key() -> String:
	return _anon_key

## Guarantee a signed-in account exists: restore a saved session if we can, otherwise create an
## anonymous one. Await this once at startup (the splash). Returns true if signed in afterward.
func ensure_account() -> bool:
	if signed():
		return true
	if _refresh_token != "":
		var r: Variant = await _auth_req("/auth/v1/token?grant_type=refresh_token", {
			"refresh_token": _refresh_token,
		})
		if _apply(r, is_anonymous):
			return true   # restored an existing account (keep its guest/permanent status)
		# refresh failed (expired/revoked) — fall through to a fresh anonymous account
		_refresh_token = ""
	if configured():
		return await sign_in_anonymous()
	return false

## Create a real account with no login screen. Requires "Allow anonymous sign-ins" enabled in the
## Supabase dashboard (Authentication -> Sign In / Providers). Returns true on success.
func sign_in_anonymous() -> bool:
	var r: Variant = await _auth_req("/auth/v1/signup", {})
	return _apply(r, true)

## --- Native Google Sign-In (Android/iOS plugin, bundled at export) --------------------------------
## Name of the plugin singleton. Set to match the Google Sign-In plugin you bundle at Codemagic. On
## desktop/editor the singleton is absent, so google_available() is false and the UI hides the button.
const GOOGLE_SINGLETON := "GodotGoogleSignIn"

## True only on a device where the Google Sign-In plugin is present.
func google_available() -> bool:
	return Engine.has_singleton(GOOGLE_SINGLETON)

## Drive the native Google account picker, then exchange the resulting ID token for a Supabase
## session. Returns true on success; false (no-op) when the plugin isn't present.
func sign_in_with_google_native() -> bool:
	if not google_available():
		return false
	var id_token: String = await _native_google_id_token(Engine.get_singleton(GOOGLE_SINGLETON))
	if id_token == "":
		return false
	return await sign_in_with_google(id_token)

## Bridge the plugin's callback signals into an awaited return. Plugins vary; this probes common
## signal/method names (sign_in_success(id_token) / sign_in_failed, signIn()/sign_in()). Adjust to
## your plugin's exact API once chosen. Bounded wait so a cancelled picker doesn't hang.
func _native_google_id_token(g: Object) -> String:
	var box := {"token": "", "done": false}
	if g.has_signal("sign_in_success"):
		g.connect("sign_in_success", func(t: String): box.token = t; box.done = true, CONNECT_ONE_SHOT)
	if g.has_signal("sign_in_failed"):
		g.connect("sign_in_failed", func(_e = null): box.done = true, CONNECT_ONE_SHOT)
	if g.has_method("sign_in"):
		g.call("sign_in")
	elif g.has_method("signIn"):
		g.call("signIn")
	else:
		return ""
	var waited := 0.0
	while not box.done and waited < 120.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return box.token

## Exchange a Google ID token (from the native Google Sign-In plugin) for a Supabase session.
## Requires the Google provider enabled in Supabase with your OAuth client ID.
func sign_in_with_google(id_token: String) -> bool:
	# Remember the guest account so its wallet can follow the player if Google mints a NEW account.
	var prev_id := user_id
	var prev_token := access_token
	var was_anon := is_anonymous
	var r: Variant = await _auth_req("/auth/v1/token?grant_type=id_token", {
		"provider": "google",
		"id_token": id_token,
	})
	var ok := _apply(r, false)
	if ok and was_anon and prev_id != "" and user_id != prev_id:
		# Google created a separate account (Supabase didn't link the identity in place), so the
		# guest's coins/skins live under the old uuid — carry them over. The server verifies both
		# tokens, so this can only move a wallet the player actually owns.
		await Net.merge_accounts(access_token, prev_token)
	return ok

## Drop the session (server-side logout is best-effort) and forget the stored refresh token.
func sign_out() -> void:
	if access_token != "":
		await _auth_req("/auth/v1/logout", {}, true)
	user_id = ""
	access_token = ""
	_refresh_token = ""
	is_anonymous = false
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	signed_out.emit()

# --- internals ---------------------------------------------------------------

## Read a persisted refresh token (sync, no network). ensure_account() trades it for a live session.
func _load_stored() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return
	_refresh_token = (data as Dictionary).get("refresh_token", "")
	is_anonymous = (data as Dictionary).get("is_anonymous", false)

## Adopt a Supabase auth response {access_token, refresh_token, user:{id}}. `anonymous` records
## whether this session is a guest account (persisted so the UI knows to offer Google). Returns true.
func _apply(r: Variant, anonymous: bool) -> bool:
	if not (r is Dictionary):
		return false
	var d := r as Dictionary
	var token: String = d.get("access_token", "")
	if token == "":
		return false
	access_token = token
	_refresh_token = d.get("refresh_token", _refresh_token)
	var u: Variant = d.get("user", {})
	if u is Dictionary:
		user_id = (u as Dictionary).get("id", user_id)
	is_anonymous = anonymous
	_save()
	signed_in.emit(user_id)
	return true

func _save() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"refresh_token": _refresh_token,
			"is_anonymous": is_anonymous,
		}))

## POST to a Supabase Auth (GoTrue) endpoint with the publishable key. `bearer` attaches the current
## access token (for authenticated endpoints like logout). Returns the parsed JSON or null.
func _auth_req(path: String, body: Dictionary, bearer: bool = false) -> Variant:
	if _anon_key == "":
		push_warning("Auth: no publishable key (set SUPABASE_ANON_KEY or ANON_KEY_FALLBACK)")
		return null
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray([
		"apikey: " + _anon_key,
		"Content-Type: application/json",
	])
	if bearer and access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	var err := http.request(_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		push_warning("Auth: request could not start (%d)" % err)
		return null
	var res: Array = await http.request_completed   # [result, code, headers, body]
	http.queue_free()
	var code := int(res[1])
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	if code < 200 or code >= 300:
		push_warning("Auth %s -> HTTP %d" % [path, code])   # body may carry tokens; don't log it
		return null
	if text == "":
		return {}
	return JSON.parse_string(text)
