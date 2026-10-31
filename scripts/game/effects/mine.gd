## A hidden mine on the enemy's board. Detonates in a PLUS blast when:
##  - placed onto a cell an enemy ship already covers (immediate),
##  - an enemy ship sweeps any of its cells over it during movement, or
##  - its fuse runs out (it blows on its own at the start of the victim's turn).
## Damage is the same either way: a plus-blast that can clip adjacent ship cells.
class_name Mine
extends BoardEffect

var cell: Vector2i
var fuse: int = 3        # counts the VICTIM's turns
var spent: bool = false

func _init(p_placer: int, p_cell: Vector2i, p_fuse: int = 3) -> void:
	placer = p_placer
	cell = p_cell
	fuse = p_fuse

func occupies(c: Vector2i) -> bool:
	return c == cell

func is_done() -> bool:
	return spent

func on_victim_turn_start(_state: GameState, board: Board) -> void:
	fuse -= 1
	if fuse <= 0:
		detonate(board)

## Blow up now: plus-blast at this cell, damaging any ship cells in range. Returns the result.
func detonate(board: Board) -> ActionResult:
	spent = true
	return board.apply_hits(Blast.plus_cells(cell))
