## The 20x20 playing field: tracks which ship occupies each cell, and answers sector queries
## (the basis for Active Radar and Barrage Zone, which operate on whole 5x5 zones).
class_name Board
extends RefCounted

var ships: Array[ShipInstance] = []    # the LIVING fleet (sunk ships are moved out, see `sunk`)
var sunk: Array[ShipInstance] = []     # wrecks — kept so the fleet roster can show them ablaze
var effects: Array[BoardEffect] = []   # mines/drones/barrage the OPPONENT placed on this board
var powerups: Array[Powerup] = []      # collectibles for THIS board's owner
var _occupant: Dictionary = {}   # Vector2i -> ShipInstance

const MAX_MINES := 5

func occupant(cell: Vector2i) -> ShipInstance:
	return _occupant.get(cell, null)

func is_free(cell: Vector2i) -> bool:
	return Sectors.in_bounds(cell) and not _occupant.has(cell)

## Place a ship. Returns false (and changes nothing) if any cell is off-board or taken.
func place(ship: ShipInstance) -> bool:
	var cells := ship.cells()
	for c in cells:
		if not is_free(c):
			return false
	for c in cells:
		_occupant[c] = ship
	if ship not in ships:
		ships.append(ship)
	return true

func remove(ship: ShipInstance) -> void:
	for c in ship.cells():
		if _occupant.get(c) == ship:
			_occupant.erase(c)
	ships.erase(ship)

# --- Effects (mines / drones / barrage) ---

func add_effect(effect: BoardEffect) -> void:
	effects.append(effect)

## The effect sitting on `cell`, if any (for no-stacking checks).
func effect_at(cell: Vector2i) -> BoardEffect:
	for e in effects:
		if e.occupies(cell):
			return e
	return null

## How many mines a given player has live on this board.
func mine_count(placer: int) -> int:
	var n := 0
	for e in effects:
		if e is Mine and e.placer == placer:
			n += 1
	return n

## Place a mine, honoring the 5-mine cap and no-stacking. Returns the Mine or null if refused.
func try_place_mine(placer: int, cell: Vector2i, fuse: int) -> Mine:
	if mine_count(placer) >= MAX_MINES or effect_at(cell) != null or not Sectors.in_bounds(cell):
		return null
	var mine := Mine.new(placer, cell, fuse)
	add_effect(mine)
	return mine

## Is `cell` under any ship's full footprint (damaged or not)?
func is_covered(cell: Vector2i) -> bool:
	for ship in ships:
		if cell in ship.all_cells():
			return true
	return false

# --- Powerups (collectibles for this board's owner) ---

func powerup_at(cell: Vector2i) -> Powerup:
	for p in powerups:
		if p.cell == cell:
			return p
	return null

## A cell is valid for a powerup spawn only if it's empty: in bounds, no ship, no effect, no powerup.
func is_spawn_free(cell: Vector2i) -> bool:
	return Sectors.in_bounds(cell) and not is_covered(cell) \
		and effect_at(cell) == null and powerup_at(cell) == null

## A random empty cell for a spawn (null Vector2i guard via the bool). Returns false if none found.
func random_spawn_cell(rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in 200:
		var c := Vector2i(rng.randi_range(0, Sectors.BOARD_SIZE - 1), rng.randi_range(0, Sectors.BOARD_SIZE - 1))
		if is_spawn_free(c):
			return c
	return Vector2i(-1, -1)   # board implausibly full

## Defuse (safely remove) every mine & drone in a sector — the Mine Sweep powerup. Returns the count.
func defuse_sector(sector: Vector2i) -> int:
	var removed := 0
	var kept: Array[BoardEffect] = []
	for e in effects:
		var in_sector := false
		if e is Mine:
			in_sector = Sectors.sector_of((e as Mine).cell) == sector
		elif e is Drone:
			in_sector = Sectors.sector_of((e as Drone).cell) == sector
		if in_sector:
			removed += 1
		else:
			kept.append(e)
	effects = kept
	return removed

## Drop effects that have finished (exploded mines, expired drones, ended barrages).
func prune_effects() -> void:
	var kept: Array[BoardEffect] = []
	for e in effects:
		if not e.is_done():
			kept.append(e)
	effects = kept

## Rebuild the occupancy map from every ship's current (alive) cells. Call after ships move.
func reindex() -> void:
	_occupant.clear()
	for ship in ships:
		for c in ship.cells():
			_occupant[c] = ship

## Resolve damage against a set of target cells: blow off each hit cell, sink any ship that
## loses its last cell, and report what happened. The shared core every attack runs through.
func apply_hits(target_cells: Array[Vector2i]) -> ActionResult:
	var res := ActionResult.new()
	res.targeted = target_cells
	for c in target_cells:
		var ship := occupant(c)
		if ship == null:
			continue
		ship.destroy_cell(c)
		_occupant.erase(c)
		res.hits.append(c)
		if ship not in res.ships_hit:
			res.ships_hit.append(ship)
		if not ship.is_alive() and ship in ships:
			ships.erase(ship)
			sunk.append(ship)        # keep the wreck for the fleet roster (it renders ablaze)
			res.sunk.append(ship)
	return res

## Find a ship by id among BOTH the living fleet and the sunk wrecks — for the fleet-roster UI, which
## must still show (and set aflame) a destroyed ship even after it leaves `ships`.
func find_by_id(id: StringName) -> ShipInstance:
	for s in ships:
		if s.def.id == id:
			return s
	for s in sunk:
		if s.def.id == id:
			return s
	return null

## Ships on THIS board that have at least one cell inside `sector`.
func ships_in_sector(sector: Vector2i) -> Array[ShipInstance]:
	var found: Array[ShipInstance] = []
	for ship in ships:
		for c in ship.cells():
			if Sectors.sector_of(c) == sector:
				found.append(ship)
				break
	return found

## How many ships sit (at least partly) in a sector. The Active Radar answer (run on the enemy board).
func count_ships_in_sector(sector: Vector2i) -> int:
	return ships_in_sector(sector).size()
