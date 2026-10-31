## Current Games: the player's in-progress async matches (via the Net facade), with a New Match
## (shareable invite code) and Join-with-code flow. Backed by LocalServer now; unchanged when the
## real backend lands. Tapping a your-turn match will open the online battle screen — that turn-
## submission wiring is the next slice, so for now it toasts.
extends Control

const STATUS_TEXT := {
	"your_turn": "YOUR TURN", "their_turn": "Their turn", "waiting": "Waiting for opponent",
	"finished": "Finished",
}
const STATUS_COLOR := {
	"your_turn": Color(1.0, 0.83, 0.36), "their_turn": Color(0.62, 0.70, 0.80),
	"waiting": Color(0.35, 0.72, 0.95), "finished": Color(0.5, 0.55, 0.62),
}

var list_box: VBoxContainer
var _toast: Label
var _code_overlay: Control
var _code_label: Label
var _join_overlay: Control
var _join_input: LineEdit

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assests/UI/Main_menu.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.modulate = Color(0.30, 0.35, 0.43)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var title := Label.new()
	title.text = "CURRENT GAMES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_anchor(title, 0.30, 0.055, 0.70, 0.13)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_anchor(scroll, 0.17, 0.16, 0.83, 0.73)
	add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)

	_button("＋  New Match", 0.30, 0.775, 0.485, 0.85, _new_match)
	_button("Join with Code", 0.515, 0.775, 0.70, 0.85, _open_join)

	var home := Button.new()
	home.text = "⌂ Home"
	home.focus_mode = Control.FOCUS_NONE
	_anchor(home, 0.02, 0.03, 0.13, 0.095)
	home.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	add_child(home)

	_build_code_overlay()
	_build_join_overlay()
	_toast = _make_toast()
	add_child(_toast)

	_refresh()

	if OS.get_cmdline_args().has("--shot"):
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_games.png")
		get_tree().quit()

func _refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()
	var matches: Array = await Net.list_matches()
	if matches.is_empty():
		var empty := Label.new()
		empty.text = "No games yet — start one and share the code with a friend."
		empty.add_theme_color_override("font_color", Color(0.7, 0.77, 0.85))
		empty.custom_minimum_size = Vector2(0, 120)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		list_box.add_child(empty)
		return
	for m in matches:
		list_box.add_child(_row(m))

func _row(m: Dictionary) -> Control:
	var status: String = m.status
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 66)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.96)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2 if m.your_turn else 1)
	sb.border_color = STATUS_COLOR.get(status, Color.WHITE) if m.your_turn else Color(0.35, 0.5, 0.7, 0.4)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	row.add_theme_stylebox_override("panel", sb)

	var opp: String = m.opponent if String(m.opponent) != "" else "—"
	var vs := Label.new()
	vs.text = "vs %s" % opp if status != "waiting" else "Waiting for a friend"
	vs.add_theme_font_size_override("font_size", 19)
	vs.anchor_left = 0.02; vs.anchor_right = 0.5; vs.anchor_top = 0.12; vs.anchor_bottom = 0.6
	row.add_child(vs)

	var badge := Label.new()
	badge.text = STATUS_TEXT.get(status, status)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", STATUS_COLOR.get(status, Color.WHITE))
	badge.anchor_left = 0.02; badge.anchor_right = 0.5; badge.anchor_top = 0.55; badge.anchor_bottom = 0.95
	if status != "waiting":
		badge.text += "   ·   turn %d" % m.turn
	row.add_child(badge)

	var act := Button.new()
	act.focus_mode = Control.FOCUS_NONE
	act.anchor_left = 0.80; act.anchor_right = 0.98; act.anchor_top = 0.18; act.anchor_bottom = 0.82
	if status == "waiting":
		act.text = "Show code"
		var code: String = m.code
		act.pressed.connect(func(): _show_code(code))
	elif status == "your_turn":
		act.text = "Play ▶"
		var mid: String = m.match_id
		act.pressed.connect(func(): _play(mid))
	else:
		act.text = "View"
		var mid2: String = m.match_id
		act.pressed.connect(func(): _play(mid2))
	row.add_child(act)
	return row

func _new_match() -> void:
	var r: Dictionary = await Net.create_match()
	if r.get("ok", false):
		_show_code(r.invite_code)
		_refresh()

func _play(match_id: String) -> void:
	MatchSession.match_id = match_id
	var view: Dictionary = await Net.get_view(match_id)
	if view.get("own_ships", []).is_empty():
		# We joined but haven't placed our fleet yet — go place it first.
		MatchSession.placement_mode = "online_join"
		MatchSession.versus_enemy_skins = {}
		get_tree().change_scene_to_file("res://scenes/ui/placement_screen.tscn")
		return
	MatchSession.online = true
	# On your opening move, show the VERSUS challenge reveal first — carrying the opponent's real
	# equipped skins (safe cosmetic data from your redacted view). Otherwise go straight to the turn.
	if bool(view.get("your_turn", false)) and int(view.get("turn_number", 99)) <= 2:
		MatchSession.versus_enemy_skins = view.get("opponent_skins", {})
		MatchSession.versus_enemy_name = String(view.get("opponent_name", ""))
		MatchSession.versus_next = "res://scenes/ui/turn_screen.tscn"
		get_tree().change_scene_to_file("res://scenes/ui/versus_screen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/turn_screen.tscn")

# --- overlays ---

func _show_code(code: String) -> void:
	_code_label.text = code
	_code_overlay.visible = true

func _open_join() -> void:
	_join_input.text = ""
	_join_overlay.visible = true
	_join_input.grab_focus()

func _do_join() -> void:
	var r: Dictionary = await Net.join_match(_join_input.text)
	_join_overlay.visible = false
	if r.get("ok", false):
		MatchSession.placement_mode = "online_join"   # now place your own fleet
		MatchSession.match_id = String(r.get("match_id", ""))
		MatchSession.versus_enemy_skins = {}
		get_tree().change_scene_to_file("res://scenes/ui/placement_screen.tscn")
	else:
		_soon("Couldn't join: %s" % r.get("reason", "unknown"))

func _build_code_overlay() -> void:
	_code_overlay = _overlay()
	var card := _card(0.30, 0.30, 0.70, 0.70)
	_code_overlay.add_child(card)
	var t := _center_label("SHARE THIS CODE", 0.30, 0.34, 0.70, 0.40, 20, Color(0.7, 0.8, 0.9))
	_code_overlay.add_child(t)
	_code_label = _center_label("------", 0.30, 0.42, 0.70, 0.55, 44, Color(1.0, 0.85, 0.45))
	_code_overlay.add_child(_code_label)
	var copy := Button.new()
	copy.text = "Copy"
	_anchor(copy, 0.40, 0.58, 0.60, 0.64)
	copy.pressed.connect(func(): DisplayServer.clipboard_set(_code_label.text); _soon("Code copied"))
	_code_overlay.add_child(copy)
	var close := Button.new()
	close.text = "Done"
	_anchor(close, 0.40, 0.645, 0.60, 0.70)
	close.pressed.connect(func(): _code_overlay.visible = false)
	_code_overlay.add_child(close)
	add_child(_code_overlay)

func _build_join_overlay() -> void:
	_join_overlay = _overlay()
	var card := _card(0.30, 0.34, 0.70, 0.66)
	_join_overlay.add_child(card)
	_join_overlay.add_child(_center_label("ENTER INVITE CODE", 0.30, 0.38, 0.70, 0.44, 20, Color(0.7, 0.8, 0.9)))
	_join_input = LineEdit.new()
	_join_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_input.max_length = 6
	_join_input.add_theme_font_size_override("font_size", 26)
	_anchor(_join_input, 0.36, 0.46, 0.64, 0.53)
	_join_input.text_submitted.connect(func(_s): _do_join())
	_join_overlay.add_child(_join_input)
	var join := Button.new()
	join.text = "Join"
	_anchor(join, 0.36, 0.55, 0.505, 0.61)
	join.pressed.connect(_do_join)
	_join_overlay.add_child(join)
	var cancel := Button.new()
	cancel.text = "Cancel"
	_anchor(cancel, 0.515, 0.55, 0.64, 0.61)
	cancel.pressed.connect(func(): _join_overlay.visible = false)
	_join_overlay.add_child(cancel)
	add_child(_join_overlay)

# --- small builders ---

func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	var d := ColorRect.new()
	d.color = Color(0.0, 0.01, 0.02, 0.75)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	o.add_child(d)
	return o

func _card(l: float, t: float, r: float, b: float) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.14, 0.99)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.47, 0.68, 0.88, 0.8)
	p.add_theme_stylebox_override("panel", sb)
	_anchor(p, l, t, r, b)
	return p

func _center_label(txt: String, l: float, t: float, r: float, b: float, sz: int, col: Color) -> Label:
	var lb := Label.new()
	lb.text = txt
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", sz)
	lb.add_theme_color_override("font_color", col)
	_anchor(lb, l, t, r, b)
	return lb

func _button(txt: String, l: float, t: float, r: float, b: float, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = txt
	btn.focus_mode = Control.FOCUS_NONE
	_anchor(btn, l, t, r, b)
	btn.pressed.connect(cb)
	add_child(btn)

func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l; c.anchor_top = t; c.anchor_right = r; c.anchor_bottom = b
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0

func _make_toast() -> Label:
	var lb := Label.new()
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 18)
	lb.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lb.add_theme_constant_override("outline_size", 6)
	lb.anchor_left = 0.15; lb.anchor_right = 0.85; lb.anchor_top = 0.9; lb.anchor_bottom = 0.95
	lb.modulate.a = 0.0
	return lb

func _soon(msg: String) -> void:
	_toast.text = msg
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.3)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
