## Serialize a whole match (GameState + both boards + ships + effects + powerups + fog + RNG) to a
## JSON-friendly Dictionary and back. The authoritative server persists/transmits matches with
## this. Round-trips exactly: encode(decode(encode(gs))) == encode(gs).
##
## Notes: Vector2i is stored as [x, y]; the RNG seed/state go as STRINGS (they're 64-bit and JSON
## numbers are doubles, which would lose precision); occupancy and the barrage caster link are
## rebuilt after decode rather than stored.
class_name MatchCodec
extends RefCounted

static func encode(gs: GameState) -> Dictionary:
	return {
		"current_player": gs.current_player,
		"turn_number": gs.turn_number,
		"has_moved": gs.has_moved,
		"has_used_special": gs.has_used_special,
		"has_fired": gs.has_fired,
		"moving_ship": _ship_id(gs.moving_ship),
		"move_points_left": gs.move_points_left,
		"used_free_rotation": gs.used_free_rotation,
		"rng_seed": str(gs.rng.seed),
		"rng_state": str(gs.rng.state),
		"mine_sweeps": [gs.mine_sweeps[0], gs.mine_sweeps[1]],
		"shots": [_shots_out(gs.shots[0]), _shots_out(gs.shots[1])],
		"rewards": [gs.rewards[0], gs.rewards[1]],
		"incoming": [_incoming_out(gs.incoming[0]), _incoming_out(gs.incoming[1])],
		"boards": [_board_out(gs.boards[0]), _board_out(gs.boards[1])],
	}

static func decode(d: Dictionary) -> GameState:
	var gs := GameState.new()   # gives us two empty boards + an rng
	gs.current_player = int(d["current_player"])
	gs.turn_number = int(d["turn_number"])
	gs.has_moved = bool(d["has_moved"])
	gs.has_used_special = bool(d["has_used_special"])
	gs.has_fired = bool(d["has_fired"])
	gs.move_points_left = int(d["move_points_left"])
	gs.used_free_rotation = bool(d["used_free_rotation"])
	gs.rng.seed = int(str(d["rng_seed"]))
	gs.rng.state = int(str(d["rng_state"]))
	gs.mine_sweeps[0] = int(d["mine_sweeps"][0])
	gs.mine_sweeps[1] = int(d["mine_sweeps"][1])
	gs.shots[0] = _shots_in(d["shots"][0])
	gs.shots[1] = _shots_in(d["shots"][1])
	var rw: Array = d.get("rewards", [0, 0])
	gs.rewards[0] = int(rw[0])
	gs.rewards[1] = int(rw[1])
	var inc: Array = d.get("incoming", [{}, {}])
	gs.incoming[0] = _incoming_in(inc[0])
	gs.incoming[1] = _incoming_in(inc[1])
	gs.boards[0] = _board_in(d["boards"][0])
	gs.boards[1] = _board_in(d["boards"][1])
	# Cross-references that weren't stored directly.
	gs.moving_ship = _find(gs.boards[gs.current_player], StringName(d["moving_ship"]))
	for b in gs.boards:
		for e in b.effects:
			if e is Barrage:
				var cid: String = e.get_meta("caster_id", "")
				(e as Barrage).caster = _find(gs.boards[e.placer], StringName(cid)) if cid != "" else null
				e.remove_meta("caster_id")
		b.reindex()
	return gs

## The REDACTED state a player is allowed to receive (Golden Rule #6: never send the hidden enemy
## board to a client). Includes their own fleet + own-board powerups, their fog markers, the
## mines/drones THEY placed on the enemy board, and drone readings — but never the enemy fleet,
## the enemy's powerups, or the enemy mines hidden on the player's own board.
static func player_view(gs: GameState, player: int) -> Dictionary:
	var own := gs.boards[player]
	var enemy := gs.boards[1 - player]
	var own_ships: Array = []
	for s in own.ships:
		own_ships.append(_ship_out(s))                  # your fleet, in full
	var own_sunk: Array = []
	for s in own.sunk:
		own_sunk.append(_ship_out(s))                   # your losses, so the roster shows them ablaze
	var own_powerups: Array = []
	for p in own.powerups:
		own_powerups.append({"kind": int(p.kind), "cell": _c(p.cell)})
	var my_enemy_effects: Array = []
	for e in enemy.effects:
		if e.placer == player:                          # only the mines/drones YOU placed
			my_enemy_effects.append(_effect_out(e))
	var readings: Array = []
	for r in gs.drone_readings(player):
		readings.append({"cell": _c(r.cell), "distance": r.distance})
	return {
		"you": player,
		"your_turn": gs.current_player == player,
		"current_player": gs.current_player,
		"turn_number": gs.turn_number,
		"winner": gs.winner(),
		"reward": gs.rewards[player],                    # coins we earned (server-rolled; 0 if ongoing)
		"mine_sweeps": gs.mine_sweeps[player],
		"own_ships": own_ships,                          # (enemy mines on your board are omitted — hidden)
		"own_sunk": own_sunk,                            # your destroyed ships (for the burning roster)
		"own_powerups": own_powerups,
		"fog": _shots_out(gs.shots[player]),             # your hit/miss markers on the enemy board
		"incoming": _incoming_out(gs.incoming[player]),  # the opponent's last shots against YOU (replay)
		"my_enemy_effects": my_enemy_effects,
		"drone_readings": readings,
	}

## Rebuild the CLIENT's local match from a redacted player_view: your board is real (for moving +
## rendering), the enemy board is empty except the mines/drones YOU placed there, plus your fog.
## The client simulates its own turn on this and records the actions into a Turn; the server holds
## the true state. (The client never learns the enemy fleet — that's the whole point.)
static func decode_view(v: Dictionary) -> GameState:
	var gs := GameState.new()
	var you := int(v["you"])
	gs.current_player = you
	gs.turn_number = int(v["turn_number"])
	gs.mine_sweeps[you] = int(v["mine_sweeps"])
	var own := gs.boards[you]
	own.ships.clear()
	for sd in v["own_ships"]:
		own.ships.append(_ship_in(sd))
	own.sunk.clear()
	for sd in v.get("own_sunk", []):
		own.sunk.append(_ship_in(sd))
	for pd in v["own_powerups"]:
		own.powerups.append(Powerup.new(int(pd["kind"]) as GameEnums.PowerupKind, _v(pd["cell"])))
	own.reindex()
	var enemy := gs.boards[1 - you]
	enemy.ships.clear()
	for ed in v["my_enemy_effects"]:
		var e := _effect_in(ed)
		if e != null:
			if e is Barrage:
				(e as Barrage).caster = _find(own, &"battleship")
				e.remove_meta("caster_id")
			enemy.effects.append(e)
	gs.shots[you] = _shots_in(v["fog"])
	gs.incoming[you] = _incoming_in(v.get("incoming", {}))
	return gs

# --- boards / ships ---

static func _board_out(b: Board) -> Dictionary:
	var ships: Array = []
	for s in b.ships:
		ships.append(_ship_out(s))
	var sunk: Array = []
	for s in b.sunk:
		sunk.append(_ship_out(s))
	var effects: Array = []
	for e in b.effects:
		effects.append(_effect_out(e))
	var powerups: Array = []
	for p in b.powerups:
		powerups.append({"kind": int(p.kind), "cell": _c(p.cell)})
	return {"ships": ships, "sunk": sunk, "effects": effects, "powerups": powerups}

static func _board_in(d: Dictionary) -> Board:
	var b := Board.new()
	for sd in d["ships"]:
		b.ships.append(_ship_in(sd))
	for sd in d.get("sunk", []):
		b.sunk.append(_ship_in(sd))
	for ed in d["effects"]:
		var e := _effect_in(ed)
		if e != null:
			b.effects.append(e)
	for pd in d["powerups"]:
		b.powerups.append(Powerup.new(int(pd["kind"]) as GameEnums.PowerupKind, _v(pd["cell"])))
	return b

static func _ship_out(s: ShipInstance) -> Dictionary:
	var destroyed: Array = []
	for o in s.destroyed_offsets:
		destroyed.append(_c(o))
	return {
		"id": String(s.def.id), "owner": s.owner, "origin": _c(s.origin), "facing": int(s.facing),
		"destroyed": destroyed, "reload": s.reload_cooldown, "charge": s.charge,
		"stunned": s.stunned_turns, "suppressed": s.suppressed_turns,
	}

static func _ship_in(d: Dictionary) -> ShipInstance:
	var s := ShipInstance.create(_def(StringName(d["id"])), int(d["owner"]), _v(d["origin"]),
		int(d["facing"]) as GameEnums.Facing)
	for o in d["destroyed"]:
		s.destroyed_offsets[_v(o)] = true
	s.reload_cooldown = int(d["reload"])
	s.charge = int(d["charge"])
	s.stunned_turns = int(d["stunned"])
	s.suppressed_turns = int(d["suppressed"])
	return s

# --- effects (polymorphic) ---

static func _effect_out(e: BoardEffect) -> Dictionary:
	if e is Mine:
		var m := e as Mine
		return {"type": "mine", "placer": m.placer, "cell": _c(m.cell), "fuse": m.fuse, "spent": m.spent}
	if e is Drone:
		var dr := e as Drone
		return {"type": "drone", "placer": dr.placer, "cell": _c(dr.cell), "life": dr.life}
	if e is Barrage:
		var ba := e as Barrage
		return {"type": "barrage", "placer": ba.placer, "sector": _c(ba.sector),
			"turns_left": ba.turns_left, "attacks": ba.attacks_per_tick,
			"caster": String(ba.caster.def.id) if ba.caster != null else ""}
	return {"type": "unknown"}

static func _effect_in(d: Dictionary) -> BoardEffect:
	match String(d["type"]):
		"mine":
			var m := Mine.new(int(d["placer"]), _v(d["cell"]), int(d["fuse"]))
			m.spent = bool(d["spent"])
			return m
		"drone":
			return Drone.new(int(d["placer"]), _v(d["cell"]), int(d["life"]))
		"barrage":
			var b := Barrage.new(int(d["placer"]), _v(d["sector"]), null, int(d["turns_left"]), int(d["attacks"]))
			b.set_meta("caster_id", String(d["caster"]))   # relinked in decode() once boards exist
			return b
	return null

# --- fog of war ---

static func _shots_out(shots: Dictionary) -> Array:
	var out: Array = []
	for c in shots:
		out.append({"cell": _c(c), "hit": shots[c].hit, "turn": shots[c].turn})
	return out

static func _shots_in(arr: Array) -> Dictionary:
	var out := {}
	for r in arr:
		out[_v(r["cell"])] = {"hit": bool(r["hit"]), "turn": int(r["turn"])}
	return out

# --- incoming attack (for the defender's replay) ---

static func _incoming_out(rec: Dictionary) -> Dictionary:
	if rec.is_empty():
		return {}
	var shots: Array = []
	for s in rec.get("shots", []):
		shots.append({"cell": _c(s.cell), "hit": bool(s.hit)})
	return {"shots": shots, "turn": int(rec.get("turn", 0))}

static func _incoming_in(d) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or d.is_empty():
		return {}
	var shots: Array = []
	for s in d.get("shots", []):
		shots.append({"cell": _v(s["cell"]), "hit": bool(s["hit"])})
	return {"shots": shots, "turn": int(d.get("turn", 0))}

# --- small helpers ---

static func _c(v: Vector2i) -> Array:
	return [v.x, v.y]

static func _v(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))

static func _ship_id(s: ShipInstance) -> String:
	return String(s.def.id) if s != null else ""

static func _find(b: Board, id: StringName) -> ShipInstance:
	if id == &"":
		return null
	for s in b.ships:
		if s.def.id == id:
			return s
	return null

static func _def(id: StringName) -> ShipDef:
	for d in ShipCatalog.all():
		if d.id == id:
			return d
	return null
