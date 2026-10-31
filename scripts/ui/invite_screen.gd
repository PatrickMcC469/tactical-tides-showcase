## Invite screen (on GameFrame). Shown after you create a match: displays the shareable code with a
## big SHARE button (native OS share sheet via ShareUtil, clipboard fallback) + COPY, your fleet in
## the left panel, and a "waiting for your friend" status. Reads MatchSession.invite_code.
extends Control

const GOLD := Color(1.0, 0.86, 0.40)

var _toast: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var f := GameFrame.new()
	add_child(f)
	f.fleet_btn.visible = false      # not a game view — no My Fleet/Enemy toggle
	f.battle_btn.visible = false
	await get_tree().process_frame    # let the frame size before we read panel rects

	var code := MatchSession.invite_code if MatchSession.invite_code != "" else "------"

	# LEFT panel: your fleet (flair while you wait).
	var lr: Rect2 = f.rect_px(GameFrame.LEFT)
	var roster := ShipCatalog.all()
	var th := lr.size.y / roster.size()
	for i in roster.size():
		var d: ShipDef = roster[i]
		var img := TextureRect.new()
		img.texture = BoardView.ship_side(d.id)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.position = lr.position + Vector2(4, i * th + 2); img.size = Vector2(lr.size.x - 8, th - 16)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(img)
		var nm := Label.new(); nm.text = d.display_name
		nm.add_theme_font_size_override("font_size", 10); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_color_override("font_color", Color(0.8, 0.88, 1)); nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.position = lr.position + Vector2(0, i * th + th - 15); nm.size = Vector2(lr.size.x, 14)
		add_child(nm)

	# CENTER panel: the shareable code + instructions.
	var cr: Rect2 = f.rect_px(GameFrame.CENTER)
	_center_label("SHARE THIS CODE", cr, 0.10, 22, Color(0.75, 0.85, 0.95))
	_center_label(code, cr, 0.30, 66, GOLD)
	_center_label("Send it to a friend — they tap\nJoin with Code to accept.", cr, 0.52, 16, Color(0.82, 0.88, 0.96))
	_center_label("Waiting for your friend to join…", cr, 0.74, 15, Color(0.6, 0.72, 0.85))

	# RIGHT panel: a short "how it works" hint.
	var rr: Rect2 = f.rect_px(GameFrame.RIGHT)
	_center_label("The match is created and\nsaved. You can leave and\nplay other games — it'll be\nwaiting in CURRENT GAMES\nwhen your friend joins.", rr, 0.20, 12, Color(0.78, 0.85, 0.94))

	# Bottom console: SHARE (primary) + COPY.
	_button("SHARE  INVITE", 0.42, 210, GOLD, func(): _share(code))
	_button("Copy Code", 0.615, 150, Color(0.6, 0.72, 0.85), func(): _copy(code))
	# (Home + Settings come from the GameFrame chrome now — top corners.)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0)); _toast.add_theme_constant_override("outline_size", 6)
	_toast.position = Vector2(262, 452); _toast.size = Vector2(500, 30); _toast.modulate.a = 0.0
	add_child(_toast)

	if "--shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_invite.png")
		get_tree().quit()

func _share(code: String) -> void:
	var native := ShareUtil.share_text("Battle me in Tactical Tides! Join with code: %s" % code)
	if not native:
		_show_toast("Copied — paste it to a friend!")   # fell back to clipboard

func _copy(code: String) -> void:
	DisplayServer.clipboard_set(code)
	_show_toast("Code copied")

func _center_label(text: String, rect: Rect2, yfrac: float, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = rect.position + Vector2(0, rect.size.y * yfrac); l.size = Vector2(rect.size.x, rect.size.y * 0.22)
	add_child(l)

func _button(text: String, cx: float, w: float, accent: Color, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	var vp := get_viewport_rect().size
	b.size = Vector2(w, 50); b.position = Vector2(vp.x * cx - w * 0.5, vp.y * 0.885 - 25)
	b.pressed.connect(cb)
	add_child(b)

func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
