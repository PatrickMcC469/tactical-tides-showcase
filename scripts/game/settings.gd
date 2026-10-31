## Player-facing app settings (persisted to user://). Small on purpose; grows as options land.
extends Node

const PATH := "user://settings.cfg"

var reduce_motion: bool = false
var sound: bool = true
var player_name: String = ""   # the captain name shown to opponents (empty -> "Captain")

## Scene the Settings screen's Back button returns to. The main-menu gear leaves this at the default;
## the in-game gear sets it to the current game scene so Back drops you back into the match. Not
## persisted — it's transient navigation state.
var settings_return: String = "res://scenes/ui/main_menu.tscn"

func _ready() -> void:
	_load()

func set_sound(v: bool) -> void:
	sound = v
	_save()
	Audio.apply_setting()

## Multiplier fed to the water/fog shaders' `speed` uniform. Frozen when reduce-motion is on.
func motion_speed() -> float:
	return 0.0 if reduce_motion else 1.0

func set_reduce_motion(v: bool) -> void:
	reduce_motion = v
	_save()

## The captain name to show opponents; falls back to "Captain" when unset.
func captain_name() -> String:
	var n := player_name.strip_edges()
	return n if n != "" else "Captain"

func set_player_name(v: String) -> void:
	player_name = v.strip_edges().left(20)   # keep it short enough for the versus tile
	_save()

func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("display", "reduce_motion", reduce_motion)
	c.set_value("audio", "sound", sound)
	c.set_value("player", "name", player_name)
	c.save(PATH)

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	reduce_motion = bool(c.get_value("display", "reduce_motion", false))
	sound = bool(c.get_value("audio", "sound", true))
	player_name = str(c.get_value("player", "name", ""))
