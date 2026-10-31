## Base for persistent things placed on a board across turns (mines, drones, barrage).
##
## Every effect is placed by `placer` onto the ENEMY's board (the board owner is the victim).
## They resolve at hook points the GameState calls; the base hooks are no-ops, so each subtype
## only overrides what it needs. Polymorphism, same idea as Ability.
class_name BoardEffect
extends RefCounted

var placer: int = 0    # the player who placed it (victim/board-owner = 1 - placer)

## Does this effect sit on `cell`? (used for no-stacking checks and recon display)
func occupies(_cell: Vector2i) -> bool:
	return false

## When true, the GameState prunes it from the board.
func is_done() -> bool:
	return false

## Start of the VICTIM's (board owner's) turn — mines tick/expire, barrage fires its first volley.
func on_victim_turn_start(_state: GameState, _board: Board) -> void:
	pass

## End of the VICTIM's turn — barrage fires its second volley.
func on_victim_turn_end(_state: GameState, _board: Board) -> void:
	pass

## Start of the PLACER's turn — drones tick down their lifespan.
func on_placer_turn_start(_state: GameState) -> void:
	pass
