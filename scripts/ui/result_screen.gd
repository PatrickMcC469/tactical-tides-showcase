## Post-game result screen with a cinematic reveal:
##   1. the game fades to black
##   2. the VICTORY / DEFEAT image fades in from black
##   3. the red alert light flashes
##   4. (loser) a currency popup reveals the consolation coins
##   5. a Continue button appears -> `dismissed`
## Uses winner.png / loss.png if present, else a titled fallback so the flow works before the art
## exists. Set the fields, add it as a child, connect `dismissed`.
class_name ResultScreen
extends Control

signal dismissed
signal home       # "back to menu" from the result screen

var won := true
var image_path := ""
var coins := 0                 # consolation coins to reveal (loser); 0 = no popup (winner uses the wheel)
var button_text := "CONTINUE"

var _content: Control
var _black: ColorRect
var _flash: _Flash
var _popup: Control
var _btn: Button
var _home_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# The image (or fallback), hidden until we reveal it from black.
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.modulate.a = 0.0
	add_child(_content)
	if image_path != "" and ResourceLoader.exists(image_path):
		var img := TextureRect.new()
		img.texture = load(image_path)
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(img)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.14, 0.11, 0.03) if won else Color(0.14, 0.035, 0.045)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(bg)
		var title := Label.new()
		title.text = "VICTORY!" if won else "DEFEAT"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 72)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if won else Color(0.85, 0.32, 0.30))
		title.position = Vector2(212, 190); title.size = Vector2(600, 100)
		_content.add_child(title)

	# Red light flash overlay (over the caged light, top-center).
	_flash = _Flash.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)

	# Black cover that fades in (hide the game) then out (reveal the image).
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	add_child(_black)

	# Currency popup (loser only), hidden until revealed.
	_popup = _build_popup()
	_popup.visible = false
	add_child(_popup)

	_btn = Button.new()
	_btn.text = button_text
	_btn.add_theme_font_size_override("font_size", 24)
	_btn.size = Vector2(260, 52); _btn.position = Vector2(512 - 130, 508)
	_btn.modulate.a = 0.0
	_btn.pressed.connect(func(): dismissed.emit())
	add_child(_btn)

	_home_btn = Button.new()
	_home_btn.text = "⌂ Home"
	_home_btn.add_theme_font_size_override("font_size", 16)
	_home_btn.size = Vector2(112, 40); _home_btn.position = Vector2(20, 20)
	_home_btn.modulate.a = 0.0
	_home_btn.pressed.connect(func(): home.emit())
	add_child(_home_btn)

	_run_intro()

func _run_intro() -> void:
	# 1. Fade the game to black.
	var t1 := create_tween()
	t1.tween_property(_black, "modulate:a", 1.0, 0.7)
	await t1.finished
	# 2. Reveal the result image from black, with the win/lose sting.
	_content.modulate.a = 1.0
	Audio.play("win" if won else "lose")
	var t2 := create_tween()
	t2.tween_property(_black, "modulate:a", 0.0, 0.7)
	await t2.finished
	# 3. A short flash of the red light.
	var tf := create_tween()
	tf.tween_property(_flash, "modulate:a", 1.0, 0.08)
	tf.tween_property(_flash, "modulate:a", 0.0, 0.55)
	await get_tree().create_timer(0.55).timeout
	# 4. Currency popup (loser consolation).
	if coins > 0:
		_popup.visible = true
		_popup.pivot_offset = _popup.size * 0.5
		_popup.scale = Vector2(0.6, 0.6)
		create_tween().tween_property(_popup, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.55).timeout
	# 5. Continue + Home buttons.
	create_tween().tween_property(_btn, "modulate:a", 1.0, 0.3)
	create_tween().tween_property(_home_btn, "modulate:a", 1.0, 0.3)

func _build_popup() -> Control:
	var p := Panel.new()
	p.size = Vector2(260, 88); p.position = Vector2(512 - 130, 372)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.30, 0.8)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = "+ %d COINS" % coins
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_top = 8
	p.add_child(l)
	var cap := Label.new()
	cap.text = "for playing"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	cap.position = Vector2(0, 60); cap.size = Vector2(260, 20)
	p.add_child(cap)
	return p

## Red radial flash over the caged light (top-center of the frame).
class _Flash extends Control:
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.062)
		for i in 12:
			var t := i / 12.0
			draw_circle(c, 74.0 * (1.0 - t) + 16.0, Color(1.0, 0.12, 0.09, 0.12 * (1.0 - t)))
		draw_circle(c, 16.0, Color(1.0, 0.4, 0.35, 0.6))
