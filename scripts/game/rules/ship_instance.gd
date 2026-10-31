## A ship's LIVE state during a match: which ShipDef it is, who owns it, where it sits, its
## current health, and its cooldown/charge/status timers. The static stats live on `def`;
## everything that changes during play lives here.
class_name ShipInstance
extends RefCounted

var def: ShipDef
var owner: int                      # 0 or 1
var origin: Vector2i                # anchor cell; footprint extends along `facing`
var facing: GameEnums.Facing = GameEnums.Facing.NORTH

var destroyed_offsets: Dictionary = {}  # shape offsets that have been blown off (set)
var reload_cooldown: int = 0        # turns until it can fire again (0 = ready)
var charge: int = 0                 # accrues +1 per owner's turn; special ready at threshold
var stunned_turns: int = 0          # can't move while > 0 (e.g. hit by a torpedo)
var suppressed_turns: int = 0       # can't attack while > 0 (e.g. hit by a drone shot)

static func create(p_def: ShipDef, p_owner: int, p_origin: Vector2i, p_facing: GameEnums.Facing) -> ShipInstance:
	var s := ShipInstance.new()
	s.def = p_def
	s.owner = p_owner
	s.origin = p_origin
	s.facing = p_facing
	return s

## The cells this ship currently occupies: its footprint shape rotated by `facing` and
## offset to `origin`.
## The ALIVE cells this ship occupies (destroyed cells are gone). Used for occupancy & targeting.
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off in def.shape:
		if not destroyed_offsets.has(off):
			out.append(origin + _rotate(off))
	return out

## The FULL footprint (every cell, damaged or not) — used by mines & drones, which don't care
## whether a particular cell is still intact ("any space, damaged or not").
func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off in def.shape:
		out.append(origin + _rotate(off))
	return out

## The footprint this ship WOULD occupy at a hypothetical origin (same facing). For move previews.
func footprint_at(o: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off in def.shape:
		out.append(o + _rotate(off))
	return out

## The board cells that have been blown off (for drawing them as damaged, not gone).
func destroyed_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off in destroyed_offsets:
		out.append(origin + _rotate(off))
	return out

## Remaining health = remaining cells.
func hp() -> int:
	return def.shape.size() - destroyed_offsets.size()

## Blow off the cell at an absolute board position (one point of damage).
func destroy_cell(abs_cell: Vector2i) -> void:
	for off in def.shape:
		if origin + _rotate(off) == abs_cell:
			destroyed_offsets[off] = true
			return

## Restore one destroyed cell (Repair powerup). Returns false if nothing was damaged.
func repair_one() -> bool:
	if destroyed_offsets.is_empty():
		return false
	destroyed_offsets.erase(destroyed_offsets.keys()[0])
	return true

## Rotate a shape offset by the ship's facing (90° steps; NORTH = authored orientation).
func _rotate(off: Vector2i) -> Vector2i:
	var r := off
	for _i in int(facing):  # NORTH=0, EAST=1, SOUTH=2, WEST=3 quarter-turns
		r = Vector2i(-r.y, r.x)
	return r

## Unit vector pointing "forward" (toward the bow) given the current facing.
func forward_vector() -> Vector2i:
	return _rotate(Vector2i(0, -1))

## Board cell the ship currently pivots around (its middle cell).
func pivot_board() -> Vector2i:
	return origin + _rotate(def.pivot)

## Turn 90° clockwise, keeping the pivot cell fixed on the board.
func apply_rotation() -> void:
	var p := pivot_board()
	facing = ((int(facing) + 1) % 4) as GameEnums.Facing
	origin = p - _rotate(def.pivot)

func is_alive() -> bool:
	return hp() > 0

func can_fire() -> bool:
	return is_alive() and reload_cooldown == 0 and suppressed_turns == 0

func charge_ready() -> bool:
	return charge >= Tiers.charge_threshold(def.charge)

## Called at the start of this ship owner's turn: tick down timers and accrue charge.
func tick_turn_start() -> void:
	if reload_cooldown > 0:
		reload_cooldown -= 1
	if stunned_turns > 0:
		stunned_turns -= 1
	if suppressed_turns > 0:
		suppressed_turns -= 1
	if not charge_ready():
		charge += 1
