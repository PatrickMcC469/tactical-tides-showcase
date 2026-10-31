## Battleship special. Marks a 5x5 area; for several turns it rains shots on that zone at
## the start and end of the enemy's turn. Ends early if the Battleship is sunk.
class_name BarrageZone
extends Ability

var sector_size: int = 5
var duration_turns: int = 3
var ends_if_caster_sunk: bool = true

func _init() -> void:
	id = &"barrage_zone"
	display_name = "Barrage Zone"
	kind = GameEnums.AbilityKind.SPECIAL
	target_kind = GameEnums.TargetKind.SECTOR

func describe() -> String:
	return ("Mark a %dx%d area. For %d turns it's bombarded at the start and end of the "
		+ "enemy's turn. Ends early if this ship is sunk.") \
		% [sector_size, sector_size, duration_turns]

func execute(ctx: ActionContext) -> ActionResult:
	var res := ActionResult.new()
	if ctx.acting_ship == null:
		res.ok = false
		res.message = "Barrage Zone needs a casting Battleship."
		return res
	ctx.board.add_effect(Barrage.new(ctx.acting_player, ctx.sector, ctx.acting_ship, duration_turns, 3))
	res.message = "Barrage marked on enemy sector %s for %d turns." % [
		Sectors.label(ctx.sector), duration_turns]
	return res
