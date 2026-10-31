## Settings screen. Reached from the main-menu gear and the in-game gear (GameFrame). Options:
## reduce-motion, sound, and the Account section (Google sign-in to turn a guest account permanent).
extends Control

var _account_status: Label
var _google_btn: Button
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
	sb.border_color = Color(0.47, 0.68, 0.88, 0.8)
	card.add_theme_stylebox_override("panel", sb)
	_anchor(card, 0.28, 0.15, 0.72, 0.90)
	add_child(card)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_anchor(title, 0.28, 0.175, 0.72, 0.24)
	add_child(title)

	var lbl := Label.new()
	lbl.text = "Reduce Motion"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	_anchor(lbl, 0.325, 0.28, 0.60, 0.34)
	add_child(lbl)

	var chk := CheckButton.new()
	chk.button_pressed = Settings.reduce_motion
	chk.focus_mode = Control.FOCUS_NONE
	chk.toggled.connect(func(on: bool): Settings.set_reduce_motion(on))
	_anchor(chk, 0.605, 0.275, 0.675, 0.345)
	add_child(chk)

	var desc := Label.new()
	desc.text = "Calms the drifting water and rolling fog on the battle board."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.62, 0.70, 0.80))
	_anchor(desc, 0.325, 0.345, 0.675, 0.40)
	add_child(desc)

	var slbl := Label.new()
	slbl.text = "Sound"
	slbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slbl.add_theme_font_size_override("font_size", 20)
	_anchor(slbl, 0.325, 0.43, 0.60, 0.49)
	add_child(slbl)

	var schk := CheckButton.new()
	schk.button_pressed = Settings.sound
	schk.focus_mode = Control.FOCUS_NONE
	schk.toggled.connect(func(on: bool): Settings.set_sound(on))
	_anchor(schk, 0.605, 0.425, 0.675, 0.495)
	add_child(schk)

	var sdesc := Label.new()
	sdesc.text = "Sound effects and ocean ambience."
	sdesc.add_theme_font_size_override("font_size", 14)
	sdesc.add_theme_color_override("font_color", Color(0.62, 0.70, 0.80))
	_anchor(sdesc, 0.325, 0.495, 0.675, 0.54)
	add_child(sdesc)

	# ---- Account section ----
	var sep := ColorRect.new()
	sep.color = Color(0.30, 0.42, 0.55, 0.5)
	_anchor(sep, 0.325, 0.565, 0.675, 0.568)
	add_child(sep)

	var albl := Label.new()
	albl.text = "Account"
	albl.add_theme_font_size_override("font_size", 20)
	albl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_anchor(albl, 0.325, 0.575, 0.675, 0.61)
	add_child(albl)

	# Captain name — shown to opponents on the versus screen + games list.
	var nlbl := Label.new()
	nlbl.text = "Captain Name"
	nlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nlbl.add_theme_font_size_override("font_size", 16)
	_anchor(nlbl, 0.345, 0.62, 0.52, 0.665)
	add_child(nlbl)

	var nedit := LineEdit.new()
	nedit.text = Settings.player_name
	nedit.placeholder_text = "Captain"
	nedit.max_length = 20
	nedit.add_theme_font_size_override("font_size", 16)
	nedit.text_changed.connect(func(t: String): Settings.set_player_name(t))
	_anchor(nedit, 0.52, 0.62, 0.655, 0.665)
	add_child(nedit)

	_account_status = Label.new()
	_account_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_account_status.add_theme_font_size_override("font_size", 13)
	_account_status.add_theme_color_override("font_color", Color(0.62, 0.70, 0.80))
	_anchor(_account_status, 0.325, 0.675, 0.675, 0.735)
	add_child(_account_status)

	_google_btn = Button.new()
	_google_btn.text = "Sign in with Google"
	_google_btn.focus_mode = Control.FOCUS_NONE
	_google_btn.pressed.connect(_on_google)
	Press.attach(_google_btn)
	_anchor(_google_btn, 0.36, 0.74, 0.64, 0.795)
	add_child(_google_btn)

	_refresh_account()

	var back := Button.new()
	back.text = "◀ Back"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_go_back)
	_anchor(back, 0.40, 0.82, 0.60, 0.88)
	add_child(back)

	if OS.get_cmdline_args().has("--shot"):
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_settings.png")
		get_tree().quit()

## Reflect the current account state and show/hide the Google button accordingly.
func _refresh_account() -> void:
	if not Auth.signed():
		_account_status.text = "Playing as a guest (offline)."
		_google_btn.visible = false
	elif Auth.is_anonymous:
		_account_status.text = "Guest account. Sign in with Google to save your fleet, coins, and friends — and keep them if you switch phones."
		_google_btn.visible = true
		_google_btn.disabled = _busy
		# On desktop/editor there's no native plugin; make that clear rather than silently failing.
		if not Auth.google_available():
			_google_btn.text = "Sign in with Google (mobile app)"
			_google_btn.disabled = true
	else:
		_account_status.text = "Signed in with Google ✓  Your progress is saved to your account."
		_google_btn.visible = false

func _on_google() -> void:
	if _busy or not Auth.google_available():
		return
	_busy = true
	_google_btn.text = "Signing in…"
	_google_btn.disabled = true
	var ok: bool = await Auth.sign_in_with_google_native()
	_busy = false
	if not ok:
		_google_btn.text = "Sign in with Google"
	_refresh_account()

func _go_back() -> void:
	var dest := Settings.settings_return
	Settings.settings_return = "res://scenes/ui/main_menu.tscn"   # reset so the next open defaults correctly
	get_tree().change_scene_to_file(dest)

func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l; c.anchor_top = t; c.anchor_right = r; c.anchor_bottom = b
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0
