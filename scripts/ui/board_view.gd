## Draws one 20x20 board: water, grid, the 5x5 sector overlay with A1..D4 labels, and (when
## revealed) the fleet's ship cells + powerups. Also emits tap/hover cell signals and can draw a
## placement preview, so screens can build interaction on top of it.
class_name BoardView
extends Control

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)
signal cell_dragged(cell: Vector2i)     # pointer moved while held down (drag-to-aim)
signal cell_released(cell: Vector2i)    # pointer/touch lifted

var board: Board = null
var reveal_ships: bool = true
var cell_size: float = 28.0

var preview_cells: Array[Vector2i] = []
var preview_ok: bool = true
var ghost_cells: Array[Vector2i] = []      # clickable move destinations (turn screen)
var highlight_cells: Array[Vector2i] = []  # the selected ship
var markers: Dictionary = {}               # enemy-waters fog: cell -> {hit, alpha}
var own_effects: Array = []                # your placed mines/drones: {pos, kind:0 mine/1 drone, text}
var barrage_sectors: Array[Vector2i] = []  # your active barrage zones

# Live shot animations: each = {pos:Vector2i, hit:bool, age:float}. Play a tracer streak then an
# explosion (hit) or splash (miss); hits also kick a short board shake.
var _impacts: Array = []
var _shake_time := 0.0
var _shake_off := Vector2.ZERO
var _flyovers: Array = []   # active/pending carrier fly-over passes (multi_shot = 1, air_strafe = 2)
const AXIS_X := 0   # bomber flies along the X axis (horizontal) — drops the target's ROW
const AXIS_Y := 1   # bomber flies along the Y axis (vertical, nose-up) — drops the target's COLUMN
const FLYOVER_DUR := 1.5
var _torpedo := {}   # submarine torpedo running through the water: {} idle, else {from,to,cell,hit,age,dur}
const TORPEDO_PER_CELL := 0.11   # seconds the torpedo takes to travel one cell
var _mine_drops: Array = []   # mines splashing into the water on placement: each {cell, age}
const MINE_DROP_DUR := 1.0
# Idle "living water": faint ripples + foam drifting off your ships. Purely procedural (driven by
# _water_t), throttled to ~30fps, on only for your own board and off under reduce-motion.
var _water_t := 0.0
var _redraw_acc := 0.0
var _ambient := false
const IMPACT_DUR := 0.72
const TRACER_DUR := 0.18
const SHAKE_DUR := 0.22

const WATER := Color(0.07, 0.12, 0.18)
const FOG := Color(0.10, 0.14, 0.20)
const GRID := Color(0.18, 0.26, 0.34)
const SECTOR := Color(0.45, 0.65, 0.85)
const SHIP_EDGE := Color(0.92, 0.95, 1.0, 0.5)
const POWERUP := Color(0.96, 0.80, 0.22)
const LABEL := Color(0.55, 0.72, 0.92, 0.55)

## Per-type powerup art (drop these PNGs in and they show automatically; falls back to a gold
## square until the art lands). Keyed by GameEnums.PowerupKind.
const POWERUP_ART := {
	GameEnums.PowerupKind.RAPID_RELOAD: "res://assests/powerups/rapid_reload.png",
	GameEnums.PowerupKind.REPAIR: "res://assests/powerups/repair.png",
	GameEnums.PowerupKind.MOVEMENT: "res://assests/powerups/movement.png",
	GameEnums.PowerupKind.OVERCLOCK: "res://assests/powerups/overclock.png",
	GameEnums.PowerupKind.MINE_SWEEP: "res://assests/powerups/mine_sweep.png",
}

static func powerup_sprite(kind: int) -> Texture2D:
	var p: String = POWERUP_ART.get(kind, "")
	return load(p) if p != "" and ResourceLoader.exists(p) else null
const PREVIEW_OK := Color(0.40, 0.85, 0.45, 0.55)
const PREVIEW_BAD := Color(0.90, 0.35, 0.35, 0.55)
const GHOST := Color(0.50, 0.85, 0.95, 0.10)
const GHOST_EDGE := Color(0.60, 0.90, 1.0, 0.32)
const HIGHLIGHT := Color(1.0, 0.92, 0.55, 0.28)   # selected-ship outline — kept faint so the hull reads
const HIT := Color(0.92, 0.30, 0.28)
const MISS := Color(0.55, 0.62, 0.70)
const DAMAGE_LINE := Color(0.95, 0.35, 0.25, 0.95)

## Per-ship draw scale (beam, length) multipliers on top of the length-based sizing, for hulls
## whose natural aspect leaves their footprint under-filled. The Aircraft Carrier's wide flight
## deck (3-cell-wide footprint) needs its beam widened so it fills the tiles it occupies.
const FILL_SCALE := {
	&"aircraft_carrier": Vector2(1.32, 1.06),
}

const SHIP_SPRITES := {
	&"battleship": preload("res://assests/ships/battleship/battleship_default_td.png"),
	&"aircraft_carrier": preload("res://assests/ships/aircraft_carrier/air_default_td.png"),
	&"cruiser": preload("res://assests/ships/cruiser/cru_default_td.png"),
	&"destroyer": preload("res://assests/ships/destroyer/des_default_td.png"),
	&"submarine": preload("res://assests/ships/sub/sub_default_td.png"),
	&"drone_ship": preload("res://assests/ships/drone/drone_default_td.png"),
}

## ship id -> art folder (needed to resolve the equipped skin's `<key>_td/_tl.png`).
const SHIP_DIR := {
	&"battleship": "battleship", &"aircraft_carrier": "aircraft_carrier", &"cruiser": "cruiser",
	&"destroyer": "destroyer", &"submarine": "sub", &"drone_ship": "drone",
}

## The equipped-skin art path for a ship (top-down `_td` or cinematic `_tl`), or "" for default.
## The active skin key is `<prefix>_<theme>`; the file is `<dir>/<key>_<suffix>.png`.
static func _skin_art(id: StringName, suffix: String) -> String:
	return _skin_art_key(id, Cosmetics.active_skin(String(id)), suffix)

## Art path for an EXPLICIT skin key (not necessarily our own equipped one).
static func _skin_art_key(id: StringName, key: String, suffix: String) -> String:
	if key == "":
		return ""
	var dir: String = SHIP_DIR.get(id, "")
	if dir == "":
		return ""
	var path := "res://assests/ships/%s/%s_%s.png" % [dir, key, suffix]
	return path if ResourceLoader.exists(path) else ""

static func ship_sprite(id: StringName) -> Texture2D:
	var skin := _skin_art(id, "td")
	return load(skin) if skin != "" else SHIP_SPRITES.get(id)

## Detailed broadside renders (default skin) for the SELECTED SHIP panel. Loaded at runtime so
## missing/unimported art degrades gracefully to the top-down sprite. Skin-aware lookup later.
const SHIP_SIDES := {
	&"battleship": "res://assests/ships/battleship/battleship_default_tl.png",
	&"aircraft_carrier": "res://assests/ships/aircraft_carrier/air_default_tl.png",
	&"cruiser": "res://assests/ships/cruiser/cru_default_tl.png",
	&"destroyer": "res://assests/ships/destroyer/des_default_tl.png",
	&"submarine": "res://assests/ships/sub/sub_default_tl.png",
	&"drone_ship": "res://assests/ships/drone/drone_default_tl.png",
}

static func ship_side(id: StringName) -> Texture2D:
	var skin := _skin_art(id, "tl")
	if skin != "":
		return load(skin)
	return ship_side_default(id)

## The default-skin cinematic shot.
static func ship_side_default(id: StringName) -> Texture2D:
	var p: String = SHIP_SIDES.get(id, "")
	return load(p) if p != "" and ResourceLoader.exists(p) else null

## Cinematic shot for an EXPLICIT skin key — used for the versus screen's enemy fleet, whose skins
## come from the opponent's loadout rather than our local Cosmetics. Falls back to default art.
static func ship_side_skinned(id: StringName, key: String) -> Texture2D:
	var p := _skin_art_key(id, key, "tl")
	return load(p) if p != "" else ship_side_default(id)

static func ship_color(id: StringName) -> Color:
	match id:
		&"battleship": return Color(0.86, 0.46, 0.36)
		&"aircraft_carrier": return Color(0.34, 0.72, 0.70)
		&"cruiser": return Color(0.66, 0.50, 0.86)
		&"destroyer": return Color(0.46, 0.76, 0.50)
		&"submarine": return Color(0.40, 0.60, 0.92)
		&"drone_ship": return Color(0.84, 0.80, 0.38)
	return Color(0.62, 0.68, 0.74)

## Carrier skin theme -> bomber sprite file (assests/bomber/). Filenames don't follow the ship-skin
## convention and carry a couple of typos, so map them explicitly. Every theme has a bomber.
const BOMBER_BY_THEME := {
	"default": "bomber_defualt", "steel": "bomber_steel", "blue": "bomber_deep_blue",
	"desert": "bomber_desert", "artic": "bomber_artic", "inferno": "bobmer_inferno",
	"gold": "bomber_golden", "neptune": "bomber_phantom", "void": "bomber_void",
	"celestial": "bomber_celestial",
}

## The bomber matching the carrier's equipped skin (falls back to default), so the fly-over plane
## matches the ship that launched it.
static func carrier_plane() -> Texture2D:
	var theme := Skins.theme_of(Cosmetics.active_skin("aircraft_carrier"))
	var file: String = BOMBER_BY_THEME.get(theme, "bomber_defualt")
	var p := "res://assests/bomber/%s.png" % file
	if not ResourceLoader.exists(p):
		p = "res://assests/bomber/bomber_defualt.png"
	return load(p) if ResourceLoader.exists(p) else null

## Destroyer skin theme -> mine sprite file (assests/mines/). Same theme mapping as the bombers.
const MINE_BY_THEME := {
	"default": "mine_default", "steel": "mine_steel", "blue": "mine_deep_blue",
	"desert": "mine_desert", "artic": "mine_artic", "inferno": "mine_inferno",
	"gold": "mine_golden", "neptune": "mine_phantom", "void": "mine_void",
	"celestial": "mine_celestial",
}

## The mine sprite matching the destroyer's equipped skin (the destroyer lays the mines). Falls back
## to the default mine, then null (callers draw a plain marker if there's no art).
static func mine_sprite() -> Texture2D:
	var theme := Skins.theme_of(Cosmetics.active_skin("destroyer"))
	var file: String = MINE_BY_THEME.get(theme, "mine_default")
	var p := "res://assests/mines/%s.png" % file
	if not ResourceLoader.exists(p):
		p = "res://assests/mines/mine_default.png"
	return load(p) if ResourceLoader.exists(p) else null

## `speed` (0..1) scales all motion so the "reduce motion" setting can dial it down (or off).
## Own-board water = the shared procedural shader file (also used for the menu wave). The board's
## bg ColorRect fills the 20x20 grid with it, so ships sit on live, seamless waves.
const WATER_SURFACE_SHADER := preload("res://scripts/shaders/water_surface.gdshader")
const WATER_BASE_SPEED := 0.14   # base drift; scaled by Settings.motion_speed() (0 under reduce-motion)
const FOG_SHADER := """
shader_type canvas_item;
uniform float speed = 1.0;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0,0.0)), c = hash(i + vec2(0.0,1.0)), d = hash(i + vec2(1.0,1.0));
	return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	// Dominant sideways roll so the mist visibly drifts across the enemy waters.
	vec2 roll = vec2(t * 0.05, t * 0.014);
	float f = noise(uv * 3.0 + roll) * 0.55
		+ noise(uv * 6.0 + roll * 1.6 + vec2(0.0, t * 0.02)) * 0.30
		+ noise(uv * 12.0 - roll * 0.8) * 0.15;
	f = pow(f, 1.4);   // billow the density into rolling banks
	vec3 dark = vec3(0.05, 0.07, 0.11);
	vec3 mist = vec3(0.20, 0.24, 0.32);
	COLOR = vec4(mix(dark, mist, f * 0.78), 1.0);
}
"""

var bg: ColorRect
var _water_mat: ShaderMaterial
var _fog_mat: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2.ONE * (cell_size * Sectors.BOARD_SIZE)
	size = custom_minimum_size
	bg = ColorRect.new()
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = custom_minimum_size
	add_child(bg)
	_water_mat = _make_water_mat()
	_fog_mat = _make_mat(FOG_SHADER)
	bg.material = _water_mat if reveal_ships else _fog_mat
	_set_ambient(reveal_ships)   # idle living-water animation on your own board

## Turn the idle living-water animation on/off. Off under reduce-motion and on the enemy view (no
## ships there). While on, _process keeps ticking a throttled ambient redraw.
func _set_ambient(on: bool) -> void:
	_ambient = on and Settings.motion_speed() > 0.0
	if _ambient:
		set_process(true)
	elif _impacts.is_empty() and _shake_time <= 0.0:
		set_process(false)

## Own-board water material from the shared shader file; motion scaled by the reduce-motion setting.
func _make_water_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SURFACE_SHADER
	mat.set_shader_parameter("speed", WATER_BASE_SPEED * Settings.motion_speed())
	return mat

func _make_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("speed", Settings.motion_speed())  # 0 when reduce-motion is on
	return mat

func set_board(b: Board, reveal: bool) -> void:
	board = b
	reveal_ships = reveal
	if bg != null:
		bg.material = _water_mat if reveal else _fog_mat
	_set_ambient(reveal)
	queue_redraw()

func set_preview(cells: Array[Vector2i], ok: bool) -> void:
	preview_cells = cells
	preview_ok = ok
	queue_redraw()

func clear_preview() -> void:
	if not preview_cells.is_empty():
		preview_cells = []
		queue_redraw()

func set_ghosts(cells: Array[Vector2i]) -> void:
	ghost_cells = cells
	queue_redraw()

func set_highlight(cells: Array[Vector2i]) -> void:
	highlight_cells = cells
	queue_redraw()

func set_markers(m: Dictionary) -> void:
	markers = m
	queue_redraw()

## Kick off shot animations on the given cells (hit_cells is the subset that struck a ship).
func play_impacts(cells: Array, hit_cells: Array) -> void:
	if cells.is_empty() or Settings.reduce_motion:
		return   # reduce-motion: markers just settle in, no tracer/blast/shake
	var hit := {}
	for h in hit_cells:
		hit[h] = true
	for c in cells:
		var is_hit: bool = hit.has(c)
		_impacts.append({"pos": c, "hit": is_hit, "age": 0.0})
		if is_hit:
			_shake_time = SHAKE_DUR
	set_process(true)
	queue_redraw()

## A mine splashing into the water at each cell (placement flourish) — visible ~1s, then it settles as
## the hidden mine token (own_effects keeps drawing it). Skipped under reduce-motion.
func play_mine_drop(cells: Array) -> void:
	if cells.is_empty() or Settings.reduce_motion:
		return
	for c in cells:
		_mine_drops.append({"cell": c, "age": 0.0})
	set_process(true)
	queue_redraw()

func _draw_mine_drop(md: Dictionary) -> void:
	var t := clampf(md.age / MINE_DROP_DUR, 0.0, 1.0)
	var center := (Vector2(md.cell) + Vector2(0.5, 0.5)) * cell_size + _shake_off
	var tex := mine_sprite()
	var r := cell_size * 0.44
	if t < 0.55:                                  # falling in: descends from above, slight shrink
		var ft := t / 0.55
		var fall := (1.0 - ft) * cell_size * 1.3
		var sc := lerpf(1.35, 0.92, ft)
		if tex != null:
			var rr := r * sc
			draw_texture_rect(tex, Rect2(center - Vector2(0.0, fall) - Vector2(rr, rr), Vector2(rr, rr) * 2.0),
				false, Color(1, 1, 1, 0.55 + 0.45 * ft))
	else:                                         # splash ring where it hit; mine now settled
		var st := (t - 0.55) / 0.45
		draw_arc(center, cell_size * (0.18 + st * 0.55), 0.0, TAU, 28,
			Color(0.82, 0.92, 1.0, (1.0 - st) * 0.55), 2.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false)

## An explosion AT each given cell with NO incoming tracer — a blast in place (mines detonating),
## not a shell flying in. Starts past the tracer phase so it detonates on the spot.
func play_blast(cells: Array) -> void:
	if cells.is_empty() or Settings.reduce_motion:
		return
	for c in cells:
		var center := (Vector2(c) + Vector2(0.5, 0.5)) * cell_size
		_impacts.append({"pos": c, "hit": true, "age": TRACER_DUR, "from": center})
	_shake_time = SHAKE_DUR
	set_process(true)
	queue_redraw()

## Queue a carrier fly-over: a skinned bomber crosses the board along `axis` (AXIS_X = horizontal over
## the row, AXIS_Y = vertical over the column) and drops each shot as it passes that cell, so the shot
## fires FROM the plane. `delay` staggers the start (air_strafe runs an X pass, then a Y pass 2s later).
## Skips under reduce-motion (markers already settled).
func play_flyover(cells: Array, hit_cells: Array, tex: Texture2D, axis: int, delay: float = 0.0) -> void:
	if cells.is_empty() or Settings.reduce_motion:
		return
	var hits := {}
	for h in hit_cells:
		hits[h] = true
	var full := cell_size * Sectors.BOARD_SIZE
	var margin := cell_size * 3.0
	var a0 := full + margin       # enter from below/left of the board
	var a1 := -margin             # exit above/left... (AXIS_Y goes bottom->top; AXIS_X left->right)
	if axis == AXIS_X:
		a0 = -margin; a1 = full + margin
	# fixed perpendicular coord = average of the targets on the moving axis
	var sfix := 0.0
	for c in cells:
		sfix += float(c.y if axis == AXIS_X else c.x)
	var fixed: float = (sfix / float(cells.size()) + 0.5) * cell_size
	var drops: Array = []
	for c in cells:
		var coord := (float(c.x if axis == AXIS_X else c.y) + 0.5) * cell_size
		drops.append({"cell": c, "hit": hits.has(c), "at": clampf(inverse_lerp(a0, a1, coord), 0.05, 0.95), "fired": false})
	_flyovers.append({"tex": tex, "axis": axis, "a0": a0, "a1": a1, "fixed": fixed,
		"age": -maxf(0.0, delay), "dur": FLYOVER_DUR, "drops": drops})
	set_process(true)
	queue_redraw()

## Plane position for a fly-over pass at normalized progress t (0..1) along its flight axis.
func _flyover_pos(fo: Dictionary, t: float) -> Vector2:
	var a: float = lerpf(fo.a0, fo.a1, clampf(t, 0.0, 1.0))
	return Vector2(a, fo.fixed) if fo.axis == AXIS_X else Vector2(fo.fixed, a)

func _draw_plane(fo: Dictionary) -> void:
	var tex: Texture2D = fo.get("tex")
	if tex == null:
		return
	var pos := _flyover_pos(fo, fo.age / fo.dur)
	var h := cell_size * 2.6
	var w := h * tex.get_width() / float(tex.get_height())
	var rot: float = PI * 0.5 if fo.axis == AXIS_X else 0.0   # art is nose-up; turn it to face east for an X run
	draw_set_transform(pos + _shake_off, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false)
	draw_set_transform(_shake_off, 0.0, Vector2.ONE)

## Submarine torpedo: runs from the launch cell along its line to the impact cell, leaving a bubble
## wake, then detonates there (blast on a hit, splash on a miss). Under reduce-motion, just the blast.
func play_torpedo(start_cell: Vector2i, end_cell: Vector2i, hit: bool) -> void:
	if Settings.reduce_motion:
		play_impacts([end_cell], [end_cell] if hit else [])
		return
	var from := (Vector2(start_cell) + Vector2(0.5, 0.5)) * cell_size
	var to := (Vector2(end_cell) + Vector2(0.5, 0.5)) * cell_size
	var cells: float = maxf(1.0, (Vector2(end_cell) - Vector2(start_cell)).length())
	_torpedo = {"from": from, "to": to, "cell": end_cell, "hit": hit, "age": 0.0,
		"dur": maxf(0.3, cells * TORPEDO_PER_CELL)}
	set_process(true)
	queue_redraw()

func _draw_torpedo() -> void:
	var t := clampf(_torpedo.age / _torpedo.dur, 0.0, 1.0)
	var head: Vector2 = _torpedo.from.lerp(_torpedo.to, t)
	var dir: Vector2 = _torpedo.to - _torpedo.from
	dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var o := _shake_off
	draw_line(_torpedo.from + o, head + o, Color(0.72, 0.88, 1.0, 0.22), maxf(1.5, cell_size * 0.14))  # foamy wake
	for k in 5:                                   # trailing bubbles
		var q: Vector2 = _torpedo.from.lerp(head, float(k) / 5.0) + o
		draw_circle(q, cell_size * 0.05, Color(0.85, 0.93, 1.0, 0.22))
	draw_circle(head + o, cell_size * 0.11, Color(0.90, 0.95, 1.0, 0.85))                # bright head
	draw_circle(head + o + dir * cell_size * 0.04, cell_size * 0.06, Color(0.18, 0.26, 0.34, 0.9))

func _process(delta: float) -> void:
	for imp in _impacts:
		imp.age += delta
	if not _impacts.is_empty():
		_impacts = _impacts.filter(func(i): return i.age < IMPACT_DUR)
	if not _flyovers.is_empty():
		_advance_flyovers(delta)
	if not _torpedo.is_empty():
		_advance_torpedo(delta)
	if not _mine_drops.is_empty():
		for md in _mine_drops:
			md.age += delta
		_mine_drops = _mine_drops.filter(func(m): return m.age < MINE_DROP_DUR)
	if _shake_time > 0.0:
		_shake_time -= delta
		var m := clampf(_shake_time / SHAKE_DUR, 0.0, 1.0) * 3.5
		_shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * m
	else:
		_shake_off = Vector2.ZERO
	var busy := not _impacts.is_empty() or _shake_time > 0.0 or not _flyovers.is_empty() or not _torpedo.is_empty() or not _mine_drops.is_empty()
	if _ambient:
		_water_t += delta
	if busy:
		queue_redraw()                       # shot animations: every frame
	elif _ambient:
		_redraw_acc += delta                 # idle water: throttle to ~30fps
		if _redraw_acc >= 0.033:
			_redraw_acc = 0.0
			queue_redraw()
	else:
		set_process(false)

## Advance each fly-over pass: once its start delay elapses, drop each shot as the plane passes that
## cell (spawning an impact whose tracer originates FROM the plane), then retire finished passes.
func _advance_flyovers(delta: float) -> void:
	for fo in _flyovers:
		fo.age += delta
		if fo.age < 0.0:
			continue                          # still in its start delay
		var t: float = fo.age / fo.dur
		for d in fo.drops:
			if not d.fired and t >= d.at:
				d.fired = true
				_impacts.append({"pos": d.cell, "hit": d.hit, "age": 0.0, "from": _flyover_pos(fo, t)})
				if d.hit:
					_shake_time = SHAKE_DUR
	_flyovers = _flyovers.filter(func(f): return f.age < f.dur)

## Advance the torpedo; on arrival detonate at the impact cell (start past the tracer phase so there's
## no incoming-shell streak — just the blast/splash where it struck).
func _advance_torpedo(delta: float) -> void:
	_torpedo.age += delta
	if _torpedo.age >= _torpedo.dur:
		_impacts.append({"pos": _torpedo.cell, "hit": _torpedo.hit, "age": TRACER_DUR, "from": _torpedo.to})
		if _torpedo.hit:
			_shake_time = SHAKE_DUR
		_torpedo = {}

func set_own_effects(effects: Array, sectors: Array[Vector2i]) -> void:
	own_effects = effects
	barrage_sectors = sectors
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _cell_at((event as InputEventMouseMotion).position)
		if Sectors.in_bounds(c):
			cell_hovered.emit(c)
			if (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
				cell_dragged.emit(c)          # holding + moving = drag-to-aim
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var c := _cell_at((event as InputEventMouseButton).position)
		if Sectors.in_bounds(c):
			if (event as InputEventMouseButton).pressed:
				cell_clicked.emit(c)
			else:
				cell_released.emit(c)
	elif event is InputEventScreenTouch:
		var c := _cell_at((event as InputEventScreenTouch).position)
		if Sectors.in_bounds(c):
			if (event as InputEventScreenTouch).pressed:
				cell_clicked.emit(c)
			else:
				cell_released.emit(c)
	elif event is InputEventScreenDrag:
		var c := _cell_at((event as InputEventScreenDrag).position)
		if Sectors.in_bounds(c):
			cell_hovered.emit(c)
			cell_dragged.emit(c)

func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / cell_size), int(pos.y / cell_size))

func _draw() -> void:
	var n := Sectors.BOARD_SIZE
	var full := cell_size * n
	# (background water/fog is drawn by the `bg` shader behind this)
	if _shake_off != Vector2.ZERO:
		draw_set_transform(_shake_off, 0.0, Vector2.ONE)   # brief board shake on a hit

	for i in n + 1:
		var off := i * cell_size
		draw_line(Vector2(off, 0), Vector2(off, full), GRID, 1.0)
		draw_line(Vector2(0, off), Vector2(full, off), GRID, 1.0)

	if board != null and reveal_ships:
		if _ambient:
			for ship in board.ships:
				_draw_wake(ship)          # living water behind the hulls
		for ship in board.ships:
			_draw_ship(ship)
		for p in board.powerups:
			var ptex := powerup_sprite(p.kind)
			if ptex != null:
				var pr := _cell_rect(p.cell)
				var pad := cell_size * 0.18   # a touch larger than the cell so the token pops
				draw_texture_rect(ptex, Rect2(pr.position - Vector2(pad, pad),
					pr.size + Vector2(pad, pad) * 2.0), false)
			else:
				_fill_cell(p.cell, POWERUP)

	for c in preview_cells:
		_fill_cell(c, PREVIEW_OK if preview_ok else PREVIEW_BAD)

	if not reveal_ships:
		for sec in barrage_sectors:
			var sr := Rect2(sec.x * Sectors.SECTOR_SIZE * cell_size, sec.y * Sectors.SECTOR_SIZE * cell_size,
				Sectors.SECTOR_SIZE * cell_size, Sectors.SECTOR_SIZE * cell_size)
			draw_rect(sr, Color(0.92, 0.45, 0.30, 0.12), true)
			draw_rect(sr, Color(0.95, 0.55, 0.40, 0.7), false, 2.0)
		for cell in markers:
			var rec: Dictionary = markers[cell]
			var center := Vector2(cell.x + 0.5, cell.y + 0.5) * cell_size
			if rec.hit:
				draw_circle(center, cell_size * 0.32, Color(HIT.r, HIT.g, HIT.b, rec.alpha))
			else:
				draw_circle(center, cell_size * 0.16, Color(MISS.r, MISS.g, MISS.b, rec.alpha))
		for e in own_effects:
			var ec := (Vector2(e.pos) + Vector2(0.5, 0.5)) * cell_size
			if int(e.kind) == 0:   # mine — the destroyer's skinned mine art (plain marker if art missing)
				var mtex := mine_sprite()
				if mtex != null:
					var r := cell_size * 0.44
					draw_texture_rect(mtex, Rect2(ec - Vector2(r, r), Vector2(r, r) * 2.0), false)
				else:
					var h := cell_size * 0.2
					draw_rect(Rect2(ec - Vector2(h, h), Vector2(h, h) * 2.0), Color(0.96, 0.55, 0.18, 0.95))
			else:                  # drone (recon ping with distance number)
				draw_circle(ec, cell_size * 0.30, Color(0.40, 0.85, 0.95, 0.45))
				draw_string(ThemeDB.fallback_font, ec + Vector2(-4, 4), str(e.text),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	for c in highlight_cells:
		draw_rect(_cell_rect(c), HIGHLIGHT, false, 1.5)
	for c in ghost_cells:
		_fill_cell(c, GHOST)
		draw_rect(_cell_rect(c), GHOST_EDGE, false, 1.0)

	for i in range(0, n + 1, Sectors.SECTOR_SIZE):
		var off := i * cell_size
		draw_line(Vector2(off, 0), Vector2(off, full), SECTOR, 2.0)
		draw_line(Vector2(0, off), Vector2(full, off), SECTOR, 2.0)
	for s in Sectors.all_sectors():
		var pos := Vector2(s.x * Sectors.SECTOR_SIZE * cell_size + 4, s.y * Sectors.SECTOR_SIZE * cell_size + 15)
		draw_string(ThemeDB.fallback_font, pos, Sectors.label(s), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LABEL)

	for imp in _impacts:                       # shot animations on top of everything
		_draw_impact(imp, full)
	for fo in _flyovers:                        # the bomber(s), above the impacts they drop
		if fo.age >= 0.0:
			_draw_plane(fo)
	if not _torpedo.is_empty():                 # the submarine torpedo running through the water
		_draw_torpedo()
	for md in _mine_drops:                       # mines splashing into the water on placement
		_draw_mine_drop(md)
	if _shake_off != Vector2.ZERO:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Draw one shot animation: a tracer streak arcs in, then an explosion (hit) or splash (miss).
func _draw_impact(imp: Dictionary, full: float) -> void:
	var age: float = imp.age
	var center := Vector2(imp.pos.x + 0.5, imp.pos.y + 0.5) * cell_size
	if age < TRACER_DUR:
		# Incoming shell streak from below the board up to the target.
		var tt := age / TRACER_DUR
		var origin: Vector2 = imp.get("from", Vector2(full * 0.5, full + cell_size * 4.0))
		var tip := origin.lerp(center, tt)
		var tail := origin.lerp(center, maxf(0.0, tt - 0.28))
		draw_line(tail, tip, Color(1.0, 0.92, 0.55, 0.9), 2.5)
		draw_circle(tip, 3.0, Color(1.0, 1.0, 0.85, 0.95))
		return
	var t := (age - TRACER_DUR) / (IMPACT_DUR - TRACER_DUR)   # 0..1 over the impact
	var fade := 1.0 - t
	if imp.hit:
		if t < 0.28:                                          # white muzzle flash
			draw_circle(center, cell_size * (0.2 + t * 1.6), Color(1, 1, 0.9, (0.28 - t) / 0.28 * 0.9))
		draw_arc(center, cell_size * (0.25 + t * 0.9), 0.0, TAU, 32,      # fireball ring
			Color(1.0, 0.5 - t * 0.3, 0.14, fade * 0.9), 1.0 + 3.0 * fade)
		draw_circle(center, cell_size * 0.36 * fade, Color(1.0, 0.35, 0.10, fade * 0.75))  # core
		for k in 6:                                           # debris sparks
			var a := k * TAU / 6.0 + float(imp.pos.x)
			var dir := Vector2(cos(a), sin(a))
			var d := cell_size * (0.3 + t * 1.15)
			draw_line(center + dir * d * 0.6, center + dir * d, Color(1.0, 0.72, 0.3, fade * 0.8), 2.0)
	else:
		draw_arc(center, cell_size * (0.12 + t * 0.7), 0.0, TAU, 28,      # splash ring
			Color(0.75, 0.90, 1.0, fade * 0.8), 0.8 + 2.2 * fade)
		draw_circle(center, cell_size * 0.13 * fade, Color(0.85, 0.95, 1.0, fade * 0.6))
		for k in 5:                                           # droplets
			var a := k * TAU / 5.0 + 0.5
			var d := cell_size * (0.2 + t * 0.55)
			draw_circle(center + Vector2(cos(a), sin(a)) * d, 0.6 + 1.6 * fade, Color(0.82, 0.93, 1.0, fade * 0.7))

## Draw a ship: first a footprint underlay (tinted cells + borders) so it clearly occupies its
## squares, then the sprite on top (sized to its length, keeping the hull's aspect). Damaged
## cells get a dark cell + red crack on top.
func _draw_ship(ship: ShipInstance) -> void:
	var tex := ship_sprite(ship.def.id)
	if tex != null:
		# The art is authored bow-up. Size the hull to its LENGTH (in cells) and keep the
		# sprite's real aspect for the beam, so ships stay ship-shaped instead of stretching
		# to fill their footprint box. A tiny overhang keeps it from looking cramped.
		const OVERHANG := 1.04
		var fill: Vector2 = FILL_SCALE.get(ship.def.id, Vector2.ONE)
		var length_px := float(ship.def.length) * cell_size * OVERHANG * fill.y
		var beam_px := length_px * float(tex.get_width()) / float(tex.get_height()) * fill.x / fill.y
		# center of the ship's current (rotated) footprint on the board
		var cells := ship.all_cells()
		var minx := 999; var maxx := -999; var miny := 999; var maxy := -999
		for c in cells:
			minx = mini(minx, c.x); maxx = maxi(maxx, c.x)
			miny = mini(miny, c.y); maxy = maxi(maxy, c.y)
		var center := Vector2((minx + maxx + 1) * 0.5, (miny + maxy + 1) * 0.5) * cell_size
		draw_set_transform(center, int(ship.facing) * PI * 0.5, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-beam_px * 0.5, -length_px * 0.5, beam_px, length_px), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		for c in ship.cells():
			_fill_cell(c, ship_color(ship.def.id))
	for c in ship.destroyed_cells():
		_fill_cell(c, Color(0, 0, 0, 0.5))
		var r := _cell_rect(c)
		draw_line(r.position, r.position + r.size, DAMAGE_LINE, 1.5)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), DAMAGE_LINE, 1.5)

## Idle "living water" around a ship: faint ripple rings expanding off the hull plus a few foam flecks
## drifting nearby. Fully procedural (driven by _water_t), so there's no per-frame state to track.
func _draw_wake(ship: ShipInstance) -> void:
	var cells := ship.cells()
	if cells.is_empty():
		return
	var minx := 9999; var maxx := -9999; var miny := 9999; var maxy := -9999
	for c in cells:
		minx = mini(minx, c.x); maxx = maxi(maxx, c.x)
		miny = mini(miny, c.y); maxy = maxi(maxy, c.y)
	var center := Vector2((minx + maxx + 1) * 0.5, (miny + maxy + 1) * 0.5) * cell_size
	var fw := maxx - minx + 1
	var fh := maxy - miny + 1
	var rad := maxf(fw, fh) * cell_size * 0.5
	var ph := center.x * 0.021 + center.y * 0.017   # per-ship phase so hulls aren't all in sync
	# Wake takes on the ship's equipped skin: icy for artic, fiery for inferno, etc. (default = blue).
	var col := Skins.wake_color(Skins.theme_of(Cosmetics.active_skin(String(ship.def.id))))
	# Oval waves, stretched along the ship's LONG axis. Done via a scaled draw transform (draw_arc is
	# circular). Compose with the board-shake offset so the wake shakes too, then restore that offset.
	var stretch := Vector2(1.32, 0.72) if fw >= fh else Vector2(0.72, 1.32)
	draw_set_transform(center + _shake_off, 0.0, stretch)
	for k in 2:                                       # ripple rings, hugging the hull
		var t := fposmod(_water_t * 0.28 + float(k) * 0.5 + ph, 1.0)
		draw_arc(Vector2.ZERO, rad * 0.5 + t * rad * 0.45, 0.0, TAU, 40,
			Color(col.r, col.g, col.b, (1.0 - t) * 0.20), 1.5)
	draw_set_transform(_shake_off, 0.0, Vector2.ONE)  # back to the base (shake) transform
	for i in 5:                                       # foam flecks drifting just off the hull
		var life := fposmod(_water_t * 0.5 + float(i) * 0.2 + ph, 1.0)
		var ang := ph * 6.0 + float(i) * 1.9
		var pos := center + Vector2(cos(ang), sin(ang)) * (rad * 0.5 + life * cell_size * 0.55)
		draw_circle(pos, cell_size * 0.05, Color(col.r, col.g, col.b, sin(life * PI) * 0.35))

func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(c.x * cell_size + 1, c.y * cell_size + 1, cell_size - 2, cell_size - 2)

func _fill_cell(c: Vector2i, col: Color) -> void:
	draw_rect(_cell_rect(c), col, true)
