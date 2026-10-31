## Fleet Bundles shop: each bundle is one theme across all six ships (Golden Armada, Arctic Fleet,
## …). Buying it is 25% off the six skins individually, and skins you already own drop off the
## price (complete-the-set). Reached from the coin store's BUNDLES tab. Uses Skins for data,
## Cosmetics for coins/ownership.
extends Control

var list_box: VBoxContainer
var coins_lbl: Label
var _toast: Label

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assests/UI/Main_menu.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.modulate = Color(0.28, 0.33, 0.40)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var title := Label.new()
	title.text = "FLEET BUNDLES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_anchor(title, 0.30, 0.045, 0.70, 0.115)
	add_child(title)

	var sub := Label.new()
	sub.text = "One look across your whole fleet — 25% off, and skins you own come off the price."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.66, 0.74, 0.84))
	_anchor(sub, 0.20, 0.115, 0.80, 0.155)
	add_child(sub)

	coins_lbl = Label.new()
	coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_lbl.add_theme_font_size_override("font_size", 18)
	coins_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.36))
	coins_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	coins_lbl.add_theme_constant_override("outline_size", 5)
	_anchor(coins_lbl, 0.70, 0.03, 0.87, 0.09)
	add_child(coins_lbl)

	var home := Button.new()
	home.text = "⌂ Home"
	home.focus_mode = Control.FOCUS_NONE
	_anchor(home, 0.02, 0.03, 0.13, 0.095)
	home.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	add_child(home)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_anchor(scroll, 0.13, 0.17, 0.87, 0.95)
	add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(list_box)

	_toast = _make_toast()
	add_child(_toast)
	_refresh()

	if OS.get_cmdline_args().has("--shot"):
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_bundles.png")
		get_tree().quit()

func _refresh() -> void:
	coins_lbl.text = "★ %d" % Cosmetics.coins
	for c in list_box.get_children():
		c.queue_free()
	for theme in Skins.BUNDLE_THEMES:
		list_box.add_child(_bundle_card(theme))

## {price, owned, total} for a theme's bundle at the current ownership.
func _bundle_state(theme: String) -> Dictionary:
	var keys := Skins.theme_keys(theme)
	var owned := 0
	for k in keys:
		if Cosmetics.is_purchased(k):
			owned += 1
	var unowned := keys.size() - owned
	var price := int(round(unowned * Skins.skin_price(theme) * (1.0 - Skins.BUNDLE_DISCOUNT)))
	return {"keys": keys, "price": price, "owned": owned, "total": keys.size()}

func _bundle_card(theme: String) -> Control:
	var st := _bundle_state(theme)
	var rarity := Skins.rarity_of(theme)
	var complete: bool = st.owned == st.total

	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 104)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.96)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2)
	sb.border_color = Skins.RARITY_COLOR.get(rarity, Color.WHITE)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14; box.offset_right = -14; box.offset_top = 8; box.offset_bottom = -8
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	# Name + rarity.
	var namecol := VBoxContainer.new()
	namecol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	namecol.size_flags_stretch_ratio = 3.0
	namecol.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := Label.new()
	nm.text = String(Skins.BUNDLE_NAMES.get(theme, theme.capitalize()))
	nm.add_theme_font_size_override("font_size", 20)
	namecol.add_child(nm)
	var rar := Label.new()
	rar.text = "%s  ·  6 ships" % rarity
	rar.add_theme_font_size_override("font_size", 12)
	rar.add_theme_color_override("font_color", Skins.RARITY_COLOR.get(rarity, Color.WHITE))
	namecol.add_child(rar)
	box.add_child(namecol)

	# Six ship top-downs for the theme.
	var thumbs := HBoxContainer.new()
	thumbs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumbs.size_flags_stretch_ratio = 6.0
	thumbs.alignment = BoxContainer.ALIGNMENT_CENTER
	thumbs.add_theme_constant_override("separation", 4)
	for s in Skins.SHIPS:
		var t := TextureRect.new()
		t.texture = _td(String(s[2]), String(s[3]), theme)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(44, 86)
		thumbs.add_child(t)
	box.add_child(thumbs)

	# Price + buy.
	var buycol := VBoxContainer.new()
	buycol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buycol.size_flags_stretch_ratio = 2.4
	buycol.alignment = BoxContainer.ALIGNMENT_CENTER
	if st.owned > 0 and not complete:
		var owned_note := Label.new()
		owned_note.text = "own %d of 6" % st.owned
		owned_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owned_note.add_theme_font_size_override("font_size", 12)
		owned_note.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		buycol.add_child(owned_note)
	var buy := Button.new()
	buy.focus_mode = Control.FOCUS_NONE
	if complete:
		buy.text = "OWNED ✓"
		buy.disabled = true
	else:
		buy.text = "★ %d" % st.price
		var keys: Array = st.keys
		var price: int = st.price
		buy.pressed.connect(func(): _buy(theme, keys, price))
	buycol.add_child(buy)
	box.add_child(buycol)
	return card

func _buy(theme: String, keys: Array, price: int) -> void:
	if Cosmetics.buy_bundle(keys, price):
		_soon("%s unlocked!" % Skins.BUNDLE_NAMES.get(theme, theme.capitalize()))
		_refresh()
	else:
		_soon("Not enough coins")

func _td(dir: String, prefix: String, theme: String) -> Texture2D:
	var p := "res://assests/ships/%s/%s_%s_td.png" % [dir, prefix, theme]
	return load(p) if ResourceLoader.exists(p) else null

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
	lb.anchor_left = 0.15; lb.anchor_right = 0.85; lb.anchor_top = 0.92; lb.anchor_bottom = 0.97
	lb.modulate.a = 0.0
	return lb

func _soon(msg: String) -> void:
	_toast.text = msg
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
