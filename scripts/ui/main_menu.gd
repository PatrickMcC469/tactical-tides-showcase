## Main menu. Button-less background (main_menu.png) with each button as its own PNG overlaid on top —
## no baked buttons, no phantom hotspots. Positions are viewport fractions, tuned via the constants
## below so everything tracks the art at any resolution.
extends Control

const BG := "res://assests/UI/Main_menu.png"   # button-less background (import is Main_menu.png.import)
# Nav buttons in a centred 2x2 grid. Each cell CELL_W x CELL_H; GRID_X/Y is the top-left of the grid;
# GAP_* is the space between cells. (GRID_X + 2*CELL_W + GAP_X centres it around x=0.5.)
const CELL_W := 0.325
const CELL_H := 0.215
const GRID_X := 0.16    # centres the grid: (1 - (2*CELL_W + GAP_X)) / 2
const GRID_Y := 0.25
const GAP_X := 0.03
const GAP_Y := 0.02

var _toast: Label

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

	# Left-column nav buttons (data-driven — each its own art on the button-less background).
	var nav := [
		["btn_new_game.png", _new_game],
		["btn_current_games.png", _current_games],
		["btn_ship_store.png", _ship_store],
		["btn_coin_store.png", _coin_store],
	]
	for i in nav.size():
		var col := i % 2
		@warning_ignore("integer_division")
		var row := i / 2
		var l: float = GRID_X + col * (CELL_W + GAP_X)
		var t: float = GRID_Y + row * (CELL_H + GAP_Y)
		_overlay_button("res://assests/UI/" + str(nav[i][0]), l, t, l + CELL_W, t + CELL_H, nav[i][1])

	# Top bar: coin balance (self-drawn) top-left; mail + settings top-right (aligned, same size).
	var wallet := CurrencyBlock.new()
	wallet.anchor_left = 0.045; wallet.anchor_right = 0.22
	wallet.anchor_top = 0.075; wallet.anchor_bottom = 0.15
	wallet.offset_left = 0; wallet.offset_top = 0; wallet.offset_right = 0; wallet.offset_bottom = 0
	wallet.pressed.connect(_coin_store)
	add_child(wallet)
	_sync_coins(wallet)   # pull the authoritative server balance into the display

	# Free Coins (watch-ad, only when a rewarded ad is ready) — top-right, in its own box.
	_corner_box(0.845, 0.055, 0.955, 0.335)
	var free := _overlay_button("res://assests/UI/free_coin_reward.png", 0.85, 0.065, 0.95, 0.325, _free_coins)
	free.visible = _rewarded_ready()

	# Daily Reward box, bottom-left (below the grid — no overlap).
	_corner_box(0.04, 0.725, 0.26, 0.955)
	_overlay_button("res://assests/UI/tactical_tides_daily_reward_box.png", 0.06, 0.735, 0.24, 0.885, _daily_rewards)
	_caption("DAILY REWARD", 0.04, 0.885, 0.26, 0.94)

	# Mail + Settings box, bottom-right (below the grid). Mail enlarged so it reads.
	_corner_box(0.73, 0.725, 0.955, 0.955)
	_overlay_button("res://assests/UI/btn_mail.png", 0.74, 0.735, 0.845, 0.945, _mailroom)
	_overlay_button("res://assests/UI/setting_button.png", 0.85, 0.75, 0.945, 0.925, _settings)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(1, 1, 1))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.anchor_left = 0.5; _toast.anchor_right = 0.5
	_toast.anchor_top = 0.9; _toast.anchor_bottom = 0.9
	_toast.offset_left = -240; _toast.offset_right = 240
	_toast.modulate.a = 0.0
	add_child(_toast)

	# Dev-only shortcuts (editor/debug builds only; false in a release export).
	if OS.is_debug_build():
		_dev_button("▶ HOTSEAT", 0.27, 0.485, _hotseat)
		_dev_button("⚔ BATTLE DEMO", 0.515, 0.73, _battle_demo)

	if OS.get_cmdline_args().has("--shot"):
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_menu.png")
		get_tree().quit()

## A designed PNG button overlaid on the menu art, filling the given viewport-fraction box (aspect
## kept, centred), with press feel. Returns the button.
func _overlay_button(path: String, l: float, t: float, r: float, b: float, cb: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load(path)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.focus_mode = Control.FOCUS_NONE
	btn.anchor_left = l; btn.anchor_top = t; btn.anchor_right = r; btn.anchor_bottom = b
	btn.offset_left = 0; btn.offset_top = 0; btn.offset_right = 0; btn.offset_bottom = 0
	btn.pressed.connect(cb)
	Press.attach(btn)
	add_child(btn)
	return btn

## A subtle rounded panel ("box") at the given viewport-fraction rect, behind buttons.
func _corner_box(l: float, t: float, r: float, b: float) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.5)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.55, 0.72, 0.45)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = l; p.anchor_top = t; p.anchor_right = r; p.anchor_bottom = b
	p.offset_left = 0; p.offset_top = 0; p.offset_right = 0; p.offset_bottom = 0
	add_child(p)

## A centred caption label (with outline) over the art at the given viewport-fraction box.
func _caption(text: String, l: float, t: float, r: float, b: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.anchor_left = l; lbl.anchor_top = t; lbl.anchor_right = r; lbl.anchor_bottom = b
	lbl.offset_left = 0; lbl.offset_top = 0; lbl.offset_right = 0; lbl.offset_bottom = 0
	add_child(lbl)

## A small labelled dev button in the top bar (debug builds only).
func _dev_button(text: String, l: float, r: float, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.anchor_left = l; b.anchor_right = r
	b.anchor_top = 0.006; b.anchor_bottom = 0.052
	b.offset_left = 0; b.offset_top = 0; b.offset_right = 0; b.offset_bottom = 0
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	Press.attach(b)
	add_child(b)

func _new_game() -> void:
	MatchSession.placement_mode = "online_create"
	MatchSession.versus_enemy_skins = {}
	get_tree().change_scene_to_file("res://scenes/ui/placement_screen.tscn")

## Dev-only: two players place on one device, then battle locally (visual/gameplay testing).
func _hotseat() -> void:
	MatchSession.placement_mode = "hotseat"
	MatchSession.versus_enemy_skins = {}
	get_tree().change_scene_to_file("res://scenes/ui/placement_screen.tscn")

## Dev-only: jump straight into a demo battle (turn_screen builds a demo fleet with no live match).
func _battle_demo() -> void:
	MatchSession.online = false
	MatchSession.state = null
	get_tree().change_scene_to_file("res://scenes/ui/turn_screen.tscn")

func _ship_store() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ship_skins_screen.tscn")

func _coin_store() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/coin_store_screen.tscn")

func _settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings_screen.tscn")

func _current_games() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/current_games_screen.tscn")

func _mailroom() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mailroom_screen.tscn")

func _daily_rewards() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/daily_rewards_screen.tscn")

## Free coins via a rewarded ad — placeholder until AdMob is wired (monetization Phase 3).
func _free_coins() -> void:
	_soon("Free Coins (watch ad)")

## True when a rewarded ad is loaded + ready. Placeholder until AdMob: "ready" only in debug builds so
## the button can be positioned; hidden in release.
func _rewarded_ready() -> bool:
	return OS.is_debug_build()   # TODO(Phase 3): return Ads.rewarded_ready() once AdMob is wired

## Mirror the server coin balance into the local Cosmetics display (server is the source of truth).
func _sync_coins(w: CurrencyBlock) -> void:
	if not Auth.signed():
		return
	var bal: int = await Wallet.balance()
	if bal >= 0:
		Cosmetics.coins = bal
		w.refresh()

func _soon(feature: String) -> void:
	_toast.text = "%s — coming soon" % feature
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.1)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
