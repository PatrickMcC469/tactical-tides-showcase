## The match "brain": holds BOTH players' boards, whose turn it is, and the per-turn flow.
##
## This is Battleship-style: each player has their OWN separate 20x20 board with their own
## fleet. You fire at coordinates on the ENEMY's board (which you can't see) — never your own —
## so friendly fire is impossible. The hidden enemy board is exactly why the authoritative
## server matters (Golden Rule #6): a client must not be able to read the opponent's board.
##
## Turn flow (notebook): move ONE ship -> optionally a special (if charged) -> choose a ship
## to fire -> Fire. Then end the turn.
class_name GameState
extends RefCounted

var boards: Array[Board] = []      # boards[0] = Player 0's fleet, boards[1] = Player 1's fleet
var current_player: int = 0
var turn_number: int = 1

# Per-turn action gates (reset each turn).
var has_moved: bool = false
var has_used_special: bool = false
var has_fired: bool = false

# Movement state for the one ship being moved this turn.
var moving_ship: ShipInstance = null
var move_points_left: int = 0
var used_free_rotation: bool = false

# Powerups.
var rng := RandomNumberGenerator.new()
var mine_sweeps: Array[int] = [0, 0]   # (legacy, used by board_demo tests; live flow uses pending_picks)
# Targeted powerups just collected this turn, awaiting the player to pick a target (a friendly ship
# for Rapid Reload, a sector for Mine Sweep). Not banked — cleared at the start of each turn.
var pending_picks: Array[int] = []
var last_collected: Array[int] = []   # powerup kinds grabbed in the last move, for the UI's popup

# Fog of war: each player's knowledge of the enemy board — cell -> true(hit)/false(miss).
var shots: Array[Dictionary] = [{}, {}]

# The opponent's most recent attack against each player, for the defender's "incoming fire" replay
# when they open their turn online. incoming[victim] = {shots:[{cell,hit}], turn}. Overwritten each
# new attack; the very first turn has none.
var incoming: Array[Dictionary] = [{}, {}]

# Coins each player earned this match, rolled SERVER-SIDE (Referee) when the match ends; 0 while
# it's ongoing. rewards[winner] = wheel roll, rewards[loser] = consolation.
var rewards: Array[int] = [0, 0]

const POWERUP_EVERY := 4

func _init() -> void:
	boards = [Board.new(), Board.new()]
	rng.randomize()

## A player's own board (where their ships live and move).
func own_board(player: int) -> Board:
	return boards[player]

## The board a player attacks / scans (the opponent's).
func enemy_board(player: int) -> Board:
	return boards[1 - player]

## Begin the current player's turn: tick their own ships and reset the action gates.
func begin_turn() -> void:
	has_moved = false
	has_used_special = false
	has_fired = false
	moving_ship = null
	move_points_left = 0
	used_free_rotation = false
	pending_picks.clear()   # targeted powerups must be used the turn you grab them, or lost
	last_collected.clear()
	for ship in _player_ships(current_player):
		ship.tick_turn_start()
	# Enemy-placed effects on this player's own board act at their turn start (mine fuses, barrage).
	_effects_victim_turn_start(current_player)
	# This player's own effects on the enemy board tick at their turn start (drone lifespans).
	_effects_placer_turn_start(current_player)
	# Every 4 turns, a random powerup spawns for both players (same type, independent empty cells).
	if is_powerup_turn():
		_spawn_powerups()

func end_turn() -> void:
	# Enemy-placed effects on the current player's board act at their turn end (barrage volley).
	_effects_victim_turn_end(current_player)
	current_player = 1 - current_player
	turn_number += 1
	begin_turn()

## True on turns where powerups appear (mirrored to both players — see README).
func is_powerup_turn() -> bool:
	return turn_number % POWERUP_EVERY == 0

# --- Movement (one ship per turn; moving is optional) ---

## Choose the ship to move this turn. Fails if a ship was already chosen, it's not yours,
## it's sunk, or it's stunned. Sets up its movement-point budget.
func begin_move(ship: ShipInstance) -> bool:
	if has_moved or ship.owner != current_player or not ship.is_alive() or ship.stunned_turns > 0:
		return false
	moving_ship = ship
	move_points_left = Tiers.movement_points(ship.def.movement)
	used_free_rotation = false
	has_moved = true
	return true

## Cells a single translate covers: ceil(length / 2) (Battleship length 5 -> 3).
func move_step_distance(ship: ShipInstance) -> int:
	return (ship.def.length + 1) / 2

## Spend one point sliding forward (+1) or backward (-1) along the ship's axis.
## Sub-steps cell-by-cell so a mine anywhere in the swept path is caught immediately.
func try_translate(direction_sign: int) -> bool:
	if moving_ship == null or move_points_left <= 0:
		return false
	var ship := moving_ship
	var board := boards[ship.owner]
	var step := move_step_distance(ship)
	var dir := ship.forward_vector() * direction_sign
	var start_origin := ship.origin
	for s in range(1, step + 1):
		ship.origin = start_origin + dir * s
		for c in ship.cells():
			if not Sectors.in_bounds(c) or _blocked_by_other(board, ship, c):
				ship.origin = start_origin   # can't complete the move -> revert, nothing spent
				return false
		# Mid-sweep hazard: a mine under the ship at THIS step blows immediately; the ship
		# keeps moving if it survives and has range left (no guaranteed catch).
		board.reindex()   # occupancy must reflect THIS step before the blast resolves damage
		_detonate_mines_under(ship, board)
		if not ship.is_alive():
			break
		_collect_powerups_under(ship, board)   # beneficial pickups along the path
	move_points_left -= 1
	board.reindex()
	board.prune_effects()
	return true

## Turn 90° around the pivot, if it fits and there's budget.
func try_rotate() -> bool:
	if moving_ship == null:
		return false
	var ship := moving_ship
	if ship.def.movement == GameEnums.Movement.SLOW and move_points_left <= 0:
		return false
	var cost := rotation_cost(ship)
	if cost > move_points_left:
		return false
	var board := boards[ship.owner]
	var old_origin := ship.origin
	var old_facing := ship.facing
	ship.apply_rotation()
	for c in ship.cells():
		if not Sectors.in_bounds(c) or _blocked_by_other(board, ship, c):
			ship.origin = old_origin         # can't turn off-board / into a ship -> revert
			ship.facing = old_facing
			return false
	move_points_left -= cost
	used_free_rotation = true
	board.reindex()
	return true

## What a 90° rotation costs this ship right now (notebook tier rules).
func rotation_cost(ship: ShipInstance) -> int:
	match ship.def.movement:
		GameEnums.Movement.SLOW:
			return move_points_left           # eats ALL remaining movement
		GameEnums.Movement.MED:
			return 1
		_:                                     # FAST / AGILE: first rotation free, then 1 each
			return 0 if not used_free_rotation else 1

# --- Firing / emergency-shot rule ---

## Can this player fire with any of their own ships this turn?
func can_player_fire(player: int) -> bool:
	for ship in _player_ships(player):
		if ship.can_fire():
			return true
	return false

## If a player has no ship able to fire, they get the Emergency Shot fallback (no dead turns).
func needs_emergency_shot(player: int) -> bool:
	return not can_player_fire(player)

## The winning player (0 or 1) once the other's whole fleet is sunk; -1 if the match is ongoing.
func winner() -> int:
	var p0_alive := not _player_ships(0).is_empty()
	var p1_alive := not _player_ships(1).is_empty()
	if p0_alive and not p1_alive:
		return 0
	if p1_alive and not p0_alive:
		return 1
	return -1

# --- helpers ---

func _player_ships(player: int) -> Array[ShipInstance]:
	var out: Array[ShipInstance] = []
	for ship in boards[player].ships:
		if ship.is_alive():
			out.append(ship)
	return out

## Is `cell` occupied by a DIFFERENT ship on this board (own-fleet collision)?
func _blocked_by_other(board: Board, ship: ShipInstance, cell: Vector2i) -> bool:
	for other in board.ships:
		if other != ship and cell in other.cells():
			return true
	return false

## Detonate any mine whose cell is under the ship's full footprint right now.
func _detonate_mines_under(ship: ShipInstance, board: Board) -> void:
	var footprint := ship.all_cells()
	for e in board.effects.duplicate():
		if e is Mine and not e.is_done() and (e as Mine).cell in footprint:
			(e as Mine).detonate(board)

## Run enemy-placed effects on `victim`'s own board at the start of their turn.
func _effects_victim_turn_start(victim: int) -> void:
	var board := boards[victim]
	for e in board.effects.duplicate():
		e.on_victim_turn_start(self, board)
	board.reindex()
	board.prune_effects()

## Run enemy-placed effects on `victim`'s own board at the end of their turn (barrage volley).
func _effects_victim_turn_end(victim: int) -> void:
	var board := boards[victim]
	for e in board.effects.duplicate():
		e.on_victim_turn_end(self, board)
	board.reindex()
	board.prune_effects()

## Tick the placer's own effects (drones) sitting on the enemy board at their turn start.
func _effects_placer_turn_start(placer: int) -> void:
	var board := boards[1 - placer]
	for e in board.effects.duplicate():
		if e.placer == placer:
			e.on_placer_turn_start(self)
	board.prune_effects()

## Recon readings the placer sees: each of their drones on the enemy board + its distance.
func drone_readings(placer: int) -> Array[Dictionary]:
	var board := boards[1 - placer]
	var out: Array[Dictionary] = []
	for e in board.effects:
		if e is Drone and e.placer == placer:
			out.append({"cell": (e as Drone).cell, "distance": (e as Drone).distance_to_nearest(board)})
	return out

# --- Powerups ---

## Spawn one random powerup type for BOTH players, each at an independent random empty cell.
func _spawn_powerups() -> void:
	var kind := rng.randi_range(0, 4) as GameEnums.PowerupKind   # same type for both (fairness)
	for b in boards:
		var cell := b.random_spawn_cell(rng)
		if cell != Vector2i(-1, -1):
			b.powerups.append(Powerup.new(kind, cell))

## Collect any powerup a moving ship's footprint now covers (applies to that ship).
func _collect_powerups_under(ship: ShipInstance, board: Board) -> void:
	var footprint := ship.all_cells()
	var kept: Array[Powerup] = []
	for p in board.powerups:
		if p.cell in footprint:
			last_collected.append(p.kind)   # for the UI's pickup popup
			_apply_powerup(p, ship)
		else:
			kept.append(p)
	board.powerups = kept

func _apply_powerup(p: Powerup, ship: ShipInstance) -> void:
	match p.kind:
		GameEnums.PowerupKind.RAPID_RELOAD, GameEnums.PowerupKind.MINE_SWEEP:
			pending_picks.append(p.kind)     # player picks a target this turn (resolve_* below)
		GameEnums.PowerupKind.REPAIR:
			ship.repair_one()                # the rest apply immediately to the collecting ship
		GameEnums.PowerupKind.MOVEMENT:
			move_points_left += 1            # collected mid-move: extra point to keep going
		GameEnums.PowerupKind.OVERCLOCK:
			ship.charge += 1                 # one step closer to its special

## Markers fade over this many of the OWNER's turns, then disappear (stale intel — ships move).
const MARKER_LIFETIME := 3

## Record a fire result into `player`'s fog-of-war knowledge: cell -> {hit, turn}.
func record_shots(player: int, result: ActionResult) -> void:
	for c in result.targeted:
		shots[player][c] = {"hit": c in result.hits, "turn": turn_number}

## Record an attack against `victim` so their next turn can replay it as incoming fire. Accumulates
## across the attacker's turn (special + fire), and resets when a newer attack turn arrives.
func record_incoming(victim: int, result: ActionResult) -> void:
	var rec: Dictionary = incoming[victim]
	if rec.get("turn", -1) != turn_number:
		rec = {"shots": [], "turn": turn_number}
		incoming[victim] = rec
	for c in result.targeted:
		rec.shots.append({"cell": c, "hit": c in result.hits})

## The markers `player` should currently see, with a fade alpha by age. Prunes expired ones.
## Returns cell -> {hit: bool, alpha: float}.
func visible_shots(player: int) -> Dictionary:
	var out := {}
	var stale: Array = []
	for c in shots[player]:
		var rec: Dictionary = shots[player][c]
		var own_age := (turn_number - int(rec.turn)) / 2   # both are this player's turns
		if own_age >= MARKER_LIFETIME:
			stale.append(c)
		else:
			out[c] = {"hit": rec.hit, "alpha": maxf(1.0 - own_age / float(MARKER_LIFETIME), 0.3)}
	for c in stale:
		shots[player].erase(c)
	return out

## Spend a banked Mine Sweep: defuse all mines & drones in a sector of your OWN board. Returns count.
func use_mine_sweep(player: int, sector: Vector2i) -> int:
	if mine_sweeps[player] <= 0:
		return 0
	mine_sweeps[player] -= 1
	return boards[player].defuse_sector(sector)

## The next targeted powerup awaiting a pick this turn, or -1 (drives the UI's pick prompt).
func next_pending_pick() -> int:
	return int(pending_picks[0]) if not pending_picks.is_empty() else -1

## Resolve a pending Rapid Reload onto a chosen friendly ship (−1 to its reload cooldown).
func resolve_rapid_reload(player: int, ship: ShipInstance) -> bool:
	var i := pending_picks.find(GameEnums.PowerupKind.RAPID_RELOAD)
	if i == -1 or ship == null or ship.owner != player or not ship.is_alive():
		return false
	pending_picks.remove_at(i)
	ship.reload_cooldown = maxi(0, ship.reload_cooldown - 1)
	return true

## Resolve a pending Mine Sweep on a chosen sector of your own board. Returns how many were defused.
func resolve_mine_sweep(player: int, sector: Vector2i) -> int:
	var i := pending_picks.find(GameEnums.PowerupKind.MINE_SWEEP)
	if i == -1:
		return -1
	pending_picks.remove_at(i)
	return boards[player].defuse_sector(sector)

