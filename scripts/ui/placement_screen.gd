## Ship-placement screen (PNG-framed, matches the battle HUD). Player 1 places their fleet, hands
## the device to Player 2, then the battle starts. Tap a ship card to pick it up, tap the board to
## drop it (green = fits, red = blocked), ROTATE to turn it, READY when all six are down. A placed
## ship can be tapped (card or board) to pick it back up.
extends Control

const FRAME_W := 1536.0
const FRAME_H := 1024.0
const CELL_MAX := 20

## Slot order top-to-bottom (matches the battle screen's fleet list).
const SHIP_ORDER: Array[StringName] = [
	&"battleship", &"aircraft_carrier", &"destroyer", &"cruiser", &"submarine", &"drone_ship"]

# layout (fractions of the letterboxed frame) — same frame as the turn screen
const BOARD := Rect2(0.272, 0.132, 0.448, 0.720)
const SEL_IMG := Rect2(0.793, 0.198, 0.174, 0.262)
const MOVE_VAL_POS := Vector2(0.789, 0.535)
const SPEC_VAL_POS := Vector2(0.789, 0.626)
const HP_VAL_POS := Vector2(0.789, 0.720)
const RELOAD_VAL_POS := Vector2(0.789, 0.815)
const SLOT_X := 0.020
const SLOT_W := 0.216
const SLOT_TOP := 0.205
const SLOT_PITCH := 0.112
const THUMB_W := 0.080
const ROTATE_BTN := Rect2(0.315, 0.905, 0.170, 0.072)
const READY_BTN := Rect2(0.515, 0.905, 0.170, 0.072)
const ACCENT := Color(0.470, 0.680, 0.880)

var gs: GameState
var current_player := 0
var armed_id: StringName = &""
var armed_facing: GameEnums.Facing = GameEnums.Facing.NORTH
var hover_cell := Vector2i(-1, -1)
var shown: StringName = &""

var _gframe: GameFrame
var rotate_btn: TextureButton
var ready_btn: TextureButton
var board_view: BoardView
var slot_thumbs: Array[TextureRect] = []
var slot_names: Array[Label] = []
var slot_cards: Array[Panel] = []
var slot_hots: Array[Button] = []
var sel_img: TextureRect
var move_lbl: Label
var spec_lbl: Label
var hp_lbl: Label
var reload_lbl: Label
var status: Label
var overlay: Control
var overlay_title: Label
var overlay_label: Label
var overlay_btn: Button
var _intro := false   # overlay is the pre-placement briefing (continue just dismisses to the board)
var _fr := Rect2()

func _ready() -> void:
	gs = GameState.new()
	_fr = _frame_rect()
	_build_ui()
	_start_player(0)
	if "--shot" in OS.get_cmdline_user_args():
		await _capture()
		return
	if DisplayServer.get_name() == "headless":
		print("Placement screen loaded. Ships to place: %s" % str(SHIP_ORDER))
		get_tree().quit()
		return
	_show_intro()   # a briefing beat so New Game doesn't drop you cold onto a board you've seen

func _capture() -> void:
	gs.boards[0].place(ShipInstance.create(_def(&"battleship"), 0, Vector2i(2, 2), GameEnums.Facing.NORTH))
	gs.boards[0].place(ShipInstance.create(_def(&"submarine"), 0, Vector2i(10, 4), GameEnums.Facing.NORTH))
	board_view.set_board(gs.boards[0], true)
	_on_ship(&"aircraft_carrier")
	hover_cell = Vector2i(5, 11)
	_preview_at(hover_cell)
	_refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_place.png")
	get_tree().quit()

func _frame_rect() -> Rect2:
	return Rect2(Vector2.ZERO, get_viewport_rect().size)   # GameFrame fills the viewport

func _px(r: Rect2) -> Rect2:
	return Rect2(_fr.position + r.position * _fr.size, r.size * _fr.size)

func _lay(c: Control, r: Rect2) -> void:
	var p := _px(r)
	c.position = p.position
	c.size = p.size

# --- UI ---

func _build_ui() -> void:
	_gframe = GameFrame.new()
	add_child(_gframe)
	_gframe.fleet_btn.visible = false    # placement is a single view — no My Fleet/Enemy toggle
	_gframe.battle_btn.visible = false

	# Board in the CENTER panel.
	var br := _px(GameFrame.CENTER)
	var cs := minf(br.size.x, br.size.y) / float(CELL_MAX)
	board_view = BoardView.new()
	board_view.cell_size = cs
	board_view.position = br.position + (br.size - Vector2.ONE * cs * CELL_MAX) * 0.5
	board_view.cell_clicked.connect(_on_cell_clicked)
	board_view.cell_hovered.connect(_on_cell_hovered)
	add_child(board_view)

	# LEFT panel: fleet list (cinematic thumb + name), full-row hotspot each.
	var L := GameFrame.LEFT
	var pitch := L.size.y / float(SHIP_ORDER.size())
	for i in SHIP_ORDER.size():
		var top := L.position.y + i * pitch
		slot_cards.append(_card(Rect2(L.position.x, top + 0.004, L.size.x, pitch - 0.008)))
		var thumb := TextureRect.new()
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.texture = BoardView.ship_side(SHIP_ORDER[i])
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
		var hb := StyleBoxFlat.new()
		hb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.08)
		hb.set_border_width_all(2)
		hb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9)
		hb.set_corner_radius_all(6)
		hot.add_theme_stylebox_override("hover", hb)
		slot_hots.append(hot)

	# RIGHT panel: selected-ship details (image + captioned stats).
	var R := GameFrame.RIGHT
	sel_img = TextureRect.new()
	sel_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sel_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sel_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lay(sel_img, Rect2(R.position.x + 0.006, R.position.y + 0.012, R.size.x - 0.012, R.size.y * 0.30))
	add_child(sel_img)
	hp_lbl = _detail_label(R.position.y + R.size.y * 0.38)
	move_lbl = _detail_label(R.position.y + R.size.y * 0.50)
	spec_lbl = _detail_label(R.position.y + R.size.y * 0.62)
	reload_lbl = _detail_label(R.position.y + R.size.y * 0.74)

	# Status line under the board.
	status = Label.new()
	status.add_theme_color_override("font_color", ACCENT)
	status.add_theme_font_size_override("font_size", 13)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lay(status, Rect2(GameFrame.CENTER.position.x, GameFrame.CENTER.position.y + GameFrame.CENTER.size.y + 0.002, GameFrame.CENTER.size.x, 0.028))
	add_child(status)

	# Bottom-console gauges: ROTATE (left bezel) + READY (right bezel).
	rotate_btn = _bottom_btn("rotate_button.png", 0.285, _on_rotate)
	ready_btn = _bottom_btn("ready_button.png", 0.715, _on_ready)

	_build_overlay()

## A right-panel stat label at a vertical fraction of the viewport.
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

## A round gauge button seated in a bottom-console bezel at horizontal fraction `cx`.
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

func _stat(pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 15)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = _fr.position + pos * _fr.size
	add_child(l)
	return l

func _slot_style(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.033, 0.04) if sel else Color(0.018, 0.02, 0.026)
	sb.set_border_width_all(2 if sel else 1)
	sb.border_color = Color(1.0, 0.83, 0.36) if sel else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	sb.set_corner_radius_all(7)
	return sb

func _card(r: Rect2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _slot_style(false))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lay(p, r)
	add_child(p)
	return p

func _hotspot(r: Rect2, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	_lay(b, r)
	var e := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", e)
	b.add_theme_stylebox_override("hover", e)
	b.add_theme_stylebox_override("pressed", e)
	b.add_theme_stylebox_override("focus", e)
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
	var center := CenterContainer.new()   # keeps the box centered no matter how big its text gets
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size", 26)
	overlay_title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.36))   # briefing gold
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(overlay_title)
	overlay_label = Label.new()
	overlay_label.add_theme_font_size_override("font_size", 18)
	overlay_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_label.custom_minimum_size = Vector2(520, 0)
	box.add_child(overlay_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)
	overlay_btn = Button.new()
	overlay_btn.custom_minimum_size = Vector2(260, 54)
	overlay_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # stay 260 wide, centered (not full-width)
	overlay_btn.pressed.connect(_on_overlay_continue)
	box.add_child(overlay_btn)

## Show the full-screen overlay with a title, body, and continue button. `intro` marks it as the
## pre-placement briefing (its continue just dismisses to the board); otherwise it's the hot-seat flow.
func _show_overlay(title: String, body: String, btn: String, intro: bool) -> void:
	overlay_title.text = title
	overlay_label.text = body
	overlay_btn.text = btn
	_intro = intro
	overlay.visible = true

## Briefing beat shown every time you enter placement, so New Game frames the flow (deploy → invite)
## instead of dropping you cold onto a board you've already seen. Hot-seat (dev) skips it.
func _show_intro() -> void:
	match MatchSession.placement_mode:
		"online_create":
			_show_overlay("Chart a New Battle",
				"Position your fleet, then send the challenge to a friend.", "Deploy Fleet", true)
		"online_join":
			_show_overlay("Answer the Challenge",
				"Your friend deployed their fleet. Deploy yours to begin the battle.", "Deploy Fleet", true)

# --- flow ---

func _start_player(p: int) -> void:
	current_player = p
	armed_id = &""
	board_view.clear_preview()
	board_view.set_board(gs.boards[p], true)
	overlay.visible = false
	_show_selected(&"")
	_refresh()

func _refresh() -> void:
	_refresh_slots()
	if armed_id != &"":
		status.text = "Placing %s — tap the board; ROTATE to turn." % _def(armed_id).display_name
	elif _all_placed():
		match MatchSession.placement_mode:
			"online_create":
				status.text = "Fleet ready — tap READY to get your invite code."
			"online_join":
				status.text = "Fleet ready — tap READY to enter the battle."
			_:
				status.text = "Fleet ready — tap READY (or a ship to reposition)."
	elif MatchSession.placement_mode == "hotseat":
		status.text = "Player %d: tap a ship to place it." % (current_player + 1)
	else:
		status.text = "Tap a ship to place your fleet."

func _refresh_slots() -> void:
	for i in SHIP_ORDER.size():
		var id: StringName = SHIP_ORDER[i]
		var placed := _is_placed(id)
		slot_names[i].text = ("✓ " if placed else "") + _def(id).display_name.to_upper()
		slot_thumbs[i].modulate = Color(1, 1, 1, 0.4) if placed else Color(1, 1, 1, 1)
		slot_names[i].modulate = Color(0.6, 0.85, 0.6) if placed else Color(1, 1, 1, 1)
		slot_cards[i].add_theme_stylebox_override("panel", _slot_style(id == armed_id))

func _show_selected(id: StringName) -> void:
	shown = id
	if id == &"":
		sel_img.texture = null
		move_lbl.text = ""; spec_lbl.text = ""; hp_lbl.text = ""; reload_lbl.text = ""
		return
	var d := _def(id)
	sel_img.texture = BoardView.ship_side(id)
	hp_lbl.text = "HP   %d" % d.max_health
	move_lbl.text = "MOVE   %d pt(s)" % Tiers.movement_points(d.movement)
	spec_lbl.text = "SPECIAL   %s" % str(d.special_id).capitalize()
	reload_lbl.text = "RELOAD   %d turn(s)" % Tiers.reload_turns(d.reload)

func _on_slot(i: int) -> void:
	_on_ship(SHIP_ORDER[i])

func _on_ship(id: StringName) -> void:
	if _is_placed(id):
		gs.boards[current_player].remove(_find_ship(id))   # pick it back up
	armed_id = id
	armed_facing = GameEnums.Facing.NORTH
	board_view.set_board(gs.boards[current_player], true)
	_show_selected(id)
	_preview_at(hover_cell)
	_refresh()

func _on_cell_hovered(cell: Vector2i) -> void:
	hover_cell = cell
	_preview_at(cell)

func _on_cell_clicked(cell: Vector2i) -> void:
	if armed_id == &"":
		var ship := gs.boards[current_player].occupant(cell)
		if ship != null:
			_on_ship(ship.def.id)
		return
	var inst := ShipInstance.create(_def(armed_id), current_player, cell, armed_facing)
	if _fits(inst.cells()):
		gs.boards[current_player].place(inst)
		armed_id = &""
		board_view.clear_preview()
		board_view.set_board(gs.boards[current_player], true)
		_refresh()
	else:
		status.text = "Can't place there — off-board or overlapping."

func _on_rotate() -> void:
	if armed_id == &"":
		return
	armed_facing = ((int(armed_facing) + 1) % 4) as GameEnums.Facing
	_preview_at(hover_cell)

func _on_ready() -> void:
	if not _all_placed():
		status.text = "Place all six ships first."
		return
	match MatchSession.placement_mode:
		"online_create":
			_online_create()
		"online_join":
			_online_join()
		_:
			# hot-seat (dev): pass the device between players.
			if current_player == 0:
				_show_overlay("Fleet Locked In", "Pass the device to Player 2.", "Player 2: Place Fleet", false)
			else:
				_show_overlay("Battle Stations", "Both fleets are placed.", "Start Battle", false)

## Online host: create the match with our fleet, then go to the invite screen to share the code.
func _online_create() -> void:
	var ships := Placement.from_board(gs.boards[current_player])
	var r: Dictionary = await Net.create_match(ships)
	if not r.get("ok", false):
		status.text = "Couldn't create match: %s" % r.get("reason", "error")
		return
	MatchSession.invite_code = String(r.get("invite_code", ""))
	get_tree().change_scene_to_file("res://scenes/ui/invite_screen.tscn")

## Online guest: submit our fleet to the match we joined, then wait in Current Games.
func _online_join() -> void:
	var ships := Placement.from_board(gs.boards[current_player])
	var r: Dictionary = await Net.submit_placement(MatchSession.match_id, ships)
	if not r.get("ok", false):
		status.text = "Couldn't submit fleet: %s" % r.get("reason", "error")
		return
	get_tree().change_scene_to_file("res://scenes/ui/current_games_screen.tscn")

func _on_overlay_continue() -> void:
	if _intro:                       # briefing beat — just reveal the board
		_intro = false
		overlay.visible = false
		return
	if current_player == 0:
		_start_player(1)
	else:
		MatchSession.state = gs
		MatchSession.online = false   # hot-seat match
		get_tree().change_scene_to_file("res://scenes/ui/turn_screen.tscn")

# --- helpers ---

func _preview_at(cell: Vector2i) -> void:
	if armed_id == &"" or not Sectors.in_bounds(cell):
		board_view.clear_preview()
		return
	var inst := ShipInstance.create(_def(armed_id), current_player, cell, armed_facing)
	board_view.set_preview(inst.cells(), _fits(inst.cells()))

func _fits(cells: Array[Vector2i]) -> bool:
	for c in cells:
		if not Sectors.in_bounds(c) or gs.boards[current_player].occupant(c) != null:
			return false
	return true

func _all_placed() -> bool:
	return gs.boards[current_player].ships.size() == SHIP_ORDER.size()

func _is_placed(id: StringName) -> bool:
	return _find_ship(id) != null

func _find_ship(id: StringName) -> ShipInstance:
	for ship in gs.boards[current_player].ships:
		if ship.def.id == id:
			return ship
	return null

func _def(id: StringName) -> ShipDef:
	for d in ShipCatalog.all():
		if d.id == id:
			return d
	return null
