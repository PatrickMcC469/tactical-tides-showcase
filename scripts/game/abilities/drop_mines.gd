## Destroyer special. Lay three mines at once (same mine rules as the basic Mine fire).
class_name DropMines
extends Ability

var count: int = 3

func _init() -> void:
	id = &"drop_mines"
	display_name = "Drop Three Mines"
	kind = GameEnums.AbilityKind.SPECIAL

func describe() -> String:
	return "Lay %d hidden mines at once." % count

func execute(ctx: ActionContext) -> ActionResult:
	var res := ActionResult.new()
	var placed := 0
	for cell in ctx.cells:
		var mine := ctx.board.try_place_mine(ctx.acting_player, cell, 3)
		if mine == null:
			continue   # over the cap or cell already used — skip this one
		placed += 1
		if ctx.board.is_covered(mine.cell):
			var det := mine.detonate(ctx.board)
			res.hits.append_array(det.hits)
			res.sunk.append_array(det.sunk)
	ctx.board.prune_effects()
	res.message = "Dropped %d mine(s)." % placed
	res.targeted.assign(res.hits)   # reveal + explode any cell where a mine detonated on a ship
	return res
