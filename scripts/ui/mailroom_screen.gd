## The Mailroom — the inbox reached from the main-menu ✉ button. Messages are accordion rows: tap to
## expand the body (marks it read; the unread dot clears), and 🗑 deletes a message like a normal inbox.
## Read/deleted state persists via MailStore (user://mail.cfg). Seeds are static for now; later this
## carries real server mail (rewards, "X challenged you", news).
extends Control

# Seed messages. Each needs a stable `id` so read/deleted state can persist. body uses \n for breaks.
const MESSAGES := [
	{"id": "welcome", "from": "Fleet Command", "subject": "Welcome aboard, Captain!",
	 "body": "Your fleet is fueled and ready. Start a NEW GAME to place your ships and send a friend an invite code — then battle across the seas.\n\nFair winds and following seas."},
	{"id": "coins", "from": "Wandering Turtle Games", "subject": "Earning coins",
	 "body": "Win battles to earn coins on the post-game spin. Spend them in the Ship Store on skins for your fleet.\n\nMore ways to earn are on the way."},
]

var _accent := Color(0.470, 0.680, 0.880)
var _list: VBoxContainer
var _empty: Label
var _visible_count := 0

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
	sb.border_color = Color(_accent.r, _accent.g, _accent.b, 0.8)
	card.add_theme_stylebox_override("panel", sb)
	_anchor(card, 0.24, 0.12, 0.76, 0.90)
	add_child(card)

	var title := Label.new()
	title.text = "MAILROOM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_anchor(title, 0.24, 0.145, 0.76, 0.215)
	add_child(title)

	# Scrollable list of messages.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_anchor(scroll, 0.265, 0.235, 0.735, 0.80)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	scroll.resized.connect(func(): _list.custom_minimum_size.x = scroll.size.x)

	for m in MESSAGES:
		if MailStore.is_deleted(m.id):
			continue
		_list.add_child(_message_row(m))
		_visible_count += 1

	# Empty-inbox state (shown when everything's been deleted).
	_empty = Label.new()
	_empty.text = "No messages."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_font_size_override("font_size", 16)
	_empty.add_theme_color_override("font_color", Color(0.6, 0.68, 0.78))
	_empty.visible = _visible_count == 0
	_anchor(_empty, 0.24, 0.48, 0.76, 0.54)
	add_child(_empty)

	var back := Button.new()
	back.text = "◀ Back"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	Press.attach(back)
	_anchor(back, 0.40, 0.82, 0.60, 0.88)
	add_child(back)

	if OS.get_cmdline_args().has("--shot"):
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_mailroom.png")
		get_tree().quit()

## One message as an accordion: a tappable header (sender · subject, unread dot, 🗑 delete) over a body
## that expands on tap and marks the message read.
func _message_row(m: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := Button.new()
	header.focus_mode = Control.FOCUS_NONE
	header.custom_minimum_size = Vector2(0, 60)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.clip_text = true
	header.text = "  %s  ·  %s" % [m.from, m.subject]
	header.add_theme_font_size_override("font_size", 17)
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.05, 0.08, 0.13, 0.96)
	hs.set_corner_radius_all(8)
	hs.set_border_width_all(1)
	hs.border_color = Color(_accent.r, _accent.g, _accent.b, 0.45)
	hs.content_margin_left = 12
	hs.content_margin_right = 92   # leave room for the dot + delete button
	header.add_theme_stylebox_override("normal", hs)
	header.add_theme_stylebox_override("hover", hs)
	header.add_theme_stylebox_override("pressed", hs)
	Press.attach(header)
	box.add_child(header)

	# Delete button, pinned to the header's right edge.
	var del := Button.new()
	del.text = "🗑"
	del.focus_mode = Control.FOCUS_NONE
	del.tooltip_text = "Delete message"
	del.add_theme_font_size_override("font_size", 18)
	var dels := StyleBoxFlat.new()
	dels.bg_color = Color(0.10, 0.13, 0.18, 0.0)
	del.add_theme_stylebox_override("normal", dels)
	del.add_theme_stylebox_override("hover", dels)
	del.add_theme_stylebox_override("pressed", dels)
	del.anchor_left = 1.0; del.anchor_right = 1.0; del.anchor_top = 0.5; del.anchor_bottom = 0.5
	del.offset_left = -46; del.offset_top = -18; del.offset_right = -10; del.offset_bottom = 18
	Press.attach(del)
	header.add_child(del)

	# Unread dot, to the left of the delete button (hidden once read).
	var dot := Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(1.0, 0.55, 0.25)
	ds.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("panel", ds)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(14, 14)
	dot.anchor_left = 1.0; dot.anchor_right = 1.0; dot.anchor_top = 0.5; dot.anchor_bottom = 0.5
	dot.offset_left = -70; dot.offset_top = -7; dot.offset_right = -56; dot.offset_bottom = 7
	dot.visible = not MailStore.is_read(m.id)
	header.add_child(dot)

	var body := Label.new()
	body.text = m.body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.78, 0.85, 0.93))
	body.visible = false
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.visible = false
	pad.add_child(body)
	box.add_child(pad)

	header.pressed.connect(func():
		pad.visible = not pad.visible
		body.visible = pad.visible
		if pad.visible and dot.visible:
			dot.visible = false            # reading it clears the unread dot
			MailStore.mark_read(m.id))
	del.pressed.connect(func():
		MailStore.mark_deleted(m.id)
		box.queue_free()
		_visible_count -= 1
		if _visible_count <= 0:
			_empty.visible = true)
	return box

func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l; c.anchor_top = t; c.anchor_right = r; c.anchor_bottom = b
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0
