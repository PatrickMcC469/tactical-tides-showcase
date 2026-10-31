## Tier definition tables — the single place that turns a tier enum into concrete numbers.
## Tweaking balance = editing these tables, never the ship data or game logic.
## Values transcribed from the notebook (pages 3 & 4).
class_name Tiers
extends RefCounted

## Movement points per turn. Base rule: 1 point = half a ship-length of travel.
static func movement_points(m: GameEnums.Movement) -> int:
	match m:
		GameEnums.Movement.SLOW: return 1
		GameEnums.Movement.MED: return 2
		GameEnums.Movement.FAST: return 3
		GameEnums.Movement.AGILE: return 4
	return 0

## How a 90° rotation is paid for, per movement tier (plain-English rule).
static func rotation_rule(m: GameEnums.Movement) -> String:
	match m:
		GameEnums.Movement.SLOW: return "rotation eats ALL movement"
		GameEnums.Movement.MED: return "rotation costs 1 move"
		GameEnums.Movement.FAST: return "first rotation free, then 1 move each"
		GameEnums.Movement.AGILE: return "first rotation free, then 1 move each (same as Fast)"
	return "unknown"

## Turns between shots.
static func reload_turns(r: GameEnums.Reload) -> int:
	match r:
		GameEnums.Reload.SHORT: return 1
		GameEnums.Reload.MEDIUM: return 2
		GameEnums.Reload.LONG: return 3
	return 0

## Charge needed (accrues +1 per turn) before a special is ready.
static func charge_threshold(c: GameEnums.Charge) -> int:
	match c:
		GameEnums.Charge.SHORT: return 3
		GameEnums.Charge.MEDIUM: return 5
		GameEnums.Charge.LONG: return 7
		GameEnums.Charge.VERY_LONG: return 10
	return 0
