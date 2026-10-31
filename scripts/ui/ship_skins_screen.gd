## Ship Skins browser. Frame = shop_UI.png: a ship list on the left, a horizontally-scrolling
## row of skin cards in the middle. Each card shows the skin's CINEMATIC (angled) render + its
## TOP-DOWN view, its name, rarity, and a price / OWNED-EQUIP control. Pick a ship on the left;
## drag or scroll sideways through its skins. Home button (top-right) returns to the menu.
##
## Art naming (uniform across every ship): `<prefix>_<theme>_tl.png` = cinematic, `_td.png` =
## top-down. Themes run in a fixed order that mirrors the rarity ladder. Ownership, coins and the
## active skin come from the Cosmetics autoload (local placeholder → server-authoritative later).
extends Control

# Ship / theme / rarity / name data is shared with the Bundles shop — see game/skins.gd.
const SHIPS := Skins.SHIPS
const THEME_ORDER := Skins.THEME_ORDER
const THEME_RARITY := Skins.THEME_RARITY
const SKIN_NAMES := Skins.SKIN_NAMES
const RARITY_PRICE := Skins.RARITY_PRICE
const RARITY_COLOR := Skins.RARITY_COLOR

# Left list geometry (fractions of the screen).
const LIST_X := 0.040
const LIST_W := 0.133
const LIST_TOP := 0.150
const LIST_PITCH := 0.121
const ROW_H := 0.098
# Card gallery region — kept inside the frame's inner display box.
const GALLERY := Rect2(0.246, 0.190, 0.686, 0.635)
const CARD_W := 205.0
const CARD_SEP := 16

var cards_box: HBoxContainer
var coins_lbl: Label
var _toast: Label
var _rows: Array[Button] = []
var _ship := 0

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assests/UI/shop_UI.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	_lay(scroll, GALLERY)
	add_child(scroll)
	cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", CARD_SEP)
	cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards_box)

	for i in SHIPS.size():
		var b := Button.new()
		b.text = SHIPS[i][1]
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.anchor_left = LIST_X; b.anchor_right = LIST_X + LIST_W
		b.anchor_top = LIST_TOP + i * LIST_PITCH
		b.anchor_bottom = LIST_TOP + i * LIST_PITCH + ROW_H
		b.offset_left = 0; b.offset_top = 0; b.offset_right = 0; b.offset_bottom = 0
		var idx := i
		b.pressed.connect(func(): _pick_ship(idx))
		add_child(b)
		_rows.append(b)

	coins_lbl = Label.new()
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_lbl.add_theme_font_size_override("font_size", 18)
	coins_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.36))
	coins_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	coins_lbl.add_theme_constant_override("outline_size", 5)
	coins_lbl.anchor_left = 0.70; coins_lbl.anchor_right = 0.875
	coins_lbl.anchor_top = 0.028; coins_lbl.anchor_bottom = 0.083
	add_child(coins_lbl)

	var home := Button.new()
	home.text = "⌂ Home"
	home.focus_mode = Control.FOCUS_NONE
	home.add_theme_font_size_override("font_size", 15)
	home.anchor_left = 0.888; home.anchor_right = 0.983
	home.anchor_top = 0.028; home.anchor_bottom = 0.083
	home.offset_left = 0; home.offset_top = 0; home.offset_right = 0; home.offset_bottom = 0
	home.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	add_child(home)

	_toast = _make_toast()
	add_child(_toast)

	_refresh_coins()
	_pick_ship(0)

	if OS.get_cmdline_args().has("--shot"):
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_skins.png")
		get_tree().quit()

func _lay(c: Control, r: Rect2) -> void:
	c.anchor_left = r.position.x; c.anchor_top = r.position.y
	c.anchor_right = r.position.x + r.size.x; c.anchor_bottom = r.position.y + r.size.y
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0

func _refresh_coins() -> void:
	coins_lbl.text = "★ %d" % Cosmetics.coins

func _pick_ship(i: int) -> void:
	_ship = i
	for r in _rows.size():
		_rows[r].add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.45) if r == i else Color(0.72, 0.78, 0.86))
	for c in cards_box.get_children():
		c.queue_free()
	var id: StringName = SHIPS[i][0]
	var skins := _skins_for(SHIPS[i])
	var active_key := Cosmetics.active_skin(String(id))
	if active_key == "" and not skins.is_empty():
		active_key = skins[0].key   # nothing equipped yet → the default (first) skin is active
	for skin in skins:
		cards_box.add_child(_make_card(id, skin, active_key))

## Build a ship's ordered skin list from the uniform `<prefix>_<theme>_tl/_td` art.
func _skins_for(ship: Array) -> Array:
	var id: StringName = ship[0]
	var dir_name: String = ship[2]
	var prefix: String = ship[3]
	var base := "res://assests/ships/%s/" % dir_name
	var names: Dictionary = SKIN_NAMES.get(id, {})
	var out: Array = []
	for theme in THEME_ORDER:
		var top := _tex("%s%s_%s_td.png" % [base, prefix, theme])
		if top == null:
			continue   # this ship has no top-down for the theme → no card
		out.append({
			"key": "%s_%s" % [prefix, theme],
			"name": names.get(theme, theme.capitalize()),
			"rarity": THEME_RARITY[theme],
			"theme": theme,
			"top": top,
			"cinematic": _cine(base, prefix, theme),
		})
	return out

## The cinematic (angled) render for a theme, with fallbacks for the few off-pattern filenames
## (battleship inferno is `_cin`; the sub's neptune cinematic is spelled `neptunes`).
func _cine(base: String, prefix: String, theme: String) -> Texture2D:
	var cands: Array[String] = ["%s%s_%s_tl.png" % [base, prefix, theme]]
	if theme == "neptune":
		cands.append("%s%s_neptunes_tl.png" % [base, prefix])
	cands.append("%s%s_%s_cin.png" % [base, prefix, theme])
	for c in cands:
		var t := _tex(c)
		if t != null:
			return t
	return null

func _make_card(ship_id: StringName, skin: Dictionary, active_key: String) -> Control:
	var key: String = skin.key
	var rarity: String = skin.rarity
	var price: int = 0 if skin.theme == "default" else int(RARITY_PRICE.get(rarity, 500))
	var owned := price == 0 or Cosmetics.is_purchased(key)
	var equipped := key == active_key

	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.size_flags_vertical = Control.SIZE_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.025, 0.03)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2 if equipped else 1)
	sb.border_color = Color(1.0, 0.83, 0.36) if equipped else Color(0.35, 0.5, 0.7, 0.45)
	card.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10; v.offset_right = -10; v.offset_top = 10; v.offset_bottom = -10
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)

	if skin.cinematic != null:
		v.add_child(_img(skin.cinematic, 2.2))
	v.add_child(_img(skin.top, 3.0 if skin.cinematic != null else 5.0))

	var name_lbl := Label.new()
	name_lbl.text = str(skin.name)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	v.add_child(name_lbl)

	var rar := Label.new()
	rar.text = rarity
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rar.add_theme_font_size_override("font_size", 11)
	rar.add_theme_color_override("font_color", RARITY_COLOR.get(rarity, Color.WHITE))
	v.add_child(rar)

	var act := Button.new()
	act.focus_mode = Control.FOCUS_NONE
	act.add_theme_font_size_override("font_size", 14)
	if not owned:
		act.text = "★ %d" % price
		act.pressed.connect(func(): _buy(ship_id, key, price))
	elif equipped:
		act.text = "ACTIVE ✓"
		act.disabled = true
	else:
		act.text = "EQUIP"
		act.pressed.connect(func(): _equip(ship_id, key))
	v.add_child(act)
	return card

func _img(tex: Texture2D, stretch: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.size_flags_stretch_ratio = stretch
	return t

func _buy(ship_id: StringName, key: String, price: int) -> void:
	if Cosmetics.buy(key, price):
		Cosmetics.set_active(String(ship_id), key)   # auto-equip on purchase
		_refresh_coins()
		_pick_ship(_ship)
	else:
		_soon("Not enough coins")

func _equip(ship_id: StringName, key: String) -> void:
	Cosmetics.set_active(String(ship_id), key)
	_pick_ship(_ship)

func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _make_toast() -> Label:
	var t := Label.new()
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1, 0.7, 0.5))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	t.add_theme_constant_override("outline_size", 6)
	t.anchor_left = 0.30; t.anchor_right = 0.94
	t.anchor_top = 0.86; t.anchor_bottom = 0.90
	t.modulate.a = 0.0
	return t

func _soon(msg: String) -> void:
	_toast.text = msg
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.1)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
