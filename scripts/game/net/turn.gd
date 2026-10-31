## One player's whole turn as transmissible data: an optional move (one ship + ordered steps), an
## optional special, and the required shot. This is what a client sends to the server each turn;
## the Referee re-validates it against the authoritative match state. JSON-friendly (Vector2i is
## stored as [x, y]) so it rides over any transport.
class_name Turn
extends RefCounted

var player: int = 0

# Movement (optional): one ship, then a sequence of steps.
var move_ship: StringName = &""              # "" = didn't move
var move_steps: Array[String] = []           # "F" translate forward, "B" backward, "R" rotate 90°

# Special (optional): resolved like a shot.
var special_id: StringName = &""             # "" = no special
var special_aim: Array[Vector2i] = []
var special_orient: int = 0

# Targeted powerups grabbed during the move, with the player's chosen target:
# {kind:int, ship:String} for Rapid Reload, {kind:int, sector:[x,y]} for Mine Sweep.
var powerup_picks: Array = []

# Fire (required — every turn takes a shot; "emergency_shot" when no ship can fire).
var fire_id: StringName = &""
var fire_aim: Array[Vector2i] = []
var fire_orient: int = 0

func to_dict() -> Dictionary:
	return {
		"player": player,
		"move_ship": String(move_ship),
		"move_steps": move_steps,
		"special_id": String(special_id),
		"special_aim": _cells_to_arr(special_aim),
		"special_orient": special_orient,
		"powerup_picks": powerup_picks,
		"fire_id": String(fire_id),
		"fire_aim": _cells_to_arr(fire_aim),
		"fire_orient": fire_orient,
	}

static func from_dict(d: Dictionary) -> Turn:
	var t := Turn.new()
	t.player = int(d.get("player", 0))
	t.move_ship = StringName(d.get("move_ship", ""))
	t.move_steps.assign(d.get("move_steps", []))
	t.special_id = StringName(d.get("special_id", ""))
	t.special_aim = _arr_to_cells(d.get("special_aim", []))
	t.special_orient = int(d.get("special_orient", 0))
	t.powerup_picks = d.get("powerup_picks", [])
	t.fire_id = StringName(d.get("fire_id", ""))
	t.fire_aim = _arr_to_cells(d.get("fire_aim", []))
	t.fire_orient = int(d.get("fire_orient", 0))
	return t

static func _cells_to_arr(cells: Array[Vector2i]) -> Array:
	var out: Array = []
	for c in cells:
		out.append([c.x, c.y])
	return out

static func _arr_to_cells(arr) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in arr:
		out.append(Vector2i(int(p[0]), int(p[1])))
	return out
