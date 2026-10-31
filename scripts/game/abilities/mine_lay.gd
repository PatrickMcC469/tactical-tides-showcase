## Lay a hidden mine (Destroyer's fire). Mines detonate when an enemy ship moves over
## them, after a fuse, or instantly if an enemy is already on the spot.
class_name MineLay
extends Ability

var mines_per_use: int = 1
var board_max: int = 5      # max mines a player can have on the board at once
var fuse_turns: int = 3     # auto-detonates this many turns after placement

func _init(p_mines_per_use: int = 1) -> void:
	id = &"mine_lay"
	display_name = "Lay Mine"
	kind = GameEnums.AbilityKind.FIRE
	mines_per_use = p_mines_per_use

func describe() -> String:
	return ("Lay %d hidden mine(s) (max %d on board). Detonates when an enemy moves over it, "
		+ "%d turns after placement, or instantly if an enemy is already there.") \
		% [mines_per_use, board_max, fuse_turns]

func execute(ctx: ActionContext) -> ActionResult:
	var res := ActionResult.new()
	var mine := ctx.board.try_place_mine(ctx.acting_player, ctx.point, fuse_turns)
	if mine == null:
		res.ok = false
		res.message = "Can't place a mine there (max %d reached, off-board, or cell already used)." % board_max
		return res
	if ctx.board.is_covered(mine.cell):
		var det := mine.detonate(ctx.board)
		ctx.board.prune_effects()
		res.hits = det.hits
		res.ships_hit = det.ships_hit
		res.sunk = det.sunk
		res.targeted.assign(det.hits)   # reveal + explode where the mine detonated
		res.message = "Mine detonated on placement."
	else:
		res.message = "Mine placed (hidden)."
	return res
