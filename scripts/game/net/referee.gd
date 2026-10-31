## The authoritative server referee (Golden Rule #6: never trust the client). Takes the current
## match state + a submitted Turn and RE-RUNS every action through the rules brain — begin_move /
## try_translate / try_rotate for movement, and the ability execute() path for special + fire.
## Anything the brain rejects (off-board, collision, out of points, ship on cooldown, not charged,
## wrong player) fails the whole turn, so a tampered client can't produce an illegal outcome.
class_name Referee
extends RefCounted

## Validate + apply a turn. Returns {ok:bool, reason:String, hits:Array, sunk:Array}.
static func apply(gs: GameState, turn: Turn) -> Dictionary:
	if turn.player != gs.current_player:
		return _fail("not this player's turn")

	# 1) Movement — optional, one ship, replayed step by step.
	if String(turn.move_ship) != "":
		var ship := _own_ship(gs, gs.current_player, turn.move_ship)
		if ship == null or not gs.begin_move(ship):
			return _fail("illegal move ship '%s'" % turn.move_ship)
		for s in turn.move_steps:
			var ok := false
			match s:
				"F": ok = gs.try_translate(1)
				"B": ok = gs.try_translate(-1)
				"R": ok = gs.try_rotate()
			if not ok:
				return _fail("illegal move step '%s'" % s)

	# 1b) Targeted powerups grabbed during the move — apply the player's chosen targets. Lenient:
	# an invalid pick (no matching pending powerup) simply does nothing, it can't corrupt the state.
	for pick in turn.powerup_picks:
		match int(pick.get("kind", -1)):
			GameEnums.PowerupKind.RAPID_RELOAD:
				gs.resolve_rapid_reload(gs.current_player,
					_own_ship(gs, gs.current_player, StringName(pick.get("ship", ""))))
			GameEnums.PowerupKind.MINE_SWEEP:
				var sec: Array = pick.get("sector", [0, 0])
				gs.resolve_mine_sweep(gs.current_player, Vector2i(int(sec[0]), int(sec[1])))

	# 2) Special — optional.
	if String(turn.special_id) != "":
		var sr := _resolve(gs, turn.special_id, turn.special_aim, turn.special_orient, true)
		if not sr.ok:
			return sr

	# 3) Fire — required (every turn takes a shot).
	if String(turn.fire_id) == "":
		return _fail("a turn must include a shot")
	var fr := _resolve(gs, turn.fire_id, turn.fire_aim, turn.fire_orient, false)
	if not fr.ok:
		return fr

	gs.end_turn()
	var won := gs.winner()
	if won != -1 and gs.rewards[won] == 0:   # decide the payout once, server-side (anti-cheat)
		gs.rewards[won] = Rewards.roll(gs.rng)
		gs.rewards[1 - won] = Rewards.CONSOLATION
	return {"ok": true, "reason": "", "hits": fr.hits, "sunk": fr.sunk,
		"winner": won, "reward": gs.rewards[turn.player]}

## Resolve one special/fire: gate it exactly like the turn screen does, then execute via the brain.
static func _resolve(gs: GameState, id: StringName, aim: Array, orient: int, is_special: bool) -> Dictionary:
	var player: int = gs.current_player
	var ship := _acting_ship(gs, player, id, is_special)
	if is_special:
		if ship == null or not ship.charge_ready() or gs.has_used_special:
			return _fail("special '%s' unavailable" % id)
	elif id != &"emergency_shot":
		if ship == null or not ship.can_fire() or gs.has_fired:
			return _fail("fire '%s' unavailable" % id)
	else:
		if not gs.needs_emergency_shot(player) or gs.has_fired:
			return _fail("emergency shot unavailable")
	if aim.is_empty():
		return _fail("no target for '%s'" % id)

	var ctx := ActionResolver.context(gs, player, ship, id, aim, orient)
	var res := AbilityRegistry.get_ability(id).execute(ctx)
	gs.record_shots(player, res)
	# Log it as incoming fire against the defender so they can replay it on their turn (the required
	# fire always; an attacking special only when it actually connects — skip placements/scans).
	if not is_special or not res.hits.is_empty():
		gs.record_incoming(1 - player, res)
	if is_special:
		if ship != null:
			ship.charge = 0
		gs.has_used_special = true
	else:
		if ship != null:
			ship.reload_cooldown = Tiers.reload_turns(ship.def.reload)
		gs.has_fired = true
	return {"ok": true, "reason": "", "hits": res.hits, "sunk": res.sunk}

static func _own_ship(gs: GameState, player: int, ship_id: StringName) -> ShipInstance:
	for s in gs.boards[player].ships:
		if s.def.id == ship_id and s.is_alive():
			return s
	return null

## The ship that owns a given fire/special ability (ids are unique per ship type). Null for
## Emergency Shot, which has no ship.
static func _acting_ship(gs: GameState, player: int, ability_id: StringName, is_special: bool) -> ShipInstance:
	for s in gs.boards[player].ships:
		if not s.is_alive():
			continue
		if is_special and s.def.special_id == ability_id:
			return s
		if not is_special and s.def.fire_id == ability_id:
			return s
	return null

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "hits": [], "sunk": []}
