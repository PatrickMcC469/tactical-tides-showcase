## A single targeted shot. Optionally suppresses the target's attack next turn
## (the Drone Ship's fire does this; a plain battleship shot does not).
class_name SingleShot
extends Ability

var suppresses_target: bool = false

func _init(p_suppresses: bool = false) -> void:
	id = &"single_shot"
	display_name = "Single Shot"
	kind = GameEnums.AbilityKind.FIRE
	suppresses_target = p_suppresses

func describe() -> String:
	var base := "Fire one shot at a single spot."
	if suppresses_target:
		base += " A hit ship can't attack next turn."
	return base

func execute(ctx: ActionContext) -> ActionResult:
	var res := ctx.board.apply_hits(ctx.cells)
	if suppresses_target:
		for ship in res.ships_hit:
			ship.suppressed_turns = maxi(ship.suppressed_turns, 1)
	return res
