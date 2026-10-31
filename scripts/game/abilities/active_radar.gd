## Submarine special. Scan a 5x5 sector and learn how many enemy ship-cells are inside it.
class_name ActiveRadar
extends Ability

var sector_size: int = 5

func _init() -> void:
	id = &"active_radar"
	display_name = "Active Radar"
	kind = GameEnums.AbilityKind.SPECIAL
	target_kind = GameEnums.TargetKind.SECTOR

func describe() -> String:
	return "Choose a %dx%d sector (e.g. A1); reveals how many enemy ship-cells are inside." \
		% [sector_size, sector_size]

func execute(ctx: ActionContext) -> ActionResult:
	var res := ActionResult.new()
	# ctx.board is the enemy board, so every ship on it is an enemy.
	var n := ctx.board.count_ships_in_sector(ctx.sector)
	res.info = "Radar: enemy sector %s holds %d ship(s)." % [Sectors.label(ctx.sector), n]
	return res
