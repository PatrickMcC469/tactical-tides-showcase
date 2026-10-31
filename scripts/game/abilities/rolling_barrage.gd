## Cruiser special. Three volleys of a line, all in the same direction, spaced however the
## player likes — but they must leave room for the third volley.
class_name RollingBarrage
extends Ability

var volleys: int = 3
var line_length: int = 3

func _init() -> void:
	id = &"rolling_barrage"
	display_name = "Rolling Barrage"
	kind = GameEnums.AbilityKind.SPECIAL

func describe() -> String:
	return ("Fire %d volleys of %d-in-a-row, all the same direction, spaced as you like — "
		+ "but leave room for the last volley.") % [volleys, line_length]

func execute(ctx: ActionContext) -> ActionResult:
	# Resolve all chosen volley cells at once.
	# TODO: the across-turns volley spacing/timing belongs in the effects layer.
	var res := ctx.board.apply_hits(ctx.cells)
	res.message = "Volleys resolved immediately (multi-turn spacing TODO)."
	return res
