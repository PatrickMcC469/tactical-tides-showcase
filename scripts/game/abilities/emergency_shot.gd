## Player-level fallback (NOT a ship's fire). If a player has NO ship able to fire this turn
## (e.g. everything is reloading), they fire this instead — a single 1-spot hit, no special.
## Guarantees every turn includes an attack, so there are no dead turns.
##
## Reuses SingleShot's plain behavior via inheritance; only the identity/description differ.
class_name EmergencyShot
extends SingleShot

func _init() -> void:
	super._init(false)  # plain single shot, no suppression
	id = &"emergency_shot"
	display_name = "Emergency Shot"

func describe() -> String:
	return "Fallback when no ship can fire this turn: one shot at a single spot, no special."
