## A self-drawn currency widget: a rounded pill with a gold coin, the player's balance
## (comma-formatted, never blank), and a ＋. Emits `pressed` when tapped (wire it to the coin
## store). Drop it on any screen and anchor it — no baked art needed, so it never mis-aligns with
## a background PNG. Call refresh() after the balance changes.
class_name CurrencyBlock
extends Control

signal pressed

const PANEL_BG := Color(0.05, 0.08, 0.13, 0.94)
const BORDER := Color(0.55, 0.62, 0.72, 0.55)
const GOLD := Color(1.0, 0.82, 0.30)
const GOLD_DARK := Color(0.58, 0.42, 0.12)
const TEXT := Color(1.0, 0.92, 0.72)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	var h := size.y
	var w := size.x
	var font := ThemeDB.fallback_font

	# Pill.
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(int(h * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = BORDER
	draw_style_box(sb, Rect2(Vector2.ZERO, size))

	# Coin: concentric gold rings + a star.
	var cc := Vector2(h * 0.58, h * 0.5)
	var r := h * 0.30
	draw_circle(cc, r, GOLD_DARK)
	draw_circle(cc, r * 0.86, GOLD)
	draw_circle(cc, r * 0.66, GOLD_DARK)
	draw_colored_polygon(_star(cc, r * 0.52, r * 0.22, 5), GOLD)

	# Balance.
	var txt := format(Cosmetics.coins)
	var fs := int(h * 0.48)
	draw_string(font, Vector2(h * 1.05, h * 0.5 + fs * 0.36), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT)

	# Plus (add coins).
	var pfs := int(h * 0.72)
	draw_string(font, Vector2(w - h * 0.62, h * 0.5 + pfs * 0.34), "+",
		HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, GOLD)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()

## A `points`-pointed star polygon around `center`.
func _star(center: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var rad := outer if i % 2 == 0 else inner
		var ang := -PI / 2.0 + i * PI / float(points)
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	return pts

## Thousands-separated, never blank ("0", "1,250", "22,500").
static func format(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
