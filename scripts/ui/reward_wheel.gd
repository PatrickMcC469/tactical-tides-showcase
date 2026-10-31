## Post-game reward wheel: the winner spins to see how many coins they win. Full-screen overlay;
## add it as a child of a screen and call begin(). The wheel is RIGGED to land on a pre-decided
## amount — for hot-seat we roll locally and bank to the local wallet; online will pass the SERVER's
## rolled amount (bank_local = false) so the client can never force the payout.
##
## Art: spin_wheel.png is the rotating disc (6 blank segments); spin_wheel_frame.png is the same art
## with the disc punched transparent, laid static on top so its baked pointer stays fixed while the
## disc spins under it. Coin values are drawn onto the disc. If the art is missing, a code-drawn
## wheel + pointer with the same layout is used so the flow is still testable.
class_name RewardWheel
extends Control

signal collected(amount: int)

## The reward table lives in the shared Rewards module (the SERVER rolls from the same one). The
## wheel just displays these segments, clockwise from the top, and lands on the chosen amount.
const SEGMENTS := Rewards.SEGMENTS
const WHEEL_ART := "res://assests/UI/spin_wheel.png"
const WHEEL_FRAME := "res://assests/UI/spin_wheel_frame.png"
const WHEEL_SIZE := Vector2(360, 360)
const WHEEL_POS := Vector2(332, 104)

var _bank_local := true
var _target_idx := 0
var _amount := 0
var _spun := false
var _collected := false

var _face: WheelFace
var _spin_btn: Button
var _collect_btn: Button
var _result: Label

## forced_amount >= 0 rigs the wheel to that coin value (server reward); -1 rolls locally.
## bank_local adds the coins to the local wallet on collect (hot-seat now; false online).
func begin(forced_amount: int = -1, bank_local: bool = true) -> void:
	_bank_local = bank_local
	_target_idx = _index_for(forced_amount) if forced_amount >= 0 else _weighted_roll()
	_amount = int(SEGMENTS[_target_idx].coins)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var title := Label.new()
	title.text = "VICTORY!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.40))
	title.position = Vector2(312, 18); title.size = Vector2(400, 48)
	add_child(title)

	var sub := Label.new()
	sub.text = "Spin the wheel for your reward"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	sub.position = Vector2(312, 62); sub.size = Vector2(400, 24)
	add_child(sub)

	var disc_tex: Texture2D = load(WHEEL_ART) if ResourceLoader.exists(WHEEL_ART) else null
	_face = WheelFace.new()
	_face.segments = SEGMENTS
	_face.texture = disc_tex
	_face.size = WHEEL_SIZE
	_face.position = WHEEL_POS
	_face.pivot_offset = WHEEL_SIZE * 0.5
	add_child(_face)

	# Static frame+pointer over the spinning disc, or a drawn pointer for the fallback wheel.
	if disc_tex != null and ResourceLoader.exists(WHEEL_FRAME):
		var frame := TextureRect.new()
		frame.texture = load(WHEEL_FRAME)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.size = WHEEL_SIZE
		frame.position = WHEEL_POS
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
	else:
		var pointer := Pointer.new()
		pointer.size = Vector2(44, 40)
		pointer.position = WHEEL_POS + Vector2(WHEEL_SIZE.x * 0.5 - 22, -26)
		pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pointer)

	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 30)
	_result.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_result.position = Vector2(262, 474); _result.size = Vector2(500, 40)
	_result.visible = false
	add_child(_result)

	_spin_btn = Button.new()
	_spin_btn.text = "SPIN"
	_spin_btn.add_theme_font_size_override("font_size", 24)
	_spin_btn.position = Vector2(452, 502); _spin_btn.size = Vector2(120, 54)
	_spin_btn.pressed.connect(_on_spin)
	add_child(_spin_btn)

	_collect_btn = Button.new()
	_collect_btn.text = "COLLECT"
	_collect_btn.add_theme_font_size_override("font_size", 24)
	_collect_btn.position = Vector2(432, 524); _collect_btn.size = Vector2(160, 54)
	_collect_btn.visible = false
	_collect_btn.pressed.connect(_on_collect)
	add_child(_collect_btn)

func _on_spin() -> void:
	if _spun:
		return
	_spun = true
	_spin_btn.disabled = true
	var seg := TAU / float(SEGMENTS.size())
	var settle := fposmod(-_target_idx * seg, TAU)
	settle = fposmod(settle + randf_range(-seg * 0.30, seg * 0.30), TAU)   # not always dead-center
	var cur := _face.rotation
	var target := cur + 5.0 * TAU + fposmod(settle - fposmod(cur, TAU), TAU)
	var tw := create_tween()
	tw.tween_property(_face, "rotation", target, 4.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tw.finished
	_result.text = "You won %s coins!" % CurrencyBlock.format(_amount)
	_result.visible = true
	_spin_btn.visible = false
	_collect_btn.visible = true

func _on_collect() -> void:
	if _collected:
		return
	_collected = true
	if _bank_local:
		Cosmetics.add_coins(_amount)
	collected.emit(_amount)

func _index_for(coins: int) -> int:
	for i in SEGMENTS.size():
		if int(SEGMENTS[i].coins) == coins:
			return i
	return 0   # amount not on the wheel — land on the first segment (server can extend the table)

func _weighted_roll() -> int:
	var total := 0
	for s in SEGMENTS:
		total += int(s.weight)
	var r := randi() % total
	var acc := 0
	for i in SEGMENTS.size():
		acc += int(SEGMENTS[i].weight)
		if r < acc:
			return i
	return SEGMENTS.size() - 1

## The rotating disc. Draws spin_wheel.png (with coin values overlaid on each segment) if present,
## else a code-drawn wheel with the same layout (segment 0 centered at the top so the rig lines up).
class WheelFace extends Control:
	var texture: Texture2D
	var segments: Array = []
	const COLORS := [Color(0.10, 0.28, 0.48), Color(0.06, 0.16, 0.30)]
	const JACKPOT := Color(0.55, 0.16, 0.16)

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		var n := segments.size()
		if n == 0:
			return
		var seg := TAU / float(n)
		var font := ThemeDB.fallback_font
		if texture != null:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
		else:
			for i in n:
				var a0 := -PI / 2.0 - seg * 0.5 + i * seg   # top = -PI/2, segment 0 centered there
				var pts := PackedVector2Array([c])
				for s in 13:
					var a := a0 + seg * (s / 12.0)
					pts.append(c + Vector2(cos(a), sin(a)) * rad)
				var col: Color = JACKPOT if int(segments[i].coins) >= 1000 else COLORS[i % 2]
				draw_colored_polygon(pts, col)
			draw_arc(c, rad - 2, 0, TAU, 96, Color(0.9, 0.8, 0.4), 4)
			draw_circle(c, rad * 0.12, Color(0.9, 0.8, 0.4))
		# Coin values, on each segment center (drawn for both texture and fallback).
		for i in n:
			var mid := -PI / 2.0 + i * seg
			var lp := c + Vector2(cos(mid), sin(mid)) * rad * 0.60
			var txt := str(segments[i].coins)
			draw_string(font, lp - Vector2(33, -6), txt, HORIZONTAL_ALIGNMENT_CENTER, 66, 22, Color(0, 0, 0, 0.85))
			draw_string(font, lp - Vector2(34, -7), txt, HORIZONTAL_ALIGNMENT_CENTER, 66, 22, Color(1, 0.9, 0.55))

## Fixed gold pointer above the wheel, pointing down (fallback only — the art has its own).
class Pointer extends Control:
	func _draw() -> void:
		var pts := PackedVector2Array([
			Vector2(size.x * 0.5, size.y),
			Vector2(size.x * 0.18, 0),
			Vector2(size.x * 0.82, 0),
		])
		draw_colored_polygon(pts, Color(1.0, 0.82, 0.30))
		draw_polyline(PackedVector2Array([pts[1], pts[0], pts[2]]), Color(0.4, 0.28, 0.05), 2.0)
