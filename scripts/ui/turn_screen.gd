## Battle turn screen — PNG-framed HUD.
## A designed frame PNG (per view) provides all the chrome; we overlay only the live parts:
## the interactive board in the central hole, ship thumbnails + click hotspots on the fleet
## slots, the selected-ship image / special / health / reload, and hotspots on the tabs and the
## MOVE/FIRE button. All game logic (movement, firing, specials, turn flow) is unchanged.
##   FLEET  = your waters: pick a slot to move that ship (tap ghost cells; tap the ship to rotate).
##   BATTLE = enemy waters: pick a slot to arm its shot, tap target(s), FIRE. Special when charged.
extends Control

enum View { OWN, ENEMY }

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W
const CELL_MAX := 20         # board is 20x20


## The six slots, top to bottom, exactly as drawn in the frame art.
const SLOT_ORDER: Array[StringName] = [
	&"battleship", &"aircraft_carrier", &"destroyer", &"cruiser", &"submarine", &"drone_ship"]

# Native frame size, used to letterbox without distortion.
const FRAME_W := 1536.0
const FRAME_H := 1024.0

# --- layout (fractions of the letterboxed frame rect); tune with DEBUG_LAYOUT on ---
const DEBUG_LAYOUT := false
const BOARD := Rect2(0.272, 0.132, 0.448, 0.720)
# Right panel, per the frame's sections: SELECTED SHIP image, then MOVEMENT / SPECIALS /
# HEALTH / RELOAD TIME (values sit just under each baked label).
const SEL_IMG := Rect2(0.793, 0.198, 0.174, 0.262)
const MOVE_VAL_POS := Vector2(0.789, 0.535)
const SPEC_BAR := Rect2(0.789, 0.626, 0.182, 0.022)
const HP_VAL_POS := Vector2(0.789, 0.720)
const RELOAD_POS := Vector2(0.789, 0.815)
const SLOT_X := 0.020
const SLOT_W := 0.216
const SLOT_TOP := 0.205
const SLOT_PITCH := 0.112
const THUMB_W := 0.080
const TAB_F := Rect2(0.335, 0.022, 0.165, 0.062)
const TAB_B := Rect2(0.505, 0.022, 0.165, 0.062)
const MOVE_BTN := Rect2(0.400, 0.905, 0.200, 0.060)     # fleet frame: baked MOVE button
const SPECIAL_BTN := Rect2(0.280, 0.890, 0.212, 0.082)  # battle frame: baked SPECIAL (left)
const FIRE_BTN := Rect2(0.509, 0.890, 0.202, 0.082)     # battle frame: baked FIRE (right)

const ACCENT := Color(0.470, 0.680, 0.880)
const HELP_BTN := Rect2(0.920, 0.578, 0.038, 0.034)
const FIRE_HELP_BTN := Rect2(0.718, 0.900, 0.032, 0.044)  # small '?' just right of FIRE

## Fallback ability explanations (shown until a per-ability help PNG is added under
## res://assests/UI/help/<ability_id>.png). Covers both fire and special ids.
const ABILITY_DESC := {
	# specials
	&"barrage_zone": "Bombards a chosen sector with random strikes at the start and end of the next 3 enemy turns.",
	&"air_strafe": "Strafes the entire row AND column of the target cell.",
	&"rolling_barrage": "Fires up to 3 line-volleys sweeping across enemy waters.",
	&"drop_mines": "Lays up to 3 hidden mines on enemy waters.",
	&"active_radar": "Scans a whole sector to reveal any enemy ships hiding in it.",
	&"deploy_drones": "Deploys up to 2 recon drones that report how close the nearest enemy ship is.",
	# fire
	&"cross_shot": "Fires TWO plus-shaped (+) blasts — pick two spots; each hits a cell and its four neighbours.",
	&"multi_shot": "Fires up to 4 separate shots in one attack.",
	&"line_shot": "Fires a 3-cell line — tap the start, then drag to aim (horizontal/vertical).",
	&"mine_lay": "Lays a hidden mine at a chosen cell that detonates when an enemy ship moves over it.",
	&"torpedo": "Fires a torpedo up to 5 cells — tap the start, then drag the direction you want.",
	&"drone_shot": "One shot at a single cell; a hit ship can't attack next turn.",
	&"emergency_shot": "A single fallback shot, available when no ship can fire.",
}

var gs: GameState
var view: View = View.OWN

# movement (OWN)
var selected: ShipInstance = null
var fwd_cells: Array[Vector2i] = []
var back_cells: Array[Vector2i] = []

# enemy-side action (fire or special)
var armed_ship: ShipInstance = null
var armed_id: StringName = &""
var armed_special := false
var aim_points: Array[Vector2i] = []
var aim_orient := 0

var shown: ShipInstance = null

# --- widgets ---
var _gframe: GameFrame
var board_view: BoardView
var slot_thumbs: Array[TextureRect] = []
var slot_hots: Array[Button] = []
var slot_names: Array[Label] = []
var slot_cards: Array[Panel] = []
var slot_fires: Array = []          # _ShipFire per slot, shown when that ship is destroyed
var _dev_theme_idx := 0             # dev: which skin theme the 'S' key last cycled to
var sel_img: TextureRect
var spec_bar: ProgressBar
var hp_lbl: Label
var reload_lbl: Label
var move_lbl: Label
var status: Label
var rotate_btn: TextureButton   # bottom-console gauge buttons (contextual)
var special_btn: TextureButton
var fire_btn: TextureButton
var ready_btn: TextureButton    # END TURN (offline)
var spec_hot: Button            # right-panel special-charge tap
var overlay: Control
var overlay_label: Label
var overlay_btn: Button
var overlay_action: Callable = Callable()
var help_btn: TextureButton
var fire_help_btn: TextureButton
var help_overlay: Control
var help_img: TextureRect
var help_title: Label
var help_text: Label

# Online mode: this screen submits a recorded Turn to the server instead of resolving locally.
# All of it is guarded by `_online`, so hot-seat play is untouched.
var _online := false
var _match_id := ""
var _online_winner := -1   # the finished-match winner from our view (-1 = still playing)
var _online_reward := -1   # coins the server says we earned this match (-1 = none/ongoing)
var _rec_move_ship: StringName = &""
var _rec_steps: Array[String] = []
var _rec_special_id: StringName = &""
var _rec_special_aim: Array[Vector2i] = []
var _rec_special_orient := 0
var _rec_picks: Array = []                   # online: {kind, ship} / {kind, sector} the player chose

# A targeted powerup (Rapid Reload / Mine Sweep) just grabbed, awaiting the player's pick (or -1).
var _pick_kind: int = -1

# Powerup pickup popups (the info cards the player made).
const POWERUP_POPUP := {
	GameEnums.PowerupKind.RAPID_RELOAD: "rapid_reload_popup.png",
	GameEnums.PowerupKind.REPAIR: "repair_popup.png",
	GameEnums.PowerupKind.MOVEMENT: "movement_popup.png",
	GameEnums.PowerupKind.OVERCLOCK: "overcharge_popup.png",
	GameEnums.PowerupKind.MINE_SWEEP: "mine_sweep_popup.png",
}
var _pu_overlay: Control
var _pu_img: TextureRect
var _pu_queue: Array = []

var _fr := Rect2()

func _ready() -> void:
	# Online we fetch the match view from the (possibly cold) referee — veil the screen so it never
	# flashes empty during that round-trip; freed the instant the board is built below.
	var loading: Control = _show_loading() if MatchSession.online else null
	# Dev: --online forces online mode using the first your-turn match the Net facade knows about.
	if "--online" in OS.get_cmdline_user_args():
		for m in await Net.list_matches():
			if m.your_turn:
				MatchSession.online = true
				MatchSession.match_id = m.match_id
				break
	if MatchSession.online:
		_online = true
		_match_id = MatchSession.match_id
		var _view: Dictionary = await Net.get_view(_match_id)   # our redacted view: no enemy fleet
		gs = MatchCodec.decode_view(_view)
		_online_winner = int(_view.get("winner", -1))          # set if we're opening a finished match
		_online_reward = int(_view.get("reward", -1))          # coins the server rolled for us
	else:
		gs = MatchSession.state
		if gs == null:
			gs = _demo_state()
	_fr = _frame_rect()
	_build_ui()
	if loading != null:
		loading.queue_free()   # board is up — drop the veil (same frame, no flicker)
	Audio.start_ambient()   # ocean bed plays only while on the game screen
	if not _online:
		gs.begin_turn()   # online: the server already began our turn (ticks are baked into the view)
	_set_view(View.OWN)
	if _online and not ("--shot" in OS.get_cmdline_user_args()):
		await _play_incoming()   # siren + replay the opponent's attack on our fleet, then...
		if _online_winner != -1:
			_show_result(_online_winner == gs.current_player, _online_reward)   # ...match already over
			return
	if "--shot" in OS.get_cmdline_user_args():
		await _capture()
		return
	if DisplayServer.get_name() == "headless" and not _online:
		_selftest()

func _exit_tree() -> void:
	Audio.stop_ambient()   # waves stop when we leave the game screen

## Dev-only preview: press K to instantly sink the current player's first intact ship, so the
## destroyed-ship fire on the fleet card can be checked without playing a whole match. Editor/debug
## builds only — never wired in a release export.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or gs == null:
		return
	if event is InputEventKey and event.pressed:
		var key := (event as InputEventKey).keycode
		if key == KEY_K:
			var b := gs.own_board(gs.current_player)
			for s in b.ships:
				if s.is_alive():
					for off in s.def.shape:
						s.destroyed_offsets[off] = true   # blow off every cell -> hp 0 -> sunk
					b.ships.erase(s)
					b.sunk.append(s)                      # retire the wreck like a real sink
					break
			_rebuild_slots()
		elif key == KEY_S:
			_dev_cycle_skin()   # cycle the whole fleet's skin theme to preview wakes/skins live

## Dev: equip the next skin theme on every ship and refresh, so the wake colours + ship art can be
## eyeballed live without visiting the shop. Debug builds only (gated by the caller).
func _dev_cycle_skin() -> void:
	_dev_theme_idx = (_dev_theme_idx + 1) % Skins.THEME_ORDER.size()
	var theme: String = Skins.THEME_ORDER[_dev_theme_idx]
	for def in ShipCatalog.all():
		Cosmetics.set_active(String(def.id), Skins.key_for(String(def.id), theme))
	_set_view(View.OWN)   # fleet view shows the wake; rebuilds sprites from the new skins
	status.text = "DEV skin: %s" % theme

func _frame_rect() -> Rect2:
	return Rect2(Vector2.ZERO, get_viewport_rect().size)   # GameFrame fills the whole viewport

func _px(r: Rect2) -> Rect2:
	return Rect2(_fr.position + r.position * _fr.size, r.size * _fr.size)

func _capture() -> void:
	var t := OS.get_environment("TEMP")
	if _online:
		_set_view(View.OWN)
		for _i in 3: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(t + "/tt_own.png")
		_set_view(View.ENEMY)
		for _i in 3: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(t + "/tt_enemy.png")
		get_tree().quit()
		return
	for ship in gs.own_board(0).ships:
		if ship.def.id == &"battleship" or ship.def.id == &"submarine":
			ship.charge = 99
	_set_view(View.OWN)
	_on_slot(0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(t + "/tt_own.png")
	_set_view(View.ENEMY)
	_on_slot(0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(t + "/tt_enemy.png")
	get_tree().quit()

# --- UI construction ---

func _build_ui() -> void:
	_gframe = GameFrame.new()
	_gframe.fleet_pressed.connect(func(): _set_view(View.OWN))
	_gframe.battle_pressed.connect(func(): _set_view(View.ENEMY))
	add_child(_gframe)

	# Board in the CENTER panel (square, centered).
	var br := _px(GameFrame.CENTER)
	var cs := minf(br.size.x, br.size.y) / float(CELL_MAX)
	board_view = BoardView.new()
	board_view.cell_size = cs
	board_view.position = br.position + (br.size - Vector2.ONE * cs * CELL_MAX) * 0.5
	board_view.cell_clicked.connect(_on_cell_clicked)
	board_view.cell_dragged.connect(_on_cell_dragged)
	add_child(board_view)

	# LEFT panel: fleet list — cinematic thumb + name, with a full-row hotspot each.
	var L := GameFrame.LEFT
	var pitch := L.size.y / float(SLOT_ORDER.size())
	for i in SLOT_ORDER.size():
		var top := L.position.y + i * pitch
		slot_cards.append(_card(Rect2(L.position.x, top + 0.004, L.size.x, pitch - 0.008)))
		var thumb := TextureRect.new()
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lay(thumb, Rect2(L.position.x + 0.008, top + 0.004, L.size.x - 0.016, pitch * 0.60))
		add_child(thumb)
		slot_thumbs.append(thumb)
		var nm := Label.new()
		nm.add_theme_font_size_override("font_size", 11)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.clip_text = true
		_lay(nm, Rect2(L.position.x, top + pitch * 0.62, L.size.x, pitch * 0.34))
		add_child(nm)
		slot_names.append(nm)
		var hot := _hotspot(Rect2(L.position.x, top, L.size.x, pitch), _on_slot.bind(i))
		var hb := StyleBoxFlat.new()   # hover: brighten the card edge
		hb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.08)
		hb.set_border_width_all(2)
		hb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9)
		hb.set_corner_radius_all(6)
		hot.add_theme_stylebox_override("hover", hb)
		slot_hots.append(hot)
		var fire := _ShipFire.new()   # burning wreck overlay, shown when this ship is destroyed
		_lay(fire, Rect2(L.position.x, top, L.size.x, pitch))
		fire.visible = false
		add_child(fire)
		slot_fires.append(fire)

	# RIGHT panel: selected-ship details — cinematic image + captioned stats + special charge.
	var R := GameFrame.RIGHT
	sel_img = TextureRect.new()
	sel_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sel_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sel_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lay(sel_img, Rect2(R.position.x + 0.006, R.position.y + 0.012, R.size.x - 0.012, R.size.y * 0.30))
	add_child(sel_img)
	hp_lbl = _detail_label(R.position.y + R.size.y * 0.36)
	move_lbl = _detail_label(R.position.y + R.size.y * 0.47)
	reload_lbl = _detail_label(R.position.y + R.size.y * 0.58)
	var spc_cap := _detail_label(R.position.y + R.size.y * 0.68)
	spc_cap.text = "SPECIAL"
	spec_bar = _bar(Color(0.95, 0.82, 0.30))
	_lay(spec_bar, Rect2(R.position.x + 0.026, R.position.y + R.size.y * 0.76, R.size.x - 0.052, 0.020))
	add_child(spec_bar)
	spec_hot = _hotspot(Rect2(R.position.x, R.position.y + R.size.y * 0.70, R.size.x, R.size.y * 0.10), _on_use_special)
	help_btn = _mini_help(Rect2(R.position.x + R.size.x - 0.042, R.position.y + R.size.y * 0.325, 0.034, 0.058), _on_help)
	fire_help_btn = _mini_help(Rect2(R.position.x + R.size.x - 0.042, R.position.y + R.size.y * 0.545, 0.034, 0.058), _on_fire_help)

	# Status line, just under the board.
	status = Label.new()
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_size_override("font_size", 13)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lay(status, Rect2(GameFrame.CENTER.position.x, GameFrame.CENTER.position.y + GameFrame.CENTER.size.y + 0.002, GameFrame.CENTER.size.x, 0.028))
	add_child(status)

	# Bottom-console gauge buttons — seated in the two round bezels (left / right of the latch),
	# shown contextually in _refresh: LEFT = ROTATE (fleet) / SPECIAL (battle); RIGHT = READY
	# (fleet) / FIRE (battle).
	rotate_btn = _bottom_btn("rotate_button.png", 0.285, _do_rotate)
	special_btn = _bottom_btn("special_button.png", 0.285, _on_use_special)
	fire_btn = _bottom_btn("fire_button.png", 0.715, _on_action)
	ready_btn = _bottom_btn("ready_button.png", 0.715, _on_end_turn)

	_build_overlay()
	_build_help()
	_build_pu_overlay()

## A right-panel stat label at a given vertical fraction of the viewport.
func _detail_label(yfrac: float) -> Label:
	var R := GameFrame.RIGHT
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	_lay(l, Rect2(R.position.x, yfrac, R.size.x, 0.045))
	add_child(l)
	return l

## A small round "?" help button (help.png art).
func _mini_help(r: Rect2, cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load("res://assests/UI/help.png")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.visible = false
	_lay(b, r)
	b.pressed.connect(cb)
	Press.attach(b)   # tactile dip on tap
	add_child(b)
	return b

## A round gauge button on the bottom console, centred at horizontal fraction `cx`.
func _bottom_btn(file: String, cx: float, cb: Callable) -> TextureButton:
	var tex: Texture2D = load("res://assests/UI/" + file)
	var vp := get_viewport_rect().size
	var h := vp.y * 0.20
	var w := h * tex.get_width() / float(tex.get_height())
	var b := TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(w, h)
	b.position = Vector2(vp.x * cx - w * 0.5, vp.y * 0.885 - h * 0.5)
	b.pressed.connect(cb)
	Press.attach(b)   # tactile dip on tap
	add_child(b)
	return b

func _lay(c: Control, r: Rect2) -> void:
	var p := _px(r)
	c.position = p.position
	c.size = p.size

## A clean solid slot card. `sel` gives it the gold selected border.
func _slot_style(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.033, 0.04) if sel else Color(0.018, 0.02, 0.026)
	sb.set_border_width_all(2 if sel else 1)
	sb.border_color = Color(1.0, 0.83, 0.36) if sel else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	sb.set_corner_radius_all(7)
	return sb

## Charred style for a destroyed ship's fleet card — dark hull, dim ember-red edge.
func _slot_style_dead() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.022, 0.016)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.55, 0.20, 0.11, 0.7)
	sb.set_corner_radius_all(7)
	return sb

## A brief full-screen veil while we fetch the match view from the (possibly cold) referee, so the
## battle screen never flashes empty. Pulses, and is freed the moment the board is built.
func _show_loading() -> Control:
	var o := ColorRect.new()
	o.color = Color(0.02, 0.03, 0.05)
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(o)
	var lbl := Label.new()
	lbl.text = "Contacting fleet command…"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", ACCENT)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(lbl)
	var tw := create_tween().set_loops()
	tw.tween_property(lbl, "modulate:a", 0.35, 0.6).from(1.0)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.6)
	return o

## A small procedural flame + rising embers drawn over a destroyed ship's card. No assets — it
## flickers via _process/_draw so it works under GL Compatibility, and only animates while visible.
class _ShipFire extends Control:
	var _t := 0.0
	var _embers: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		if not visible:
			return
		_t += dt
		if _embers.size() < 7 and randf() < 0.35:
			_embers.append({
				"x": size.x * 0.5 + randf_range(-size.x * 0.16, size.x * 0.16),
				"y": size.y * 0.72, "vx": randf_range(-8.0, 8.0),
				"vy": randf_range(-34.0, -18.0), "life": 0.0, "max": randf_range(0.6, 1.1)})
		for e in _embers:
			e.life += dt
			e.x += e.vx * dt
			e.y += e.vy * dt
		_embers = _embers.filter(func(e: Dictionary): return e.life < e.max)
		queue_redraw()

	func _draw() -> void:
		var cx := size.x * 0.5
		var base := size.y * 0.74
		draw_circle(Vector2(cx, base - size.y * 0.14), size.y * 0.36, Color(1.0, 0.42, 0.12, 0.14))
		var flick: float = sin(_t * 12.0) * 0.5 + cos(_t * 7.3) * 0.5
		var h := size.y * 0.46 * (1.0 + flick * 0.10)
		_flame(cx, base, size.y * 0.20, h, Color(0.85, 0.12, 0.05, 0.85), 0.0)          # red body
		_flame(cx, base, size.y * 0.14, h * 0.80, Color(1.0, 0.50, 0.08, 0.90), 1.7)    # orange
		_flame(cx, base, size.y * 0.08, h * 0.55, Color(1.0, 0.86, 0.28, 0.95), 3.1)    # yellow core
		for e in _embers:
			var a: float = 1.0 - e.life / e.max
			draw_circle(Vector2(e.x, e.y), maxf(1.0, size.y * 0.02 * a), Color(1.0, 0.62, 0.22, a * 0.9))

	func _flame(cx: float, base: float, w: float, h: float, col: Color, phase: float) -> void:
		for i in 5:
			var f := i / 4.0
			var y := base - h * f
			var sway: float = sin(_t * 9.0 + phase + f * 3.0) * w * 0.35 * f
			draw_circle(Vector2(cx + sway, y), w * (1.0 - f * 0.7), col)

func _card(r: Rect2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _slot_style(false))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lay(p, r)
	add_child(p)
	return p

func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.05, 0.08, 0.6)
	bg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("fill", fill)
	return b

func _hotspot(r: Rect2, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	_lay(b, r)
	if DEBUG_LAYOUT:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.7, 1.0, 0.35)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
	else:
		var e := StyleBoxEmpty.new()
		b.add_theme_stylebox_override("normal", e)
		b.add_theme_stylebox_override("hover", e)
		b.add_theme_stylebox_override("pressed", e)
		b.add_theme_stylebox_override("focus", e)
		b.add_theme_stylebox_override("disabled", e)  # stay invisible over baked buttons
	b.pressed.connect(cb)
	add_child(b)
	return b

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 20)
	overlay.add_child(box)
	overlay_label = Label.new()
	overlay_label.add_theme_font_size_override("font_size", 22)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_label)
	overlay_btn = Button.new()
	overlay_btn.custom_minimum_size = Vector2(260, 54)
	overlay_btn.pressed.connect(func(): if overlay_action.is_valid(): overlay_action.call())
	box.add_child(overlay_btn)

## Special-explanation popup: shows a per-special help PNG if present
## (res://assests/UI/help/<special_id>.png), otherwise a text description. Tap anywhere to close.
func _build_help() -> void:
	help_overlay = Control.new()
	help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_overlay.visible = false
	add_child(help_overlay)
	var dismiss := Button.new()   # tap anywhere to close
	dismiss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dismiss.flat = true
	var e := StyleBoxEmpty.new()
	dismiss.add_theme_stylebox_override("normal", e)
	dismiss.add_theme_stylebox_override("hover", e)
	dismiss.add_theme_stylebox_override("pressed", e)
	dismiss.pressed.connect(func(): help_overlay.visible = false)
	help_overlay.add_child(dismiss)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_overlay.add_child(dim)
	# your explanation PNG, centered
	help_img = TextureRect.new()
	help_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	help_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	help_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_img.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	help_img.offset_left = -220; help_img.offset_right = 220
	help_img.offset_top = -278; help_img.offset_bottom = 278
	help_overlay.add_child(help_img)
	# text fallback card (title + description), shown when there's no PNG yet
	var card := VBoxContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -230; card.offset_right = 230; card.offset_top = -90; card.offset_bottom = 90
	card.add_theme_constant_override("separation", 14)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_overlay.add_child(card)
	help_title = Label.new()
	help_title.add_theme_font_size_override("font_size", 24)
	help_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.32))
	help_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(help_title)
	help_text = Label.new()
	help_text.add_theme_font_size_override("font_size", 16)
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.custom_minimum_size = Vector2(460, 0)
	card.add_child(help_text)

func _on_help() -> void:
	if shown != null:
		_show_help(shown.def.special_id)

func _on_fire_help() -> void:
	if shown != null:
		_show_help(shown.def.fire_id)

func _show_help(aid: StringName) -> void:
	var path := "res://assests/UI/help/%s.png" % aid
	if ResourceLoader.exists(path):
		help_img.texture = load(path)
		help_img.visible = true
		help_title.visible = false
		help_text.visible = false
	else:
		help_img.visible = false
		help_title.visible = true
		help_text.visible = true
		help_title.text = str(aid).capitalize()
		help_text.text = ABILITY_DESC.get(aid, "This ship's ability.")
	help_overlay.visible = true

# --- view switching ---

func _set_view(v: View) -> void:
	view = v
	var me := gs.current_player
	if v == View.OWN:
		_disarm()
		board_view.set_markers({})
		board_view.set_own_effects([], [] as Array[Vector2i])
		board_view.set_board(gs.own_board(me), true)
		_after_change()
	else:
		selected = null
		_disarm()
		board_view.set_highlight([])
		board_view.set_ghosts([])
		board_view.set_board(gs.enemy_board(me), false)
		board_view.set_markers(gs.visible_shots(me))
		_update_own_effects()
		if not gs.has_fired and not _any_can_fire():
			_arm(null, &"emergency_shot", false)
	_rebuild_slots()
	_refresh()

func _any_can_fire() -> bool:
	for s in gs.own_board(gs.current_player).ships:
		if s.can_fire():
			return true
	return false

func _refresh() -> void:
	var fleet := view == View.OWN
	fire_help_btn.visible = (not fleet) and shown != null
	# Bottom gauges: ROTATE on the fleet view, SPECIAL + FIRE on the battle view; READY (end turn)
	# only offline — online, firing sends the whole turn. A gauge dims when it can't be used.
	rotate_btn.visible = fleet
	special_btn.visible = not fleet
	# RIGHT bezel: FIRE until you shoot, then READY (end turn) takes its place. Fleet view always
	# offers READY. Online has no separate end turn — firing sends the whole turn.
	fire_btn.visible = (not fleet) and not gs.has_fired
	ready_btn.visible = (not _online) and (fleet or gs.has_fired)
	spec_hot.visible = not fleet
	if fleet:
		_gauge(rotate_btn, selected != null and _points_for(selected) > 0)
		status.text = ""   # movement info lives in the MOVE stat line now
	else:
		if not gs.has_fired:
			_gauge(fire_btn, _aim_ready())
		_gauge(special_btn, shown != null and shown.charge_ready() and not gs.has_used_special)
		if gs.has_fired:
			status.text = "Fired — tap READY to end turn."
		elif armed_id == &"":
			status.text = "Pick a ship to fire, or scout first."
		else:
			status.text = "Aiming %s%s" % [_armed_name(), _hint(armed_id)]
	_gauge(ready_btn, gs.has_fired)   # END TURN lights up only once you've taken your shot
	_update_selected_special()

## Enable/dim a gauge button (disabled gauges dim so only usable actions "light up").
func _gauge(b: TextureButton, on: bool) -> void:
	b.disabled = not on
	b.modulate.a = 1.0 if on else 0.4

# --- fleet slots ---

func _slot_ship(i: int) -> ShipInstance:
	return gs.own_board(gs.current_player).find_by_id(SLOT_ORDER[i])   # includes sunk wrecks

func _rebuild_slots() -> void:
	for i in SLOT_ORDER.size():
		var ship := _slot_ship(i)
		if ship == null:
			slot_thumbs[i].texture = null
			slot_names[i].text = ""
			slot_hots[i].disabled = true
			slot_fires[i].visible = false
			continue
		var side := BoardView.ship_side(ship.def.id)
		slot_thumbs[i].texture = side if side != null else BoardView.ship_sprite(ship.def.id)
		var alive := ship.is_alive()
		slot_names[i].text = ship.def.display_name.to_upper()
		# Destroyed: burnt/desaturated hull, ember-red name, and a burning-wreck overlay.
		slot_thumbs[i].modulate = Color(1, 1, 1, 1) if alive else Color(0.42, 0.34, 0.30, 0.55)
		slot_names[i].modulate = Color(1, 1, 1, 1) if alive else Color(0.95, 0.45, 0.35, 0.6)
		slot_fires[i].visible = not alive
		slot_hots[i].disabled = not (alive and (view == View.OWN or (not gs.has_fired and ship.can_fire())))
	_highlight_slots()

func _highlight_slots() -> void:
	for i in SLOT_ORDER.size():
		var ship := _slot_ship(i)
		var dead := ship != null and not ship.is_alive()
		var sb := _slot_style_dead() if dead else _slot_style(ship != null and ship == shown)
		slot_cards[i].add_theme_stylebox_override("panel", sb)

func _on_slot(i: int) -> void:
	var ship := _slot_ship(i)
	if ship == null or not ship.is_alive():
		return
	if _pick_kind == GameEnums.PowerupKind.RAPID_RELOAD:
		_apply_rapid_reload(ship)   # tapping a fleet slot picks the reload target
		return
	if view == View.OWN:
		_select(ship)
	else:
		_show_selected(ship)
		if gs.has_fired:
			status.text = "Already fired this turn."
		elif ship.can_fire():
			_arm(ship, ship.def.fire_id, false)
		else:
			status.text = "%s is reloading (%d turn(s))." % [ship.def.display_name, ship.reload_cooldown]
			_refresh()

# --- selected-ship panel ---

func _show_selected(ship: ShipInstance) -> void:
	shown = ship
	if ship == null:
		sel_img.texture = null
		hp_lbl.text = ""
		spec_bar.visible = false
		reload_lbl.text = ""
		move_lbl.text = ""
		help_btn.visible = false
		fire_help_btn.visible = false
		_highlight_slots()
		return
	var side := BoardView.ship_side(ship.def.id)
	sel_img.texture = side if side != null else BoardView.ship_sprite(ship.def.id)
	hp_lbl.text = "HP   %d / %d" % [ship.hp(), ship.def.max_health]
	reload_lbl.text = "RELOAD   " + ("Ready" if ship.reload_cooldown == 0 else "%d turn(s)" % ship.reload_cooldown)
	spec_bar.visible = true
	help_btn.visible = true
	_update_selected_special()
	move_lbl.text = "MOVE   " + (_move_status(ship) if view == View.OWN else "—")
	_highlight_slots()

func _update_selected_special() -> void:
	if shown == null:
		return
	var thr := Tiers.charge_threshold(shown.def.charge)
	spec_bar.max_value = thr
	spec_bar.value = mini(shown.charge, thr)

func _on_use_special() -> void:
	if shown != null and view == View.ENEMY and shown.charge_ready() and not gs.has_used_special:
		_arm_special(shown)

# --- primary action (MOVE / FIRE) ---

func _on_primary() -> void:
	if view == View.OWN:
		if selected != null and _points_for(selected) > 0 and not fwd_cells.is_empty():
			_do_move(1)
	else:
		_on_action()

# --- movement (OWN) ---

func _on_cell_clicked(cell: Vector2i) -> void:
	if view == View.OWN:
		_click_own(cell)
	else:
		_click_enemy(cell)

func _click_own(cell: Vector2i) -> void:
	if _pick_kind == GameEnums.PowerupKind.MINE_SWEEP:
		_apply_mine_sweep(cell)                       # tap any cell → clear that sector
		return
	if _pick_kind == GameEnums.PowerupKind.RAPID_RELOAD:
		var picked := gs.own_board(gs.current_player).occupant(cell)
		if picked != null:
			_apply_rapid_reload(picked)               # tap a ship on the board → its reload
		return
	if selected == null:
		var ship := gs.own_board(gs.current_player).occupant(cell)
		if ship != null:
			_select(ship)
		return
	if cell in fwd_cells:
		_do_move(1)
	elif cell in back_cells:
		_do_move(-1)
	elif cell in selected.cells():
		_do_rotate()                              # tap the hull to pivot
	else:
		var other := gs.own_board(gs.current_player).occupant(cell)
		if other != null and other != selected:
			_select(other)                        # switch view freely; move commits lazily

## Selecting a ship only shows its status on the right — it never commits a move. Movement is
## begun lazily the first time you actually move/rotate it, so you can freely browse ships.
func _select(ship: ShipInstance) -> void:
	selected = ship
	_after_change()

func _can_move(ship: ShipInstance) -> bool:
	return ship != null and ship.is_alive() and ship.stunned_turns == 0 \
		and (not gs.has_moved or gs.moving_ship == ship)

func _points_for(ship: ShipInstance) -> int:
	if ship == null:
		return 0
	if gs.moving_ship == ship:
		return gs.move_points_left
	if _can_move(ship):
		return Tiers.movement_points(ship.def.movement)
	return 0

func _ensure_moving(ship: ShipInstance) -> bool:
	return true if gs.moving_ship == ship else gs.begin_move(ship)

func _do_move(dir: int) -> void:
	if selected == null or not _ensure_moving(selected):
		return
	if gs.try_translate(dir):
		Audio.play("move")
		if _online:
			_rec_move_ship = selected.def.id
			_rec_steps.append("F" if dir > 0 else "B")
	_after_change()
	_show_powerup_popups()   # popup for anything grabbed, then prompt any targeted pick

func _do_rotate() -> void:
	if selected == null or not _ensure_moving(selected):
		return
	if gs.try_rotate():
		Audio.play("move")
		if _online:
			_rec_move_ship = selected.def.id
			_rec_steps.append("R")
	_after_change()

func _build_pu_overlay() -> void:
	_pu_overlay = Control.new()
	_pu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pu_overlay.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pu_overlay.add_child(dim)
	var dismiss := Button.new()
	dismiss.flat = true
	dismiss.focus_mode = Control.FOCUS_NONE
	dismiss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dismiss.pressed.connect(_next_pu_popup)
	_pu_overlay.add_child(dismiss)
	_pu_img = TextureRect.new()
	_pu_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pu_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pu_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pu_img.anchor_left = 0.24; _pu_img.anchor_right = 0.76
	_pu_img.anchor_top = 0.13; _pu_img.anchor_bottom = 0.87
	_pu_overlay.add_child(_pu_img)
	add_child(_pu_overlay)

## Show a popup for each powerup just grabbed, then (once dismissed) prompt any targeted pick.
func _show_powerup_popups() -> void:
	for k in gs.last_collected:
		_pu_queue.append(k)
	gs.last_collected.clear()
	if _pu_queue.is_empty():
		_check_picks()
		return
	_next_pu_popup()

func _next_pu_popup() -> void:
	if _pu_queue.is_empty():
		_pu_overlay.visible = false
		_check_picks()
		return
	var k: int = _pu_queue.pop_front()
	var path := "res://assests/powerups/%s" % String(POWERUP_POPUP.get(k, ""))
	if not ResourceLoader.exists(path):
		_next_pu_popup()   # no popup art for this one → skip
		return
	_pu_img.texture = load(path)
	_pu_overlay.visible = true

## After a move: if a Rapid Reload / Mine Sweep was grabbed, prompt the player to pick a target.
func _check_picks() -> void:
	if _pick_kind != -1:
		return
	var k := gs.next_pending_pick()
	if k == -1:
		return
	_pick_kind = k
	if view != View.OWN:
		_set_view(View.OWN)
	if k == GameEnums.PowerupKind.RAPID_RELOAD:
		status.text = "Rapid Reload! Tap a friendly ship to cut its reload."
	else:
		status.text = "Mine Sweep! Tap a sector on your board to clear its mines/drones."
	_refresh()

func _apply_rapid_reload(ship: ShipInstance) -> void:
	if not gs.resolve_rapid_reload(gs.current_player, ship):
		return
	if _online:
		_rec_picks.append({"kind": int(GameEnums.PowerupKind.RAPID_RELOAD), "ship": String(ship.def.id)})
	_finish_pick("Rapid Reload → %s" % ship.def.display_name)

func _apply_mine_sweep(cell: Vector2i) -> void:
	var sector := Sectors.sector_of(cell)
	var n := gs.resolve_mine_sweep(gs.current_player, sector)
	if n < 0:
		return
	Audio.play("mine_sweep")
	if _online:
		_rec_picks.append({"kind": int(GameEnums.PowerupKind.MINE_SWEEP), "sector": [sector.x, sector.y]})
	_finish_pick("Mine Sweep → %s (%d cleared)" % [Sectors.label(sector), n])

func _finish_pick(msg: String) -> void:
	_pick_kind = -1
	_after_change()
	_rebuild_slots()
	_refresh()
	status.text = msg
	_check_picks()   # a move can grab more than one

func _move_status(ship: ShipInstance) -> String:
	if ship.stunned_turns > 0:
		return "STUNNED (%d)" % ship.stunned_turns
	if gs.has_moved and gs.moving_ship != ship:
		return "No moves left"
	return "%d point(s)" % _points_for(ship)

func _after_change() -> void:
	if view != View.OWN:
		return
	board_view.set_board(gs.own_board(gs.current_player), true)
	var hl: Array[Vector2i] = []
	if selected != null:
		hl = selected.cells()
	board_view.set_highlight(hl)
	fwd_cells = []
	back_cells = []
	if selected != null and _points_for(selected) > 0:
		fwd_cells = _stride_cells(selected, 1)
		back_cells = _stride_cells(selected, -1)
	var g: Array[Vector2i] = []
	g.append_array(fwd_cells)
	g.append_array(back_cells)
	board_view.set_ghosts(g)
	_show_selected(selected)
	_refresh()

# --- enemy-side actions (fire + special) ---

func _arm_special(ship: ShipInstance) -> void:
	_arm(ship, ship.def.special_id, true)

func _arm(ship: ShipInstance, id: StringName, is_special: bool) -> void:
	armed_ship = ship
	armed_id = id
	armed_special = is_special
	aim_points = []
	aim_orient = 0
	if ship != null:
		_show_selected(ship)
	_update_aim()

func _disarm() -> void:
	armed_ship = null
	armed_id = &""
	armed_special = false
	aim_points = []
	if board_view != null:
		board_view.clear_preview()
	_show_selected(null)

func _click_enemy(cell: Vector2i) -> void:
	if armed_id == &"" or _action_used():
		return
	if _max_taps(armed_id) > 1:
		if cell in aim_points:
			aim_points.erase(cell)
		elif aim_points.size() < _max_taps(armed_id):
			aim_points.append(cell)
	else:
		aim_points = [cell]
	_update_aim()

## Tap-and-drag aiming for directional weapons (torpedo/line/rolling barrage): the press set the
## origin (via _click_enemy), and dragging away from it sets the FIRE direction — one fluid motion,
## or tap-then-drag. Snaps the drag to the weapon's allowed directions.
func _on_cell_dragged(cell: Vector2i) -> void:
	if view != View.ENEMY or armed_id == &"" or _action_used():
		return
	if not _needs_aim(armed_id) or aim_points.is_empty():
		return
	var delta := cell - aim_points[0]
	if delta == Vector2i.ZERO:
		return
	var o := _dir_from_delta(armed_id, delta)
	if o != aim_orient:
		aim_orient = o
		_update_aim()

## The aim orientation a drag from the origin implies. Torpedo = 4-way N/E/S/W (matching the
## ActionResolver DIRS order: 0=N,1=E,2=S,3=W); line/barrage = horizontal(0) or vertical(1).
func _dir_from_delta(id: StringName, delta: Vector2i) -> int:
	if id == &"torpedo":
		if absi(delta.x) >= absi(delta.y):
			return 1 if delta.x > 0 else 3     # East : West
		return 2 if delta.y > 0 else 0         # South : North
	return 0 if absi(delta.x) >= absi(delta.y) else 1   # horizontal : vertical

func _on_aim() -> void:
	if armed_id == &"":
		return
	aim_orient = (aim_orient + 1) % (4 if armed_id == &"torpedo" else 2)
	_update_aim()

func _update_aim() -> void:
	board_view.set_preview(_action_cells(armed_id), true)
	_refresh()

func _on_action() -> void:
	if not _aim_ready():
		return
	if _online:
		_online_action()
		return
	var me := gs.current_player
	var prev_shots := {}
	for c in gs.visible_shots(me):
		prev_shots[c] = true
	var ability := AbilityRegistry.get_ability(armed_id)
	var res := ability.execute(_action_ctx())
	var hset := {}
	for c in res.hits:
		hset[c] = true
	gs.record_shots(me, res)
	var label := _armed_name()
	# Capture everything the reveal needs while the aim is still armed (_disarm clears it).
	var aid := armed_id
	var spots := aim_points.duplicate()
	var n: int = maxi(1, spots.size())
	var impacts: Array = []
	for i in n:
		impacts.append(_impact_sound(aid, spots, i, hset))
	if armed_special:
		armed_ship.charge = 0
		gs.has_used_special = true
	else:
		if armed_ship != null:
			armed_ship.reload_cooldown = Tiers.reload_turns(armed_ship.def.reload)
		gs.has_fired = true
	_update_own_effects()
	_disarm()
	_rebuild_slots()
	_refresh()
	var result_line := ""
	if res.info != "":
		result_line = res.info
	elif not res.hits.is_empty() or not res.sunk.is_empty():
		result_line = "%s — %d hit(s)%s." % [label, res.hits.size(),
			(", SUNK %d!" % res.sunk.size()) if not res.sunk.is_empty() else ""]
	else:
		result_line = "%s: %s" % [label, res.message]
	await _present_shot(aid, n, impacts, prev_shots, me, result_line, spots)
	_check_win()

## Gun/torpedo shots that go through the alarm → fire → impact anticipation sequence.
const SHOT_IDS := [&"cross_shot", &"line_shot", &"single_shot", &"emergency_shot", &"torpedo",
	&"drone_shot"]

## How long the fire alarm rings before a gun/torpedo shot actually lands.
const ALARM_SECONDS := 3.0

## Reveal a shot with anticipation: for guns/torpedoes the alarm rings for ALARM_SECONDS, THEN the
## shot lands — fog markers flip, impacts play, and the fire/impact sounds fire. Non-gun abilities
## (carrier flyover, placement, scans) land immediately. `result_line` shows once it lands.
func _present_shot(id: StringName, n: int, impacts: Array, prev_shots: Dictionary, me: int,
		result_line: String, aim_cells: Array = []) -> void:
	if id in SHOT_IDS:
		status.text = "Firing…"
		if _gframe != null: _gframe.flash_alert(7)   # blink the alert light through the alarm
		Audio.play_for("fire_charge", ALARM_SECONDS, -12.0)   # quieter alarm, cut when we fire
		await get_tree().create_timer(ALARM_SECONDS).timeout
	_fire_audio(id, n, impacts)
	var now_shots := gs.visible_shots(me)
	board_view.set_markers(now_shots)
	var new_cells: Array = []
	var hit_cells: Array = []
	for c in now_shots:
		if not prev_shots.has(c):
			new_cells.append(c)
			if now_shots[c].hit:
				hit_cells.append(c)
	if id == &"multi_shot":
		board_view.play_flyover(new_cells, hit_cells, BoardView.carrier_plane(), BoardView.AXIS_Y)
	elif id == &"air_strafe" and not aim_cells.is_empty():
		# The strafe hits the target's row AND column: one bomber runs the row along X, then 2s later a
		# second bomber runs the column along Y. Split the cells by the aim point (center goes with the row).
		var plane := BoardView.carrier_plane()
		var center: Vector2i = aim_cells[0]
		var row: Array = []
		var col: Array = []
		for c in new_cells:
			if c.y == center.y:
				row.append(c)
			elif c.x == center.x:
				col.append(c)
		board_view.play_flyover(row, hit_cells, plane, BoardView.AXIS_X, 0.0)
		board_view.play_flyover(col, hit_cells, plane, BoardView.AXIS_Y, 2.0)
	elif id == &"torpedo" and not aim_cells.is_empty() and not new_cells.is_empty():
		# Run a torpedo through the water from the launch point to where it struck (or ran out).
		board_view.play_torpedo(aim_cells[0], new_cells[0], not hit_cells.is_empty())
	elif id == &"drop_mines" or id == &"mine_lay":
		if not new_cells.is_empty():
			board_view.play_blast(new_cells)          # detonated on placement — explosion at the source
		else:
			board_view.play_mine_drop(aim_cells)      # laid hidden — splash into the water
	else:
		board_view.play_impacts(new_cells, hit_cells)
	if _gframe != null: _gframe.flash_alert()   # red light on our attack
	status.text = result_line

## Play a shot's fire + impact sounds (the alarm already rang in _present_shot). One fire sound PER
## chosen spot (bigger/multi-spot guns fire multiple times), a travel pause, then per-spot impact.
## `impacts` is the precomputed impact-sound key per spot (explosion on a hit, splash on a miss).
func _fire_audio(id: StringName, n: int, impacts: Array) -> void:
	# Carrier: jets fly over, with an impact after each pass.
	if id == &"multi_shot" or id == &"air_strafe":
		Audio.play("flyover")
		for i in n:
			Audio.play_delayed(impacts[i], 0.6 + i * 0.35)
		return

	# Placement / scan abilities: a single immediate cue, no impact.
	if not (id in SHOT_IDS):
		var cue := "fire"
		match id:
			&"mine_lay", &"drop_mines": cue = "mine_drop"
			&"deploy_drones": cue = "drone"
			&"active_radar": cue = "sonar"
			&"barrage_zone", &"rolling_barrage": cue = "barrage"
		Audio.play(cue)
		return

	# Gun/torpedo: a boom per spot, then delayed impacts.
	var shot := "fire"
	if id == &"torpedo": shot = "torpedo"
	elif id == &"drone_shot": shot = "emp"
	for i in n:
		Audio.play_delayed(shot, i * 0.13)
	var impact_at: float = 0.5 + (n - 1) * 0.13     # after the last boom, let it travel
	for i in n:
		Audio.play_delayed(impacts[i], impact_at + i * 0.18)

## Explosion if the i-th spot struck something, else splash.
func _impact_sound(id: StringName, spots: Array, i: int, hitset: Dictionary) -> String:
	var point: Vector2i = spots[i] if i < spots.size() else spots[0]
	var cells: Array
	match id:
		&"cross_shot": cells = Blast.plus_cells(point)
		&"multi_shot": cells = [point]
		_: cells = _action_cells(id)                 # single-spot abilities: the whole pattern
	for c in cells:
		if hitset.has(c):
			return "torpedo_hit" if id == &"torpedo" else "hit"
	return "splash"

## Online: a special is queued (resolved by the server on submit); the shot submits the whole turn.
func _online_action() -> void:
	if armed_special:
		_rec_special_id = armed_id
		_rec_special_aim = aim_points.duplicate()
		_rec_special_orient = aim_orient
		gs.has_used_special = true
		if armed_ship != null:
			armed_ship.charge = 0            # reflect it in the UI; the server is authoritative
		status.text = "Special queued — now take your shot to send your turn."
		_disarm()
		_rebuild_slots()
		_refresh()
	else:
		_submit_online_turn()

## Build the recorded turn (move + optional special + this shot) and send it to the server, then
## show the returned shot result on our fog board.
func _submit_online_turn() -> void:
	var me := gs.current_player
	var fired := _action_cells(armed_id)
	var t := Turn.new()
	t.player = me
	t.move_ship = _rec_move_ship
	t.move_steps = _rec_steps
	t.special_id = _rec_special_id
	t.special_aim = _rec_special_aim
	t.special_orient = _rec_special_orient
	t.powerup_picks = _rec_picks
	t.fire_id = armed_id
	t.fire_aim = aim_points.duplicate()
	t.fire_orient = aim_orient
	var r: Dictionary = await Net.submit_turn(_match_id, t)
	if not r.get("ok", false):
		status.text = "Move rejected by the server: %s" % r.get("reason", "illegal")
		return
	var hitset := {}
	for c in r.get("hits", []):
		hitset[Vector2i(int(c[0]), int(c[1]))] = true
	var aid := armed_id
	var spots := aim_points.duplicate()
	var n: int = maxi(1, spots.size())
	var impacts: Array = []
	for i in n:
		impacts.append(_impact_sound(aid, spots, i, hitset))
	var newc: Array = []
	var hitc: Array = []
	for c in fired:
		gs.shots[me][c] = {"hit": hitset.has(c), "turn": gs.turn_number}
		newc.append(c)
		if hitset.has(c):
			hitc.append(c)
	gs.has_fired = true
	_disarm()
	_refresh()
	if aid in SHOT_IDS:
		status.text = "Firing…"
		if _gframe != null: _gframe.flash_alert(7)   # blink the alert light through the alarm
		Audio.play_for("fire_charge", ALARM_SECONDS, -12.0)   # quieter alarm, cut when we fire
		await get_tree().create_timer(ALARM_SECONDS).timeout
	_fire_audio(aid, n, impacts)
	board_view.set_markers(gs.visible_shots(me))
	board_view.play_impacts(newc, hitc)
	if _gframe != null: _gframe.flash_alert()   # red light on our attack
	if int(r.get("winner", -1)) != -1:
		_show_result(int(r.get("winner", -1)) == me, int(r.get("reward", -1)))   # match ended
		return
	status.text = "Turn sent! Waiting for your opponent…"
	await get_tree().create_timer(1.6).timeout
	get_tree().change_scene_to_file("res://scenes/ui/current_games_screen.tscn")

func _update_own_effects() -> void:
	var me := gs.current_player
	var eb := gs.enemy_board(me)
	var oe: Array = []
	var bs: Array[Vector2i] = []
	for e in eb.effects:
		if e.placer != me:
			continue
		if e is Mine:
			oe.append({"pos": (e as Mine).cell, "kind": 0, "text": ""})
		elif e is Drone:
			var d := e as Drone
			oe.append({"pos": d.cell, "kind": 1, "text": str(d.distance_to_nearest(eb))})
		elif e is Barrage:
			bs.append((e as Barrage).sector)
	board_view.set_own_effects(oe, bs)

## Online defender's opener: sound the siren, then replay the opponent's last shots landing on YOUR
## own fleet (explosion on a hit, splash on a miss), then hand the turn over. No-op on the very first
## turn (nothing has hit you yet). Input is blocked until the replay finishes.
func _play_incoming() -> void:
	var inc: Dictionary = gs.incoming[gs.current_player]
	var shots: Array = inc.get("shots", []) if not inc.is_empty() else []
	if shots.is_empty():
		return
	var blocker := Control.new()   # eat taps while the attack plays out
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	_set_view(View.OWN)
	status.text = "⚠ INCOMING FIRE!"
	if _gframe != null: _gframe.flash_alert(7)   # blink the alert light through the siren
	Audio.play_for("fire_charge", ALARM_SECONDS, -12.0)   # quieter siren
	await get_tree().create_timer(ALARM_SECONDS).timeout
	var cells: Array = []
	var hits: Array = []
	for s in shots:
		cells.append(s.cell)
		if s.hit:
			hits.append(s.cell)
	board_view.play_impacts(cells, hits)
	if _gframe != null: _gframe.flash_alert()   # red light on incoming fire
	Audio.play("fire")
	for i in cells.size():
		Audio.play_delayed("hit" if cells[i] in hits else "splash", 0.4 + i * 0.16)
	await get_tree().create_timer(1.4).timeout
	blocker.queue_free()
	gs.incoming[gs.current_player] = {}   # consumed this session
	var n := hits.size()
	status.text = ("They hit you %d time(s). Your turn." % n) if n > 0 else "They missed! Your turn."

## Hot-seat win check, called after the current player's shot resolves. The shooter is the winner
## (they can only win by sinking the enemy on their own turn).
func _check_win() -> void:
	if gs.winner() == -1:
		return
	_show_result(gs.winner() == gs.current_player)

## The full result reveal — shared by hot-seat, the online winner (right after their killing shot),
## and the online loser (on opening a finished match). A beat to watch the final ship go down, then
## fade-to-black → VICTORY/DEFEAT → red flash → reward. Winner → spin wheel; loser → menu (+coins).
## `server_reward` >= 0 is the amount the referee already rolled (online) — the wheel is rigged to
## it and nothing is banked locally (the server persists it). -1 means hot-seat: roll + bank locally.
func _show_result(i_won: bool, server_reward: int = -1) -> void:
	Audio.stop_ambient()   # game over — the ocean cuts out for the reveal
	await get_tree().create_timer(1.2).timeout   # beat: watch the final ship sink
	var rs := ResultScreen.new()
	rs.won = i_won
	if i_won:
		rs.image_path = "res://assests/UI/victory.png"
		rs.button_text = "SPIN THE WHEEL"
	else:
		var payout: int = server_reward if server_reward >= 0 else Rewards.CONSOLATION
		if not _online:
			Cosmetics.add_coins(payout)   # hot-seat banks locally; online the server persists it
		rs.image_path = "res://assests/UI/loss.png"
		rs.coins = payout
		rs.button_text = "CONTINUE"
	add_child(rs)
	rs.home.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	rs.dismissed.connect(func():
		rs.queue_free()
		if i_won:
			var rw := RewardWheel.new()
			add_child(rw)
			rw.collected.connect(func(_amt): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
			rw.begin(server_reward, not _online)   # server_reward rigs the wheel online; -1 rolls locally
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))

func _on_end_turn() -> void:
	if not gs.has_fired:
		status.text = "You must fire before ending your turn (every turn takes a shot)."
		if view != View.ENEMY:
			_set_view(View.ENEMY)
		return
	gs.end_turn()
	overlay_label.text = "End of turn.\nPass the device to Player %d." % (gs.current_player + 1)
	overlay_btn.text = "Player %d: Take Turn" % (gs.current_player + 1)
	overlay_action = _show_turn
	overlay.visible = true

func _show_turn() -> void:
	selected = null
	_disarm()
	overlay.visible = false
	_set_view(View.OWN)

# --- action math ---

func _action_used() -> bool:
	return gs.has_used_special if armed_special else gs.has_fired

func _aim_ready() -> bool:
	return armed_id != &"" and not _action_used() and not aim_points.is_empty()

func _armed_name() -> String:
	return armed_ship.def.display_name if armed_ship != null else "Emergency Shot"

func _max_taps(id: StringName) -> int:
	match id:
		&"multi_shot": return 4
		&"drop_mines", &"rolling_barrage": return 3
		&"deploy_drones", &"cross_shot": return 2
	return 1

func _needs_aim(id: StringName) -> bool:
	return id == &"line_shot" or id == &"torpedo" or id == &"rolling_barrage"

# Aim resolution now lives in the shared ActionResolver so the UI preview and the server referee
# reach exactly the same cells.
func _action_cells(id: StringName) -> Array[Vector2i]:
	return ActionResolver.cells_for(id, aim_points, aim_orient)

func _action_ctx() -> ActionContext:
	return ActionResolver.context(gs, gs.current_player, armed_ship, armed_id, aim_points, aim_orient)

func _aim_label(id: StringName) -> String:
	if id == &"line_shot" or id == &"rolling_barrage":
		return "Horizontal" if aim_orient % 2 == 0 else "Vertical"
	if id == &"torpedo":
		return _arrow(DIRS[aim_orient])
	return "-"

func _hint(id: StringName) -> String:
	match id:
		&"multi_shot": return " (up to 4 spots)"
		&"line_shot": return " (tap start, drag to aim)"
		&"torpedo": return " (tap start, drag direction)"
		&"cross_shot": return " (TWO + blasts — pick 2 spots)"
		&"mine_lay": return " (lay a hidden mine)"
		&"air_strafe": return " (hits its row + column)"
		&"barrage_zone": return " (pick a sector to bombard 3 turns)"
		&"active_radar": return " (pick a sector to scan)"
		&"drop_mines": return " (up to 3 mines)"
		&"deploy_drones": return " (up to 2 drones)"
		&"rolling_barrage": return " (up to 3 volleys; Aim = H/V)"
		&"emergency_shot": return " (1-spot fallback — no ship can fire)"
	return ""

# --- movement helpers ---

func _stride_cells(ship: ShipInstance, sign: int) -> Array[Vector2i]:
	var dir := ship.forward_vector() * sign
	var step := (ship.def.length + 1) / 2
	for s in range(1, step + 1):
		for c in ship.footprint_at(ship.origin + dir * s):
			if not Sectors.in_bounds(c) or _blocked(c, ship):
				return []
	return ship.footprint_at(ship.origin + dir * step)

func _blocked(cell: Vector2i, ship: ShipInstance) -> bool:
	var occ := gs.own_board(gs.current_player).occupant(cell)
	return occ != null and occ != ship

func _nothing_spent() -> bool:
	return selected != null \
		and gs.move_points_left == Tiers.movement_points(selected.def.movement) \
		and not gs.used_free_rotation

func _reset_move() -> void:
	gs.has_moved = false
	gs.moving_ship = null
	gs.move_points_left = 0
	gs.used_free_rotation = false
	selected = null

func _arrow(v: Vector2i) -> String:
	if v == Vector2i(0, -1): return "↑"
	if v == Vector2i(0, 1): return "↓"
	if v == Vector2i(1, 0): return "→"
	return "←"

# --- standalone testing ---

func _selftest() -> void:
	var me := gs.current_player
	_set_view(View.ENEMY)
	var p0 := gs.current_player
	_on_end_turn()
	var blocked := gs.current_player == p0 and not gs.has_fired
	_arm(_own(&"battleship"), &"cross_shot", false)
	aim_points = [Vector2i(3, 4), Vector2i(12, 12)]
	_on_action()
	print("Self-test: end-before-fire blocked=%s; twin-cross targeted=%d (expect 10), has_fired=%s" % [
		blocked, gs.visible_shots(me).size(), gs.has_fired])
	get_tree().quit()

func _own(id: StringName) -> ShipInstance:
	for s in gs.own_board(gs.current_player).ships:
		if s.def.id == id:
			return s
	return null

func _demo_state() -> GameState:
	var g := GameState.new()
	for owner in 2:
		_place(g, &"battleship", owner, Vector2i(2, 2))
		_place(g, &"aircraft_carrier", owner, Vector2i(8, 2))
		_place(g, &"cruiser", owner, Vector2i(14, 6))
		_place(g, &"submarine", owner, Vector2i(4, 14))
		_place(g, &"destroyer", owner, Vector2i(10, 14))
		_place(g, &"drone_ship", owner, Vector2i(16, 15))
	return g

func _place(g: GameState, id: StringName, owner: int, origin: Vector2i) -> void:
	for d in ShipCatalog.all():
		if d.id == id:
			g.boards[owner].place(ShipInstance.create(d, owner, origin, GameEnums.Facing.NORTH))
			return
