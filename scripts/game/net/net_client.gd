## Client-side facade the UI talks to for online play. Holds the local player identity and a
## `backend` implementing the match contract. Today the backend is the in-process LocalServer;
## swapping it for an HTTP backend (Supabase-fronted Cloud Run referee) is a one-line change and
## nothing above this layer needs to know.
extends Node

## When set (or via the TT_REFEREE_URL env), the game talks to the deployed Cloud Run referee over
## HTTP instead of the in-process LocalServer — the switch that turns on real two-device play. Paste
## your Cloud Run Service URL here after deploying (see docs/deploy/cloud_run.md). Empty = local dev.
const REFEREE_URL := "https://tt-referee-707330193418.us-central1.run.app"

var backend: Variant                 # LocalServer (in-process) or HttpBackend (deployed referee)
var player_id: String = ""
var _online_backend := false         # true when `backend` is the async HttpBackend (network → await)

func _ready() -> void:
	player_id = _load_or_make_id()   # guest fallback until an account signs in
	# Adopt the real account UUID once Auth has a session (it may sign in a moment after us, since
	# restoring a saved session is async). Everything below this layer keys off player_id.
	Auth.signed_in.connect(_on_signed_in)
	Auth.signed_out.connect(func(): player_id = _load_or_make_id())
	if Auth.signed():
		player_id = Auth.user_id
	var url := OS.get_environment("TT_REFEREE_URL")
	if url == "":
		url = REFEREE_URL
	if url != "":
		var hb := HttpBackend.new(url, self)
		hb.auth_token = Auth.access_token   # prove identity to the referee (kept fresh in _on_signed_in)
		backend = hb
		_online_backend = true
	else:
		var ls := LocalServer.new()
		ls.seed_demo(player_id)             # dev content only in the in-process path
		backend = ls

func _on_signed_in(uid: String) -> void:
	if uid != "":
		player_id = uid
	if _online_backend and backend != null:
		backend.auth_token = Auth.access_token   # session refreshed → hand the HTTP backend the new JWT

## Create a match with our placed fleet; returns {ok, match_id, invite_code} to share. Sends our
## equipped skins too, so the opponent sees our cosmetics on the versus screen.
func create_match(ships: Array = []) -> Dictionary:
	if _online_backend:
		return await backend.create_match(player_id, Cosmetics.active, ships, Settings.captain_name())
	return backend.create_match(player_id, Cosmetics.active, ships, Settings.captain_name())

## Join a friend's match by invite code (also sending our equipped skins). We still place our fleet
## afterwards via submit_placement().
func join_match(code: String) -> Dictionary:
	if _online_backend:
		return await backend.join_match(code.strip_edges().to_upper(), player_id, Cosmetics.active, Settings.captain_name())
	return backend.join_match(code.strip_edges().to_upper(), player_id, Cosmetics.active, Settings.captain_name())

## Submit our placed fleet. Once both players have placed, the match begins.
func submit_placement(match_id: String, ships: Array) -> Dictionary:
	if _online_backend:
		return await backend.submit_placement(match_id, player_id, ships)
	return backend.submit_placement(match_id, player_id, ships)

## Submit this turn; the server re-validates it. Returns {ok, reason, hits, sunk}.
func submit_turn(match_id: String, turn: Turn) -> Dictionary:
	if _online_backend:
		return await backend.submit_turn(match_id, player_id, turn.to_dict())
	return backend.submit_turn(match_id, player_id, turn.to_dict())

## The redacted state this player may see (never the enemy fleet).
func get_view(match_id: String) -> Dictionary:
	if _online_backend:
		return await backend.get_view(match_id, player_id)
	return backend.get_view(match_id, player_id)

## The player's in-progress matches, for the Current Games screen.
func list_matches() -> Array:
	if _online_backend:
		return await backend.list_matches(player_id)
	return backend.list_matches(player_id)

## Carry a guest account's wallet + skins into the player's current (Google) account. Called by Auth
## right after a guest signs in with Google, passing the guest's now-superseded token as the source.
func merge_accounts(dest_token: String, src_token: String) -> Dictionary:
	if _online_backend:
		return await backend.merge_accounts(dest_token, src_token)
	return backend.merge_accounts(dest_token, src_token)

func _load_or_make_id() -> String:
	const PATH := "user://player.id"
	if FileAccess.file_exists(PATH):
		return FileAccess.open(PATH, FileAccess.READ).get_as_text().strip_edges()
	var id := "you-%08x" % (randi() & 0xFFFFFFFF)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(id)
	return id
