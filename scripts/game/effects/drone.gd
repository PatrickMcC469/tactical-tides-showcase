## A recon drone on the enemy's board. Constant for its lifespan: while the placer is choosing
## fire targets, each drone shows the distance to the nearest enemy ship node.
class_name Drone
extends BoardEffect

var cell: Vector2i
var life: int = 4    # counts the PLACER's turns

func _init(p_placer: int, p_cell: Vector2i, p_life: int = 4) -> void:
	placer = p_placer
	cell = p_cell
	life = p_life

func occupies(c: Vector2i) -> bool:
	return c == cell

func is_done() -> bool:
	return life <= 0

func on_placer_turn_start(_state: GameState) -> void:
	life -= 1

## Chebyshev distance (diagonals count as 1) to the nearest enemy ship node, counting cells
## whether damaged or not. 0 if the drone sits on a ship node. `board` is the enemy board.
func distance_to_nearest(board: Board) -> int:
	var best := -1
	for ship in board.ships:
		for c in ship.all_cells():
			var d: int = maxi(absi(c.x - cell.x), absi(c.y - cell.y))
			if best < 0 or d < best:
				best = d
	return best
