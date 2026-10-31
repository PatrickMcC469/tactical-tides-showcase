## Daily Rewards — a 7-day coin ladder you claim once per (server) day. Streak grows on consecutive
## days and resets on a miss. Everything authoritative happens server-side (Wallet.claim_daily → the
## claim_daily() RPC); this screen just reads the status and shows the reward. Day 7 is a bonus rung.
extends Control

const LADDER := [25, 40, 60, 80, 120, 160, 250]   # must match _daily_reward() in schema.sql
const ACCENT := Color(0.470, 0.680, 0.880)
const GOLD := Color(1.0, 0.83, 0.36)
const GREEN := Color(0.45, 0.82, 0.50)
const BONUS := Color(0.80, 0.55, 1.0)             # day-7 legendary tint

var _cells: Array[Panel] = []
var _markers: Array[Label] = []
var _amounts: Array[Label] = []
var _streak_lbl: Label
var _claim_btn: Button
var _status: Label
var _busy := false

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assests/UI/Main_menu.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.modulate = Color(0.35, 0.40, 0.48)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
	card.add_theme_stylebox_override("panel", sb)
	_anchor(card, 0.16, 0.18, 0.84, 0.84)
	add_child(card)

	var title := Label.new()
	title.text = "DAILY REWARDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	_anchor(title, 0.16, 0.205, 0.84, 0.265)
	add_child(title)

	_streak_lbl = Label.new()
	_streak_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_lbl.add_theme_font_size_override("font_size", 16)
	_streak_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	_anchor(_streak_lbl, 0.16, 0.275, 0.84, 0.315)
	add_child(_streak_lbl)

	# 7-day ladder row.
	for i in LADDER.size():
		var x0 := 0.195 + i * 0.087
		var x1 := x0 + 0.074
		var is_bonus := i == LADDER.size() - 1
		var cell := Panel.new()
		_anchor(cell, x0, 0.35, x1, 0.585)
		add_child(cell)
		_cells.append(cell)

		var day := Label.new()
		day.text = "BONUS" if is_bonus else "DAY %d" % (i + 1)
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day.add_theme_font_size_override("font_size", 11)
		day.add_theme_color_override("font_color", BONUS if is_bonus else Color(0.7, 0.78, 0.88))
		_anchor(day, x0, 0.365, x1, 0.405)
		add_child(day)

		var amt := Label.new()
		amt.text = "%d" % LADDER[i]
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt.add_theme_font_size_override("font_size", 23 if is_bonus else 20)
		amt.add_theme_color_override("font_color", BONUS if is_bonus else GOLD)
		_anchor(amt, x0, 0.44, x1, 0.50)
		add_child(amt)
		_amounts.append(amt)

		var coin := Label.new()
		coin.text = "coins"
		coin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coin.add_theme_font_size_override("font_size", 9)
		coin.add_theme_color_override("font_color", Color(0.62, 0.70, 0.80))
		_anchor(coin, x0, 0.505, x1, 0.535)
		add_child(coin)

		var mark := Label.new()
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 12)
		_anchor(mark, x0, 0.545, x1, 0.58)
		add_child(mark)
		_markers.append(mark)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	_anchor(_status, 0.16, 0.61, 0.84, 0.66)
	add_child(_status)

	_claim_btn = Button.new()
	_claim_btn.text = "CLAIM"
	_claim_btn.focus_mode = Control.FOCUS_NONE
	_claim_btn.add_theme_font_size_override("font_size", 22)
	_claim_btn.pressed.connect(_on_claim)
	Press.attach(_claim_btn)
	_anchor(_claim_btn, 0.36, 0.68, 0.64, 0.755)
	add_child(_claim_btn)

	var back := Button.new()
	back.text = "◀ Back"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	Press.attach(back)
	_anchor(back, 0.41, 0.775, 0.59, 0.825)
	add_child(back)

	_refresh()

	if "--shot" in OS.get_cmdline_user_args():
		for i in _cells.size():                       # a representative state so the shot shows the ladder
			_paint(i, "claimed" if i < 2 else ("today" if i == 2 else "future"))
		_streak_lbl.text = "3-DAY STREAK  🔥"
		_status.text = "Day 3 reward is ready to claim."
		_claim_btn.disabled = false
		_style_claim(true)
		await get_tree().create_timer(0.35).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_daily.png")
		get_tree().quit()

func _refresh() -> void:
	if not Auth.signed():
		_status.text = "Sign in to earn daily rewards."
		_streak_lbl.text = ""
		_claim_btn.disabled = true
		_style_claim(false)
		for i in _cells.size():
			_paint(i, "future")
		return
	var st: Dictionary = await Wallet.daily_status()
	if st.is_empty():
		_status.text = "Couldn't reach the rewards server — try again."
		_streak_lbl.text = ""
		_claim_btn.disabled = true
		_style_claim(false)
		return
	var streak := int(st.get("streak", 0))
	var claimable := bool(st.get("claimable", true))
	var today_rung: int
	if claimable:
		var continues := str(st.get("last_daily", "")) == Wallet.yesterday()
		today_rung = (streak % 7) + 1 if continues else 1
	else:
		today_rung = ((maxi(streak, 1) - 1) % 7) + 1

	for i in _cells.size():
		var num := i + 1
		if num < today_rung or (not claimable and num == today_rung):
			_paint(i, "claimed")
		elif num == today_rung:
			_paint(i, "today")
		else:
			_paint(i, "future")

	_streak_lbl.text = ("%d-DAY STREAK  🔥" % streak) if streak > 0 else "Start your streak today!"
	if claimable:
		_status.text = "Day %d reward is ready to claim." % today_rung
		_claim_btn.disabled = false
		_claim_btn.text = "CLAIM"
		_style_claim(true)
	else:
		_status.text = "Claimed today — come back tomorrow!"
		_claim_btn.disabled = true
		_claim_btn.text = "COME BACK TOMORROW"
		_style_claim(false)

func _on_claim() -> void:
	if _busy:
		return
	_busy = true
	_claim_btn.disabled = true
	var r: Dictionary = await Wallet.claim_daily()
	_busy = false
	if r.get("ok", false) and r.get("claimed", false):
		Cosmetics.coins = int(r.get("coins", Cosmetics.coins))   # mirror the server balance locally
		_status.text = "+%d coins!   streak %d 🔥" % [int(r.get("reward", 0)), int(r.get("streak", 0))]
		await get_tree().create_timer(1.2).timeout
	await _refresh()

## Paint one ladder cell for its state: future (locked), today (highlighted), or claimed (done).
func _paint(i: int, state: String) -> void:
	var is_bonus := i == LADDER.size() - 1
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	match state:
		"today":
			sb.bg_color = Color(0.12, 0.11, 0.04)
			sb.set_border_width_all(3)
			sb.border_color = GOLD
			_markers[i].text = "TODAY"
			_markers[i].add_theme_color_override("font_color", GOLD)
			_amounts[i].modulate = Color(1, 1, 1, 1)
		"claimed":
			sb.bg_color = Color(0.06, 0.12, 0.07)
			sb.set_border_width_all(2)
			sb.border_color = Color(GREEN.r, GREEN.g, GREEN.b, 0.85)
			_markers[i].text = "✓"
			_markers[i].add_theme_color_override("font_color", GREEN)
			_amounts[i].modulate = Color(1, 1, 1, 0.55)
		_:   # future / locked
			sb.bg_color = Color(0.04, 0.06, 0.10)
			sb.set_border_width_all(1)
			sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35 if not is_bonus else 0.6)
			_markers[i].text = ""
			_amounts[i].modulate = Color(1, 1, 1, 0.85)
	_cells[i].add_theme_stylebox_override("panel", sb)

func _style_claim(ready: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.bg_color = Color(0.85, 0.66, 0.18) if ready else Color(0.10, 0.14, 0.20)
	sb.set_border_width_all(2)
	sb.border_color = GOLD if ready else Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
	_claim_btn.add_theme_stylebox_override("normal", sb)
	_claim_btn.add_theme_stylebox_override("hover", sb)
	_claim_btn.add_theme_stylebox_override("pressed", sb)
	_claim_btn.add_theme_color_override("font_color", Color(0.10, 0.08, 0.02) if ready else Color(0.6, 0.68, 0.78))

func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l; c.anchor_top = t; c.anchor_right = r; c.anchor_bottom = b
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0
