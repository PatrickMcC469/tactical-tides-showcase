## Headless proof of the async turn loop: a player builds a Turn, it's serialized to JSON ("over
## the wire"), the Referee re-validates it against the authoritative state and applies it — and
## rejects tampered/illegal turns. Run from main.gd; verify with --headless.
class_name NetDemo
extends RefCounted

static func run() -> void:
	print("\n=== Async turn referee demo ===")
	var gs := _match()

	# P0 legal turn: nudge the battleship south, then fire a twin cross at two spots.
	var t := Turn.new()
	t.player = 0
	t.move_ship = &"battleship"
	t.move_steps = ["B"] as Array[String]
	t.fire_id = &"cross_shot"
	t.fire_aim = [Vector2i(8, 2), Vector2i(3, 4)] as Array[Vector2i]
	var wire := JSON.stringify(t.to_dict())
	print("P0 sends %d bytes: %s" % [wire.length(), wire])
	var received := Turn.from_dict(JSON.parse_string(wire))     # server side decodes it
	var r := Referee.apply(gs, received)
	print("P0 turn -> ok=%s reason='%s' hits=%d sunk=%d | now player %d, turn %d" % [
		r.ok, r.reason, r.hits.size(), r.sunk.size(), gs.current_player, gs.turn_number])

	# CHEAT 1 — P1 tries to sail a ship off the board.
	var offboard := _shot_turn(1, &"cross_shot", [Vector2i(2, 2)])
	offboard.move_ship = &"battleship"
	offboard.move_steps = ["F", "F", "F", "F", "F", "F"] as Array[String]
	print("CHEAT off-board move -> %s" % _verdict(Referee.apply(gs, offboard)))

	# CHEAT 2 — the wrong player submits.
	print("CHEAT wrong player  -> %s" % _verdict(Referee.apply(gs, _shot_turn(0, &"cross_shot", [Vector2i(5, 5)]))))

	# CHEAT 3 — fire a ship that isn't P1's fire ability... use a bogus/again-fired path: no target.
	print("CHEAT no target     -> %s" % _verdict(Referee.apply(gs, _shot_turn(1, &"cross_shot", []))))

	# P1 legal turn to continue the match.
	var r1 := Referee.apply(gs, _shot_turn(1, &"cross_shot", [Vector2i(2, 2), Vector2i(2, 3)]))
	print("P1 legal turn -> ok=%s hits=%d | now player %d, turn %d" % [
		r1.ok, r1.hits.size(), gs.current_player, gs.turn_number])
	_serialization_check()
	print("=== demo done ===\n")

## Slice 2: encode a match (with damage, fog, and all three effect types) to JSON and back, and
## confirm it round-trips exactly.
static func _serialization_check() -> void:
	print("--- match serialization round-trip ---")
	var gs := _match()
	# Real mid-match state: a fired turn (shots + damage), and one of each persistent effect.
	var t := Turn.new()
	t.player = 0
	t.move_ship = &"battleship"
	t.move_steps = ["B"] as Array[String]
	t.fire_id = &"cross_shot"
	t.fire_aim = [Vector2i(8, 2)] as Array[Vector2i]
	Referee.apply(gs, t)
	var enemy0 := gs.boards[1]
	enemy0.try_place_mine(0, Vector2i(5, 5), 3)
	enemy0.add_effect(Drone.new(0, Vector2i(7, 7), 4))
	enemy0.add_effect(Barrage.new(0, Sectors.from_label("B2"), _find_ship(gs, 0, &"battleship"), 3, 3))
	gs.mine_sweeps[0] = 1

	var a := MatchCodec.encode(gs)
	var wire := JSON.stringify(a)
	var gs2 := MatchCodec.decode(JSON.parse_string(wire))
	var b := MatchCodec.encode(gs2)
	var same: bool = a == b
	print("full match wire: %d bytes" % wire.length())
	print("round-trip identical: %s" % ("PASS" if same else "FAIL"))
	if not same:
		print("  A = %s" % JSON.stringify(a))
		print("  B = %s" % JSON.stringify(b))
	# The decoded match must be fully playable (occupancy + references rebuilt), not just equal.
	var cont := Referee.apply(gs2, _shot_turn(1, &"cross_shot", [Vector2i(8, 2)]))
	print("decoded match accepts a turn: %s" % ("PASS" if cont.ok else "FAIL ('%s')" % cont.reason))
	_server_check()

## Slice 3a: play through the reference server — invite-code matchmaking, redacted views (the
## enemy fleet is never sent), turn submission, and turn-order enforcement.
static func _server_check() -> void:
	print("--- local reference server ---")
	var srv := LocalServer.new()
	var made := srv.create_match("alice")
	print("Alice created match %s, invite code %s" % [made.match_id, made.invite_code])
	print("join with wrong code -> %s" % _verdict(srv.join_match("ZZZZZZ", "bob")))
	var joined := srv.join_match(made.invite_code, "bob")
	print("Bob joins -> ok=%s" % joined.ok)
	var mid: String = made.match_id

	var av := srv.get_view(mid, "alice")
	print("Alice's view: %d own ships, leaks enemy fleet? %s (must be false), her turn? %s" % [
		av.own_ships.size(), _leaks_enemy(av), av.your_turn])

	var t := Turn.new()
	t.player = 0
	t.fire_id = &"cross_shot"
	t.fire_aim = [Vector2i(8, 2)] as Array[Vector2i]
	var r := srv.submit_turn(mid, "alice", t.to_dict())
	print("Alice fires -> ok=%s hits=%d, now Bob's turn" % [r.ok, r.get("hits", []).size()])
	print("Alice submits again out of turn -> %s" % _verdict(srv.submit_turn(mid, "alice", t.to_dict())))
	var rb := srv.submit_turn(mid, "bob", _shot_turn(1, &"cross_shot", [Vector2i(2, 2)]).to_dict())
	print("Bob fires -> ok=%s, turn %d" % [rb.ok, srv.get_view(mid, "bob").turn_number])
	_client_cycle_check()

## The full client turn cycle the online battle screen will run: fetch the redacted view, rebuild
## the local board (no enemy fleet), simulate a move locally while recording steps, build a Turn,
## and submit it — the server re-validates the move + fire against the true state.
static func _client_cycle_check() -> void:
	print("--- client turn cycle (view -> local move -> submit) ---")
	var srv := LocalServer.new()
	var a := srv.create_match("alice")
	srv.join_match(a.invite_code, "bob")
	var mid: String = a.match_id
	var view := srv.get_view(mid, "alice")
	var local := MatchCodec.decode_view(view)
	print("Alice rebuilt %d own ships from her view; enemy fleet visible: %s; her turn: %s" % [
		local.boards[0].ships.size(), local.boards[1].ships.size() > 0, view.your_turn])

	var cruiser := _find_ship(local, 0, &"cruiser")
	var steps: Array[String] = []
	if local.begin_move(cruiser) and local.try_translate(-1):
		steps.append("B")            # she nudged her cruiser one step on her own board
	var t := Turn.new()
	t.player = 0
	t.move_ship = &"cruiser"
	t.move_steps = steps
	t.fire_id = &"cross_shot"
	t.fire_aim = [Vector2i(8, 2)] as Array[Vector2i]
	var r := srv.submit_turn(mid, "alice", t.to_dict())
	print("Alice submits her recorded turn -> ok=%s hits=%d (server re-validated move+fire)" % [
		r.ok, r.get("hits", []).size()])

## True if a player view leaks any enemy ship data (it must not).
static func _leaks_enemy(view: Dictionary) -> bool:
	return view.has("enemy_ships") or view.has("boards")

static func _find_ship(gs: GameState, player: int, id: StringName) -> ShipInstance:
	for s in gs.boards[player].ships:
		if s.def.id == id:
			return s
	return null

static func _shot_turn(player: int, fire_id: StringName, aim: Array) -> Turn:
	var t := Turn.new()
	t.player = player
	t.fire_id = fire_id
	var a: Array[Vector2i] = []
	a.assign(aim)
	t.fire_aim = a
	return t

static func _verdict(r: Dictionary) -> String:
	return "REJECTED ('%s')" % r.reason if not r.ok else "accepted?! (should have failed)"

static func _match() -> GameState:
	var gs := GameState.new()
	for owner in 2:
		_place(gs, &"battleship", owner, Vector2i(2, 2))
		_place(gs, &"aircraft_carrier", owner, Vector2i(8, 2))
		_place(gs, &"cruiser", owner, Vector2i(14, 6))
		_place(gs, &"submarine", owner, Vector2i(4, 14))
		_place(gs, &"destroyer", owner, Vector2i(10, 14))
		_place(gs, &"drone_ship", owner, Vector2i(16, 15))
	gs.begin_turn()
	return gs

static func _place(gs: GameState, id: StringName, owner: int, origin: Vector2i) -> void:
	var def: ShipDef = null
	for d in ShipCatalog.all():
		if d.id == id:
			def = d
	gs.boards[owner].place(ShipInstance.create(def, owner, origin, GameEnums.Facing.NORTH))
