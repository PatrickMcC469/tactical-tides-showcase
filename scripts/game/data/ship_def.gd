## A ship as pure DATA (Golden Rule #8). One Ship class reads its behavior from one of these.
## Adding a new ship = adding one entry in ShipCatalog — no new class, no logic changes.
##
## Cosmetic fields (skin_id / flag_id) are deliberately SEPARATE from the stat fields
## (Golden Rule #10): a cosmetic literally cannot touch a gameplay number.
class_name ShipDef
extends RefCounted

# --- Identity ---
var id: StringName
var display_name: String

# --- Gameplay stats ---
var max_health: int
## Nominal length along the facing axis. Drives move distance (ceil(length/2) cells per point).
var length: int = 1
## Shape offset that stays fixed when the ship rotates (its pivot / middle cell).
var pivot: Vector2i = Vector2i.ZERO
## Footprint: cell offsets from the origin, before facing rotation. The cell COUNT equals
## max_health by design — a hit destroys one cell, and the ship sinks when all cells are gone.
var shape: Array[Vector2i] = [Vector2i.ZERO]
var movement: GameEnums.Movement
var reload: GameEnums.Reload
var charge: GameEnums.Charge

# --- Actions (ability ids, resolved via AbilityRegistry) ---
var fire_id: StringName
var special_id: StringName

# --- Cosmetic seam (NEVER read by gameplay) ---
var skin_id: StringName = &"default"
var flag_id: StringName = &"default"

## Build a ShipDef from a plain data dictionary — keeps the catalog readable as a table.
static func from(d: Dictionary) -> ShipDef:
	var s := ShipDef.new()
	s.id = d.id
	s.display_name = d.display_name
	s.max_health = d.max_health
	s.length = d.get(&"length", 1)
	s.pivot = d.get(&"pivot", Vector2i.ZERO)
	s.shape.assign(d.get(&"shape", [Vector2i.ZERO]))
	s.movement = d.movement
	s.reload = d.reload
	s.charge = d.charge
	s.fire_id = d.fire_id
	s.special_id = d.special_id
	s.skin_id = d.get(&"skin_id", &"default")
	s.flag_id = d.get(&"flag_id", &"default")
	return s
