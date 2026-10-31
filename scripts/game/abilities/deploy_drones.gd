## Drone Ship special. Drop drones that ping the distance to the nearest enemy ship.
class_name DeployDrones
extends Ability

var drones: int = 2
var lifespan_turns: int = 4

func _init() -> void:
	id = &"deploy_drones"
	display_name = "Deploy Drones"
	kind = GameEnums.AbilityKind.SPECIAL

func describe() -> String:
	return ("Drop %d drones. Each pings how many spaces a chosen spot is from the nearest "
		+ "enemy ship (0 if the spot is on a ship). Last %d turns.") % [drones, lifespan_turns]

func execute(ctx: ActionContext) -> ActionResult:
	var res := ActionResult.new()
	var placed := 0
	for cell in ctx.cells:
		if not Sectors.in_bounds(cell) or ctx.board.effect_at(cell) != null:
			continue   # off-board or cell already used (no stacking)
		ctx.board.add_effect(Drone.new(ctx.acting_player, cell, lifespan_turns))
		placed += 1
	res.message = "Deployed %d drone(s)." % placed
	return res
