## Supabase-backed authoritative match server. Same contract as LocalServer (create/join/submit/
## view/matches) but the match state lives in Postgres, so it survives restarts and works across
## Cloud Run instances. Every turn is still re-validated by the Referee, and get_view() is still
## redacted — the enemy fleet never leaves the server. Runs SERVER-side only (holds the service key
## via SupabaseStore). Methods are async (await) because they hit the DB.
class_name SupabaseServer
extends RefCounted

var _db: SupabaseStore
var _rng := RandomNumberGenerator.new()

func _init(parent: Node) -> void:
	_db = SupabaseStore.new(parent)
	_rng.randomize()

## True when the service key is present (else the referee should use the in-memory LocalServer).
func configured() -> bool:
	return _db.configured()

func create_match(host_id: String, host_skins: Dictionary = {}, host_ships: Array = [], host_name: String = "") -> Dictionary:
	var id := _new_id()
	var code := _gen_code()
	var gs := GameState.new()
	Placement.apply(gs, 0, host_ships)   # host's fleet down on board 0; board 1 waits for the guest
	var row: Variant = await _db.insert("matches", {
		"id": id, "invite_code": code, "player0": host_id, "player1": null,
		"skins0": host_skins, "skins1": {}, "name0": host_name, "name1": "",
		"state": MatchCodec.encode(gs)})
	if row == null:
		return {"ok": false, "reason": "could not create match"}
	return {"ok": true, "match_id": id, "invite_code": code}

func join_match(code: String, guest_id: String, guest_skins: Dictionary = {}, guest_name: String = "") -> Dictionary:
	code = code.strip_edges().to_upper()
	var rows := await _db.select("matches", "invite_code=eq." + code)
	if rows.is_empty():
		return {"ok": false, "reason": "no match for that code"}
	var m: Dictionary = rows[0]
	if _str(m.get("player1")) != "":
		return {"ok": false, "reason": "match already full"}
	if _str(m.get("player0")) == guest_id:
		return {"ok": false, "reason": "can't join your own match"}
	await _db.update("matches", "id=eq." + _str(m.get("id")),
		{"player1": guest_id, "skins1": guest_skins, "name1": guest_name})   # guest still places via submit_placement
	return {"ok": true, "match_id": _str(m.get("id"))}

## Place a player's fleet; once both fleets are down the match begins.
func submit_placement(match_id: String, player_id: String, ships: Array) -> Dictionary:
	var rows := await _db.select("matches", "id=eq." + match_id)
	if rows.is_empty():
		return {"ok": false, "reason": "no such match"}
	var m: Dictionary = rows[0]
	var pidx := _seat(m, player_id)
	if pidx == -1:
		return {"ok": false, "reason": "you are not in this match"}
	var gs := MatchCodec.decode(m.state)
	if Placement.placed(gs.boards[pidx]):
		return {"ok": false, "reason": "already placed"}
	Placement.apply(gs, pidx, ships)
	var started := Placement.placed(gs.boards[0]) and Placement.placed(gs.boards[1])
	if started:
		gs.begin_turn()
	await _db.update("matches", "id=eq." + match_id, {"state": MatchCodec.encode(gs)})
	return {"ok": true, "started": started}

func submit_turn(match_id: String, player_id: String, turn_dict: Dictionary) -> Dictionary:
	var rows := await _db.select("matches", "id=eq." + match_id)
	if rows.is_empty():
		return {"ok": false, "reason": "no such match"}
	var m: Dictionary = rows[0]
	var pidx := _seat(m, player_id)
	if pidx == -1:
		return {"ok": false, "reason": "you are not in this match"}
	if m.get("state") == null:
		return {"ok": false, "reason": "match not started"}
	var gs := MatchCodec.decode(m.state)
	var turn := Turn.from_dict(turn_dict)
	if turn.player != pidx:
		return {"ok": false, "reason": "turn player mismatch"}
	var r: Dictionary = Referee.apply(gs, turn)
	if r.ok:
		await _db.update("matches", "id=eq." + match_id, {"state": MatchCodec.encode(gs)})
		if int(r.get("winner", -1)) != -1:
			await _bank_rewards(m, gs)   # persist the coins the referee just rolled
		r["hits"] = _cells(r.hits)
		r["sunk"] = r.sunk.size()
	return r

func get_view(match_id: String, player_id: String) -> Dictionary:
	var rows := await _db.select("matches", "id=eq." + match_id)
	if rows.is_empty():
		return {}
	var m: Dictionary = rows[0]
	var pidx := _seat(m, player_id)
	if pidx == -1 or m.get("state") == null:
		return {}
	var gs := MatchCodec.decode(m.state)
	var v := MatchCodec.player_view(gs, pidx)
	v["opponent_skins"] = m.get("skins%d" % (1 - pidx), {})   # the OTHER player's skins for the versus screen
	v["opponent_name"] = _str(m.get("name%d" % (1 - pidx)))   # who they're facing
	return v

func list_matches(player_id: String) -> Array:
	var rows := await _db.select("matches",
		"or=(player0.eq.%s,player1.eq.%s)&order=updated_at.desc" % [player_id, player_id])
	var out: Array = []
	for m in rows:
		var pidx := _seat(m, player_id)
		if pidx == -1:
			continue
		var status := "waiting"
		var your_turn := false
		var turn := 0
		var gs: GameState = MatchCodec.decode(m.state) if m.get("state") != null else null
		if _str(m.get("player1")) == "":
			status = "waiting"                                   # no opponent joined yet
		elif gs == null or not (Placement.placed(gs.boards[0]) and Placement.placed(gs.boards[1])):
			if gs == null or not Placement.placed(gs.boards[pidx]):
				status = "your_turn"; your_turn = true           # you still need to place your fleet
			else:
				status = "their_turn"                            # waiting for them to place
		elif gs.winner() != -1:
			status = "finished"; turn = gs.turn_number
		else:
			turn = gs.turn_number
			your_turn = gs.current_player == pidx
			status = "your_turn" if your_turn else "their_turn"
		var opp_name := _str(m.get("name%d" % (1 - pidx)))
		out.append({"match_id": _str(m.get("id")), "code": _str(m.get("invite_code")),
			"status": status, "your_turn": your_turn,
			"opponent": opp_name if opp_name != "" else _str(m.get("player%d" % (1 - pidx))),
			"turn": turn})
	return out

## Credit a validated coin purchase (idempotent — the DB dedupes by transaction id). Called by the
## referee's RevenueCat webhook after RevenueCat has verified the receipt.
func grant_purchase(txn_id: String, uid: String, coins: int) -> void:
	await _db.rpc("grant_purchase", {"p_txn": txn_id, "p_uid": uid, "p_coins": coins})

## Validate a client's access token and return the account uuid it belongs to (or "" if invalid).
## The referee uses this to derive player identity from the JWT instead of trusting the request body.
func verify_token(token: String) -> String:
	return await _db.verify_user(token)

## Merge one account's wallet + skins into another. Both tokens must validate: dest_token proves the
## caller owns the destination (their new Google account), src_token proves they owned the source (the
## guest account whose coins should follow them). If both tokens resolve to the SAME account, Supabase
## linked the identity in place — nothing to move. Returns {ok, merged}.
func merge_accounts(dest_token: String, src_token: String) -> Dictionary:
	var dest := await _db.verify_user(dest_token)
	var src := await _db.verify_user(src_token)
	if dest == "" or src == "":
		return {"ok": false, "reason": "invalid tokens"}
	if dest == src:
		return {"ok": true, "merged": false}   # identity was linked in place; coins already on this account
	await _db.rpc("merge_profiles", {"from_id": src, "to_id": dest})
	return {"ok": true, "merged": true}

# --- rewards ---

## Bank each player's server-rolled coins onto their profile. Best-effort: needs the player_id to be
## a real auth-user uuid (works once Google sign-in lands); harmless no-op with placeholder ids.
func _bank_rewards(m: Dictionary, gs: GameState) -> void:
	for p in 2:
		var pid := _str(m.get("player%d" % p))
		var amt := int(gs.rewards[p])
		if pid != "" and amt > 0:
			await _db.rpc("add_coins", {"uid": pid, "amount": amt})

# --- helpers (mirror LocalServer) ---

func _seat(m: Dictionary, player_id: String) -> int:
	if _str(m.get("player0")) == player_id:
		return 0
	if _str(m.get("player1")) == player_id:
		return 1
	return -1

func _str(v: Variant) -> String:
	return "" if v == null else str(v)

func _new_id() -> String:
	return "m_%d_%04d" % [int(Time.get_unix_time_from_system()), _rng.randi() % 10000]

func _gen_code() -> String:
	const CH := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # no confusable 0/O/1/I
	var s := ""
	for _i in 6:
		s += CH[_rng.randi_range(0, CH.length() - 1)]
	return s

func _cells(cells: Array) -> Array:
	var out: Array = []
	for c in cells:
		out.append([c.x, c.y])
	return out

