## The Battleship's Barrage Zone. Marks a 5x5 sector on the enemy board; at the START and END
## of the victim's turn, for 3 turns, it rains 3 random plus-blasts inside the sector.
## Ends early if the casting Battleship is sunk.
class_name Barrage
extends BoardEffect

var sector: Vector2i
var turns_left: int = 3
var attacks_per_tick: int = 3
var caster: ShipInstance

func _init(p_placer: int, p_sector: Vector2i, p_caster: ShipInstance, p_turns: int = 3, p_attacks: int = 3) -> void:
	placer = p_placer
	sector = p_sector
	caster = p_caster
	turns_left = p_turns
	attacks_per_tick = p_attacks

func is_done() -> bool:
	return turns_left <= 0 or caster == null or not caster.is_alive()

func on_victim_turn_start(_state: GameState, board: Board) -> void:
	_tick(board)

func on_victim_turn_end(_state: GameState, board: Board) -> void:
	_tick(board)
	turns_left -= 1

## Fire `attacks_per_tick` random plus-blasts inside the sector (no-op if the caster is dead).
func _tick(board: Board) -> void:
	if caster == null or not caster.is_alive():
		return
	var cells := Sectors.cells_in_sector(sector)
	for _i in attacks_per_tick:
		var center: Vector2i = cells[randi() % cells.size()]
		board.apply_hits(Blast.plus_cells(center))
