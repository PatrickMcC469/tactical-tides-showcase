## Fire a straight line of shots — horizontal OR vertical (Cruiser: 3 in a row).
class_name LineShot
extends Ability

var length: int = 3

func _init(p_length: int = 3) -> void:
	id = &"line_shot"
	display_name = "Line Shot"
	kind = GameEnums.AbilityKind.FIRE
	length = p_length

func describe() -> String:
	return "Fire %d in a row — horizontal or vertical." % length

func execute(ctx: ActionContext) -> ActionResult:
	return ctx.board.apply_hits(ctx.cells)
