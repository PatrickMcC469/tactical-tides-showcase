## Compact fleet-placement payload for online matches: a list of [ship_id, x, y, facing]. The client
## serializes its placed board with from_board() and sends it; the server applies it onto a match
## with apply(). A board with zero ships means that player hasn't placed yet (drives the "placing"
## phase — the game only begins once BOTH fleets are down).
class_name Placement
extends RefCounted

## Serialize a board's fleet to [[id, x, y, facing], ...] (JSON-friendly).
static func from_board(board: Board) -> Array:
	var out: Array = []
	for s in board.ships:
		out.append([String(s.def.id), s.origin.x, s.origin.y, int(s.facing)])
	return out

## Place a serialized fleet onto gs.boards[seat]. Skips anything malformed or that doesn't fit.
static func apply(gs: GameState, seat: int, ships: Array) -> void:
	for e in ships:
		if typeof(e) != TYPE_ARRAY or (e as Array).size() < 4:
			continue
		var def := _def(StringName(str(e[0])))
		if def == null:
			continue
		gs.boards[seat].place(ShipInstance.create(
			def, seat, Vector2i(int(e[1]), int(e[2])), int(e[3]) as GameEnums.Facing))

## True once this board has its full fleet down.
static func placed(board: Board) -> bool:
	return board.ships.size() >= ShipCatalog.all().size()

static func _def(id: StringName) -> ShipDef:
	for d in ShipCatalog.all():
		if d.id == id:
			return d
	return null
