## What an Ability.execute() reports back: which cells were hit, which ships took damage,
## which sank, plus any revealed info (Active Radar) or notes.
class_name ActionResult
extends RefCounted

var ok: bool = true
var message: String = ""
var info: String = ""                      # revealed intel (e.g. radar count)
var targeted: Array[Vector2i] = []         # every cell the action aimed at (hits + misses)
var hits: Array[Vector2i] = []             # cells that landed on a ship
var ships_hit: Array[ShipInstance] = []    # distinct ships that took damage
var sunk: Array[ShipInstance] = []         # ships destroyed by this action
