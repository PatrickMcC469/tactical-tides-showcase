## Aircraft Carrier special. A bombing run that hits a full row AND column through one point.
class_name AirStrafe
extends Ability

func _init() -> void:
	id = &"air_strafe"
	display_name = "Air Strafe"
	kind = GameEnums.AbilityKind.SPECIAL

func describe() -> String:
	return "Pick a point; a bombing run hits its entire row and column (an X & Y line)."

func execute(ctx: ActionContext) -> ActionResult:
	var cells: Array[Vector2i] = []
	for x in Sectors.BOARD_SIZE:
		cells.append(Vector2i(x, ctx.point.y))          # full row
	for y in Sectors.BOARD_SIZE:
		if y != ctx.point.y:
			cells.append(Vector2i(ctx.point.x, y))      # full column
	return ctx.board.apply_hits(cells)
