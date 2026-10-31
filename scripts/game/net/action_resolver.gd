## Turns a chosen ability + aim inputs (tapped cells + orientation) into the cells it covers and
## the ActionContext its execute() needs. Lives in the brain so the CLIENT (preview/aim) and the
## SERVER referee resolve a shot IDENTICALLY — the server must reach the same cells the client did.
class_name ActionResolver
extends RefCounted

## N, E, S, W — index matches the UI's aim-orientation for line/torpedo.
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## How many spots an ability lets you tap.
static func max_taps(id: StringName) -> int:
	match id:
		&"multi_shot": return 4
		&"drop_mines", &"rolling_barrage": return 3
		&"deploy_drones", &"cross_shot": return 2
	return 1

## Abilities whose aim has an orientation (H/V or a direction).
static func needs_aim(id: StringName) -> bool:
	return id == &"line_shot" or id == &"torpedo" or id == &"rolling_barrage"

## Clamp aim to the number of spots the ability actually allows. The client UI limits taps, but the
## authoritative resolver MUST enforce it too (Golden Rule #6) — otherwise a tampered client could
## submit an oversized aim array and fire far more cells than the ability permits. Both client and
## server go through here, so they stay identical.
static func _capped(id: StringName, aim: Array) -> Array:
	var m := max_taps(id)
	return aim.slice(0, m) if aim.size() > m else aim

## The full set of cells an ability covers, for preview + server-side re-check.
static func cells_for(id: StringName, aim: Array, orient: int) -> Array[Vector2i]:
	if aim.is_empty():
		return []
	aim = _capped(id, aim)
	match id:
		&"cross_shot":
			var crosses: Array[Vector2i] = []
			for p in aim:
				crosses.append_array(Blast.plus_cells(p))
			return crosses
		&"multi_shot", &"drop_mines", &"deploy_drones":
			var a: Array[Vector2i] = []
			a.assign(aim)
			return a
		&"line_shot":
			return _line(aim[0], orient, 3)
		&"torpedo":
			return _line_dir(aim[0], DIRS[orient], 5)
		&"air_strafe":
			return _row_col(aim[0])
		&"barrage_zone", &"active_radar":
			return Sectors.cells_in_sector(Sectors.sector_of(aim[0]))
		&"rolling_barrage":
			var out: Array[Vector2i] = []
			for p in aim:
				out.append_array(_line(p, orient, 3))
			return out
	return [aim[0]]

## Build the ActionContext an ability resolves against (attacks/scans hit the ENEMY board).
static func context(gs: GameState, player: int, ship: ShipInstance, id: StringName,
		aim: Array, orient: int) -> ActionContext:
	var ctx := ActionContext.new()
	ctx.state = gs
	ctx.board = gs.enemy_board(player)
	ctx.acting_player = player
	ctx.acting_ship = ship
	aim = _capped(id, aim)   # enforce the per-ability spot limit server-side too
	match id:
		&"cross_shot":
			ctx.cells.assign(aim)
		&"multi_shot", &"line_shot", &"drop_mines", &"deploy_drones", &"rolling_barrage":
			ctx.cells = cells_for(id, aim, orient)
		&"torpedo":
			ctx.line_start = aim[0]
			ctx.line_dir = DIRS[orient]
		&"barrage_zone", &"active_radar":
			ctx.sector = Sectors.sector_of(aim[0])
		_:
			ctx.point = aim[0]
	return ctx

static func _line(start: Vector2i, orient: int, n: int) -> Array[Vector2i]:
	var axis := Vector2i(1, 0) if orient % 2 == 0 else Vector2i(0, 1)
	var out: Array[Vector2i] = []
	for i in n:
		out.append(start + axis * i)
	return out

static func _line_dir(start: Vector2i, dir: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in n:
		out.append(start + dir * i)
	return out

static func _row_col(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in Sectors.BOARD_SIZE:
		out.append(Vector2i(x, c.y))
	for y in Sectors.BOARD_SIZE:
		if y != c.y:
			out.append(Vector2i(c.x, y))
	return out
