## A collectible powerup sitting on a board. Spawns every 4 turns (one random type for both
## players, at independent random EMPTY cells). Collected by moving a ship onto it.
class_name Powerup
extends RefCounted

var kind: GameEnums.PowerupKind
var cell: Vector2i

func _init(p_kind: GameEnums.PowerupKind, p_cell: Vector2i) -> void:
	kind = p_kind
	cell = p_cell

static func kind_name(k: GameEnums.PowerupKind) -> String:
	return ["Rapid Reload", "Repair", "Movement", "Overclock", "Mine Sweep"][k]
