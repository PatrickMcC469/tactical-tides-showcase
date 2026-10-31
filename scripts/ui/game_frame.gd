## Reusable game-screen chrome: the submarine control-panel backdrop (game_screen_background.png)
## with FLEET / BATTLE buttons flanking the caged red alert light, plus named regions that each
## screen fills with its own content:
##   • LEFT panel   — your ships (cinematic _tl pictures)
##   • CENTER panel — the board / main content
##   • RIGHT panel  — details of the selected ship
##   • BOTTOM slot  — a per-screen action button (isolated PNG placed by the screen)
## Screens instantiate this, read the panel rects via rect_px(), connect fleet_pressed/battle_pressed,
## and call flash_alert() when the player fires or takes incoming fire (the red light pulses).
class_name GameFrame
extends Control

signal fleet_pressed
signal battle_pressed

const BG := "res://assests/UI/game_screen_background.png"
# Panel regions as fractions of the viewport (tuned to the art's dark screens + console slot).
const LEFT := Rect2(0.128, 0.150, 0.158, 0.650)
const CENTER := Rect2(0.312, 0.125, 0.376, 0.680)
const RIGHT := Rect2(0.714, 0.150, 0.158, 0.650)
const BOTTOM := Rect2(0.436, 0.838, 0.128, 0.120)
const LIGHT_CENTER := Vector2(0.505, 0.058)   # the caged red light

var fleet_btn: TextureButton
var battle_btn: TextureButton
var settings_btn: TextureButton
var home_btn: BaseButton
var _glow: _Glow

const HOME_ART := "res://assests/UI/home_button.png"   # drop your art here; a placeholder shows until then
# Gear + Home seated over the round dials on the right-side console panel. Fractions of the viewport,
# so they track the art at any screen size. Nudge these to line them up exactly.
const SETTINGS_POS := Vector2(0.924, 0.135)   # top-right round dial
const HOME_POS := Vector2(0.924, 0.445)       # middle-right round dial
const CORNER_H := 72.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load(BG)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_glow = _Glow.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate.a = 0.0                          # light is "off" until an alert
	add_child(_glow)

	fleet_btn = _make_btn("res://assests/UI/fleet_button.png", 0.300, 0.056, 46.0)
	fleet_btn.pressed.connect(func(): fleet_pressed.emit())
	battle_btn = _make_btn("res://assests/UI/battle_button.png", 0.700, 0.056, 46.0)
	battle_btn.pressed.connect(func(): battle_pressed.emit())

	# Settings gear + Home, seated over the round dials on the right-side console panel.
	settings_btn = _make_btn("res://assests/UI/setting_button.png", SETTINGS_POS.x, SETTINGS_POS.y, CORNER_H)
	settings_btn.pressed.connect(_open_settings)
	_make_home_btn()

func _open_settings() -> void:
	var here := get_tree().current_scene
	Settings.settings_return = here.scene_file_path if here != null else "res://scenes/ui/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/ui/settings_screen.tscn")

## Home button in the top-right corner → back to the main menu. Uses HOME_ART if present, otherwise a
## simple ⌂ placeholder button so it works before the art is dropped in.
func _make_home_btn() -> void:
	if ResourceLoader.exists(HOME_ART):
		home_btn = _make_btn(HOME_ART, HOME_POS.x, HOME_POS.y, CORNER_H)
	else:
		var tb := Button.new()
		tb.text = "⌂"
		tb.focus_mode = Control.FOCUS_NONE
		tb.add_theme_font_size_override("font_size", 30)
		tb.size = Vector2(CORNER_H, CORNER_H)
		tb.position = Vector2(size.x * HOME_POS.x - CORNER_H * 0.5, size.y * HOME_POS.y - CORNER_H * 0.5)
		Press.attach(tb)
		add_child(tb)
		home_btn = tb
	home_btn.pressed.connect(_confirm_home)

## Confirm before leaving to the menu, so a mid-turn tap isn't an accident. Online matches are
## server-saved (nothing is lost — you resume from Current Games); this just guards against fat-fingers.
func _confirm_home() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # eat taps behind the modal
	layer.add_child(dim)

	var card := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.99)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.47, 0.68, 0.88, 0.85)
	card.add_theme_stylebox_override("panel", sb)
	_anchor(dim, card, 0.30, 0.33, 0.70, 0.67)

	var title := Label.new()
	title.text = "Return to menu?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_anchor(dim, title, 0.30, 0.37, 0.70, 0.45)

	var body := Label.new()
	body.text = "Your match is saved — jump back in any time from Current Games."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.72, 0.80, 0.90))
	_anchor(dim, body, 0.33, 0.46, 0.67, 0.56)

	var stay := Button.new()
	stay.text = "Stay"
	stay.focus_mode = Control.FOCUS_NONE
	stay.pressed.connect(func(): layer.queue_free())
	Press.attach(stay)
	_anchor(dim, stay, 0.34, 0.57, 0.49, 0.635)

	var leave := Button.new()
	leave.text = "Leave"
	leave.focus_mode = Control.FOCUS_NONE
	leave.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	leave.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	Press.attach(leave)
	_anchor(dim, leave, 0.51, 0.57, 0.66, 0.635)

## Anchor a child into `parent` at the given viewport fractions (parent is the full-screen dim).
func _anchor(parent: Control, c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l; c.anchor_top = t; c.anchor_right = r; c.anchor_bottom = b
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0
	parent.add_child(c)

## A panel fraction-rect converted to pixels in this frame's space.
func rect_px(frac: Rect2) -> Rect2:
	return Rect2(frac.position * size, frac.size * size)

## Pulse the red alert light (call on your shot / on incoming fire).
func flash_alert(pulses: int = 2) -> void:
	var tw := create_tween()
	for _i in maxi(1, pulses):
		tw.tween_property(_glow, "modulate:a", 1.0, 0.10)
		tw.tween_property(_glow, "modulate:a", 0.0, 0.32)

func _make_btn(path: String, cx: float, cy: float, h: float) -> TextureButton:
	var tex: Texture2D = load(path)
	var w := h * tex.get_width() / float(tex.get_height())
	var b := TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(w, h)
	b.position = Vector2(size.x * cx - w * 0.5, size.y * cy - h * 0.5)
	Press.attach(b)   # tactile dip on tap
	add_child(b)
	return b

## The red glow drawn over the caged light — additive-looking radial falloff.
class _Glow extends Control:
	func _draw() -> void:
		var c := Vector2(size.x * 0.505, size.y * 0.058)
		for i in 10:
			var t := i / 10.0
			draw_circle(c, 46.0 * (1.0 - t) + 12.0, Color(1.0, 0.16, 0.12, 0.11 * (1.0 - t)))
		draw_circle(c, 13.0, Color(1.0, 0.55, 0.45, 0.55))
