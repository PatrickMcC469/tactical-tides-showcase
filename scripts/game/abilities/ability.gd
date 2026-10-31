## Base class for every ship action (both FIRE and SPECIAL).
##
## This is the polymorphism seam (Golden Rule #8): a ship doesn't know HOW its fire or
## special works — it just holds an id. The AbilityRegistry maps that id to one of these
## small subclasses. Adding a new ability = adding one new file that extends Ability.
##
## NOTE (Phase 0): execute() is a documented stub. It needs the board + turn state, which
## is the NEXT Phase 0 step. For now describe() lets us show the model working without
## faking combat resolution.
class_name Ability
extends RefCounted

var id: StringName
var display_name: String
var kind: GameEnums.AbilityKind
## What the player must target. Defaults to a single spot; sector-based specials override it.
var target_kind: GameEnums.TargetKind = GameEnums.TargetKind.SINGLE_SPOT

## Human-readable summary of what this action does. Overridden by every subclass.
func describe() -> String:
	return "(no description)"

## Resolve this action against the match. Overridden by each ability; the base reports
## "not wired yet" (used by the persistent specials — mines/drones — pending an effects layer).
func execute(_ctx: ActionContext) -> ActionResult:
	var res := ActionResult.new()
	res.ok = false
	res.message = "'%s' not wired yet (needs the persistent-effects layer)." % id
	return res
