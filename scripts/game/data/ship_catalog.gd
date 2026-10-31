## The full ship roster as DATA. Transcribed from the notebook (see docs/design/ships-and-rules.md).
## To add a ship: add one ShipDef.from({...}) block. No new classes, no logic edits.
##
## Footprints (`shape`) are cell offsets; the cell count equals max_health by design.
## All shapes confirmed from the notebook dot-grids: Battleship (plus/11), Carrier (3x4/12),
## Cruiser (plus/5), Destroyer (4-line), Submarine (3-line), Drone (2-line).
class_name ShipCatalog
extends RefCounted

static func all() -> Array[ShipDef]:
	return [
		ShipDef.from({
			id = &"battleship", display_name = "Battleship",
			max_health = 11, length = 5, pivot = Vector2i(1, 2),
			shape = [                                   # plus/diamond, 11 cells
				Vector2i(1, 0),
				Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
				Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
				Vector2i(1, 4),
			],
			movement = GameEnums.Movement.SLOW,
			reload = GameEnums.Reload.LONG,
			charge = GameEnums.Charge.LONG,
			fire_id = &"cross_shot",             # plus-formation hit (Tevin confirmed 2026-06-27)
			special_id = &"barrage_zone",
		}),
		ShipDef.from({
			id = &"aircraft_carrier", display_name = "Aircraft Carrier",
			max_health = 12, length = 4, pivot = Vector2i(1, 1),
			shape = [                                   # 3 wide x 4 tall, 12 cells
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
				Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
				Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
			],
			movement = GameEnums.Movement.SLOW,
			reload = GameEnums.Reload.LONG,
			charge = GameEnums.Charge.VERY_LONG,
			fire_id = &"multi_shot",
			special_id = &"air_strafe",
		}),
		ShipDef.from({
			id = &"cruiser", display_name = "Cruiser",
			max_health = 4, length = 4, pivot = Vector2i(0, 1),
			shape = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],  # straight line, 4 cells
			movement = GameEnums.Movement.MED,
			reload = GameEnums.Reload.MEDIUM,
			charge = GameEnums.Charge.MEDIUM,
			fire_id = &"line_shot",
			special_id = &"rolling_barrage",
		}),
		ShipDef.from({
			id = &"destroyer", display_name = "Destroyer",
			max_health = 5, length = 3, pivot = Vector2i(1, 1),
			shape = [                                   # plus (+) formation, 5 cells
				Vector2i(1, 0),
				Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
				Vector2i(1, 2),
			],
			movement = GameEnums.Movement.MED,   # Tevin confirmed MED (2026-06-27)
			reload = GameEnums.Reload.MEDIUM,
			charge = GameEnums.Charge.SHORT,
			fire_id = &"mine_lay",
			special_id = &"drop_mines",
		}),
		ShipDef.from({
			id = &"submarine", display_name = "Submarine",
			max_health = 3, length = 3, pivot = Vector2i(0, 1),
			shape = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],  # 3 in a row (vertical)
			movement = GameEnums.Movement.FAST,
			reload = GameEnums.Reload.LONG,
			charge = GameEnums.Charge.SHORT,
			fire_id = &"torpedo",
			special_id = &"active_radar",
		}),
		ShipDef.from({
			id = &"drone_ship", display_name = "Drone Ship",
			max_health = 2, length = 2, pivot = Vector2i(0, 0),
			shape = [Vector2i(0, 0), Vector2i(0, 1)],  # 2 in a row (vertical)
			movement = GameEnums.Movement.AGILE,
			reload = GameEnums.Reload.SHORT,
			charge = GameEnums.Charge.SHORT,
			fire_id = &"drone_shot",
			special_id = &"deploy_drones",
		}),
	]
