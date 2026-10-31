## HTTP implementation of the match-server contract (mirrors LocalServer's methods, but over the
## network). Drop-in for Net.backend: same method names, so nothing above NetClient changes except
## that the calls become async (await). Points at the referee server (local now, Cloud Run later).
class_name HttpBackend
extends RefCounted

var base_url: String
var _parent: Node          # HTTPRequest nodes must live in the tree; NetClient supplies itself
var auth_token: String = ""   # Supabase user JWT (added when auth is wired)

func _init(url: String, parent: Node) -> void:
	base_url = url.rstrip("/")
	_parent = parent

func create_match(player_id: String, skins: Dictionary = {}, ships: Array = [], name: String = "") -> Dictionary:
	return await _post("/create", {"player_id": player_id, "skins": skins, "ships": ships, "name": name})

func join_match(code: String, player_id: String, skins: Dictionary = {}, name: String = "") -> Dictionary:
	return await _post("/join", {"code": code, "player_id": player_id, "skins": skins, "name": name})

func submit_placement(match_id: String, player_id: String, ships: Array) -> Dictionary:
	return await _post("/place", {"match_id": match_id, "player_id": player_id, "ships": ships})

func submit_turn(match_id: String, player_id: String, turn_dict: Dictionary) -> Dictionary:
	return await _post("/submit", {"match_id": match_id, "player_id": player_id, "turn": turn_dict})

func get_view(match_id: String, player_id: String) -> Dictionary:
	return await _post("/view", {"match_id": match_id, "player_id": player_id})

func list_matches(player_id: String) -> Array:
	var r := await _post("/matches", {"player_id": player_id})
	return r.get("matches", [])

## Ask the referee to carry a guest account's wallet into the player's new (Google) account. Both
## access tokens are sent so the server can verify the caller owns both accounts before transferring.
func merge_accounts(dest_token: String, src_token: String) -> Dictionary:
	return await _post("/merge", {"dest_token": dest_token, "src_token": src_token})

func _post(path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	_parent.add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth_token != "":
		headers.append("Authorization: Bearer " + auth_token)
	var err := http.request(base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "reason": "could not reach server"}
	var res: Array = await http.request_completed   # [result, code, headers, body]
	http.queue_free()
	if int(res[1]) < 200 or int(res[1]) >= 300:
		return {"ok": false, "reason": "server error %d" % res[1]}
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {"ok": false, "reason": "bad response"}
