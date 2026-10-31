## The Battleship's normal fire: TWO plus (+) blasts in one attack. Pick two spots; each hits a
## spot plus its 4 orthogonal neighbors on the enemy board.
class_name CrossShot
extends Ability

var blasts := 2

func _init() -> void:
	id = &"cross_shot"
	display_name = "Twin Cross"
	kind = GameEnums.AbilityKind.FIRE
	target_kind = GameEnums.TargetKind.MULTI_SPOT

func describe() -> String:
	return "Hit TWO plus (+) patterns — pick %d spots on the enemy board." % blasts

func execute(ctx: ActionContext) -> ActionResult:
	var cells: Array[Vector2i] = []
	for center in ctx.cells:
		cells.append_array(Blast.plus_cells(center))
	return ctx.board.apply_hits(cells)
