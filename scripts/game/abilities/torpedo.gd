## Fire a torpedo in a straight line (Submarine). It travels up to `range_spots` and only
## damages the FIRST occupied spot it reaches; that ship is also stopped for one turn.
class_name Torpedo
extends Ability

var range_spots: int = 5   # the selected spot + 4 dragged = 5 cells total
var stuns_turns: int = 1

func _init(p_range: int = 5) -> void:
	id = &"torpedo"
	display_name = "Torpedo"
	kind = GameEnums.AbilityKind.FIRE
	range_spots = p_range

func describe() -> String:
	return ("Pick a spot and drag a line up to %d long. Damages only the first ship hit, "
		+ "and stops it for %d turn.") % [range_spots, stuns_turns]

func execute(ctx: ActionContext) -> ActionResult:
	# Build the travel path, then damage the FIRST occupied cell and stop that ship.
	var path: Array[Vector2i] = []
	for i in range_spots:
		var cell := ctx.line_start + ctx.line_dir * i
		if not Sectors.in_bounds(cell):
			break
		path.append(cell)
	for cell in path:
		if ctx.board.occupant(cell) != null:
			var res := ctx.board.apply_hits([cell])
			var hit_at: Array[Vector2i] = [cell]
			res.targeted = hit_at          # ONE impact where it strikes — fires like a single torpedo, not a volley
			for ship in res.ships_hit:
				ship.stunned_turns = maxi(ship.stunned_turns, stuns_turns)
			return res
	var miss := ActionResult.new()
	if not path.is_empty():
		var end_at: Array[Vector2i] = [path[path.size() - 1]]
		miss.targeted = end_at             # a single splash where the torpedo ran out, not one per cell
	return miss
