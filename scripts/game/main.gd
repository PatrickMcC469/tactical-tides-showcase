## Phase 0 demo: loads the data-driven ship catalog and prints each ship with its stats
## resolved through the tier tables, plus its fire/special described polymorphically.
## Run it (F5 in Godot, or headless) to see the model working. No combat yet — that's next.
extends Node

func _ready() -> void:
	print_catalog()
	print("")
	BoardDemo.run()
	NetDemo.run()
	get_tree().quit()  # so a headless run exits cleanly

func print_catalog() -> void:
	print("=== TACTICAL TIDES — ship catalog (%d ships) ===\n" % ShipCatalog.all().size())
	for ship in ShipCatalog.all():
		var fire := AbilityRegistry.get_ability(ship.fire_id)
		var special := AbilityRegistry.get_ability(ship.special_id)
		print("%s" % ship.display_name)
		print("  Health : %d  (%d footprint cells — match: %s)" % [
			ship.max_health, ship.shape.size(), ship.shape.size() == ship.max_health])
		print("  Move   : %s (%d pts/turn; %s)" % [
			_movement_name(ship.movement),
			Tiers.movement_points(ship.movement),
			Tiers.rotation_rule(ship.movement)])
		print("  Reload : %s (every %d turn(s))" % [
			_reload_name(ship.reload), Tiers.reload_turns(ship.reload)])
		print("  Charge : %s (special ready at %d charges)" % [
			_charge_name(ship.charge), Tiers.charge_threshold(ship.charge)])
		print("  Fire   : %s — %s" % [fire.display_name, fire.describe()])
		print("  Special: %s — %s" % [special.display_name, special.describe()])
		print("  Skin   : %s | Flag: %s   (cosmetic only)\n" % [ship.skin_id, ship.flag_id])
	var emergency := AbilityRegistry.get_ability(&"emergency_shot")
	print("--- Player fallback ---")
	print("%s — %s" % [emergency.display_name, emergency.describe()])

# --- enum -> readable name helpers ---
func _movement_name(m: GameEnums.Movement) -> String:
	return ["SLOW", "MED", "FAST", "AGILE"][m]

func _reload_name(r: GameEnums.Reload) -> String:
	return ["SHORT", "MEDIUM", "LONG"][r]

func _charge_name(c: GameEnums.Charge) -> String:
	return ["SHORT", "MEDIUM", "LONG", "VERY_LONG"][c]
