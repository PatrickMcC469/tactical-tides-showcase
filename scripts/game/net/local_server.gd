## In-process reference implementation of the authoritative match server. Holds matches in memory
## and exposes exactly the operations the cloud backend will: create/join by invite code, submit a
## turn (validated by the Referee against the hidden authoritative state), and fetch a redacted
## per-player view. Lets us play a full async match on one machine, and each method maps 1:1 to a
## Supabase Edge Function later. NEVER returns the enemy fleet to a client.
##
## Fleets are auto-placed for now; a real placement-submission step comes with the client wiring.
class_name LocalServer
extends RefCounted

var _matches := {}     # match_id -> {gs:GameState, players:[id0,id1], code:String}
var _by_code := {}     # invite_code -> match_id
var _seq := 0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

## Host creates a match with THEIR placed fleet; returns its id + a shareable invite code. Board 0
## holds the host's ships, board 1 waits for the guest to place. (skins are presentation-only,
## stored here so each player can see the OTHER's equipped skins on the versus screen.)
func create_match(host_id: String, host_skins: Dictionary = {}, host_ships: Array = [], host_name: String = "") -> Dictionary:
	_seq += 1
	var id := "m%d" % _seq
	var code := _gen_code()
	var gs := GameState.new()
	Placement.apply(gs, 0, host_ships)
	_matches[id] = {"gs": gs, "players": [host_id, ""], "code": code,
		"skins": [host_skins, {}], "names": [host_name, ""]}
	_by_code[code] = id
	return {"ok": true, "match_id": id, "invite_code": code}

## Guest joins via invite code. They still have to place their fleet (submit_placement) before the
## match begins.
func join_match(code: String, guest_id: String, guest_skins: Dictionary = {}, guest_name: String = "") -> Dictionary:
	var id: String = _by_code.get(code, "")
	if id == "":
		return {"ok": false, "reason": "no match for that code"}
	var m: Dictionary = _matches[id]
	if String(m.players[1]) != "":
		return {"ok": false, "reason": "match already full"}
	if String(m.players[0]) == guest_id:
		return {"ok": false, "reason": "can't join your own match"}
	m.players[1] = guest_id
	m.skins[1] = guest_skins
	m.names[1] = guest_name
	return {"ok": true, "match_id": id}

## Place a player's fleet. Once BOTH fleets are down the match begins (first turn starts).
func submit_placement(match_id: String, player_id: String, ships: Array) -> Dictionary:
	var m: Dictionary = _matches.get(match_id, {})
	if m.is_empty():
		return {"ok": false, "reason": "no such match"}
	var pidx: int = m.players.find(player_id)
	if pidx == -1:
		return {"ok": false, "reason": "you are not in this match"}
	if Placement.placed(m.gs.boards[pidx]):
		return {"ok": false, "reason": "already placed"}
	Placement.apply(m.gs, pidx, ships)
	var started := Placement.placed(m.gs.boards[0]) and Placement.placed(m.gs.boards[1])
	if started:
		m.gs.begin_turn()
	return {"ok": true, "started": started}

## Submit a turn. The server re-validates it with the Referee against the authoritative state and
## only advances on success. Returns the shot result the submitter is allowed to know.
func submit_turn(match_id: String, player_id: String, turn_dict: Dictionary) -> Dictionary:
	var m: Dictionary = _matches.get(match_id, {})
	if m.is_empty() or m.gs == null:
		return {"ok": false, "reason": "no such match"}
	var pidx: int = m.players.find(player_id)
	if pidx == -1:
		return {"ok": false, "reason": "you are not in this match"}
	var turn := Turn.from_dict(turn_dict)
	if turn.player != pidx:
		return {"ok": false, "reason": "turn player mismatch"}
	var r: Dictionary = Referee.apply(m.gs, turn)
	if r.ok:
		r["hits"] = _cells(r.hits)      # make the result JSON-friendly for transport
		r["sunk"] = r.sunk.size()
	return r

## Fetch the redacted state this player is allowed to see (never the enemy fleet).
func get_view(match_id: String, player_id: String) -> Dictionary:
	var m: Dictionary = _matches.get(match_id, {})
	if m.is_empty() or m.gs == null:
		return {}
	var pidx: int = m.players.find(player_id)
	if pidx == -1:
		return {}
	var v := MatchCodec.player_view(m.gs, pidx)
	v["opponent_skins"] = m.get("skins", [{}, {}])[1 - pidx]   # so the client can render their fleet
	v["opponent_name"] = m.get("names", ["", ""])[1 - pidx]    # who they're facing (versus screen)
	return v

## The matches a player is in, with status for the Current Games list.
func list_matches(player_id: String) -> Array:
	var out: Array = []
	for id in _matches:
		var m: Dictionary = _matches[id]
		var pidx: int = m.players.find(player_id)
		if pidx == -1:
			continue
		var gs: GameState = m.gs
		var status := "waiting"
		var your_turn := false
		var turn := 0
		if String(m.players[1]) == "":
			status = "waiting"                                   # no opponent has joined yet
		elif not (Placement.placed(gs.boards[0]) and Placement.placed(gs.boards[1])):
			if not Placement.placed(gs.boards[pidx]):
				status = "your_turn"; your_turn = true           # you still need to place your fleet
			else:
				status = "their_turn"                            # waiting for them to place
		elif gs.winner() != -1:
			status = "finished"; turn = gs.turn_number
		else:
			turn = gs.turn_number
			your_turn = gs.current_player == pidx
			status = "your_turn" if your_turn else "their_turn"
		var opp_name := String(m.get("names", ["", ""])[1 - pidx])
		out.append({"match_id": id, "code": m.code, "status": status, "your_turn": your_turn,
			"opponent": opp_name if opp_name != "" else String(m.players[1 - pidx]), "turn": turn})
	return out

## Dev seed so the Current Games screen has content before a real backend exists: one game on your
## turn, one on the opponent's, and one still waiting for someone to join by code.
func seed_demo(player_id: String) -> void:
	var ships := _auto_ships()
	var a := create_match(player_id, {}, ships)             # -> your turn (both placed, you go first)
	join_match(a.invite_code, "kade", {}, "Kade")
	submit_placement(a.match_id, "kade", ships)
	var b := create_match(player_id, {}, ships)             # -> their turn (you already fired)
	join_match(b.invite_code, "mara", {}, "Mara")
	submit_placement(b.match_id, "mara", ships)
	submit_turn(b.match_id, player_id, _demo_fire(0))
	create_match(player_id, {}, ships)                      # -> waiting for an opponent to join

func _demo_fire(player: int) -> Dictionary:
	return {"player": player, "move_ship": "", "move_steps": [], "special_id": "",
		"special_aim": [], "special_orient": 0, "fire_id": "cross_shot",
		"fire_aim": [[8, 2]], "fire_orient": 0}

## No-op merge: in-memory play has no persistent wallet to move (profiles live only in Supabase).
## Present so the backend contract matches SupabaseServer; the real transfer happens in the cloud.
func merge_accounts(_dest_token: String, _src_token: String) -> Dictionary:
	return {"ok": true, "merged": false}

# --- helpers ---

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

## A default auto-placement (for seed demos / quick tests): [id, x, y, facing] per ship.
func _auto_ships() -> Array:
	return [
		["battleship", 2, 2, 0], ["aircraft_carrier", 8, 2, 0], ["cruiser", 14, 6, 0],
		["submarine", 4, 14, 0], ["destroyer", 10, 14, 0], ["drone_ship", 16, 15, 0],
	]
