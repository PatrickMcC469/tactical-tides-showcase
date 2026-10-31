## Shared blast pattern (cells relative to a center point).
## Mines, the Battleship's normal fire, and each Barrage attack all hit a PLUS (+).
class_name Blast
extends RefCounted

## Center + the 4 orthogonal neighbors.
static func plus_cells(c: Vector2i) -> Array[Vector2i]:
	return [c, c + Vector2i(0, -1), c + Vector2i(0, 1), c + Vector2i(-1, 0), c + Vector2i(1, 0)]
