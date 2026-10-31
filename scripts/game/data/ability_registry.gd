## Maps an ability id (stored on a ShipDef) to a fresh Ability instance.
## This is the lookup that lets ships reference behavior by name instead of hard-coding it.
class_name AbilityRegistry
extends RefCounted

static func get_ability(id: StringName) -> Ability:
	match id:
		# Fire modes
		&"single_shot": return SingleShot.new(false)
		&"drone_shot": return SingleShot.new(true)   # Drone's shot also suppresses
		&"cross_shot": return CrossShot.new()        # Battleship's normal fire (plus formation)
		&"emergency_shot": return EmergencyShot.new()  # player fallback when no ship can fire
		&"multi_shot": return MultiShot.new(4)
		&"line_shot": return LineShot.new(3)
		&"mine_lay": return MineLay.new(1)
		&"torpedo": return Torpedo.new(5)
		# Specials
		&"barrage_zone": return BarrageZone.new()
		&"air_strafe": return AirStrafe.new()
		&"rolling_barrage": return RollingBarrage.new()
		&"drop_mines": return DropMines.new()
		&"active_radar": return ActiveRadar.new()
		&"deploy_drones": return DeployDrones.new()
	push_error("AbilityRegistry: unknown ability id '%s'" % id)
	return null
