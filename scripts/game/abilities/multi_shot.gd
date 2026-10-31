## Fire at several freely-chosen separate spots in one action (Aircraft Carrier: 4 spots).
class_name MultiShot
extends Ability

var shots: int = 4

func _init(p_shots: int = 4) -> void:
	id = &"multi_shot"
	display_name = "Multi-Shot"
	kind = GameEnums.AbilityKind.FIRE
	shots = p_shots

func describe() -> String:
	return "Choose %d separate spots and fire at all of them." % shots

func execute(ctx: ActionContext) -> ActionResult:
	return ctx.board.apply_hits(ctx.cells)
