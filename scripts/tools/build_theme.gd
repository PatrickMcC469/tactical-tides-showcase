## One-off tool: build the global "naval" UI theme and save it as a .tres, so every screen's
## buttons / panels / labels / bars share one professional, cohesive look instead of the default
## Godot gray. Run: godot --headless --path <proj> --script res://scripts/tools/build_theme.gd
## Then set gui/theme/custom to res://ui/theme/tactical_theme.tres in project settings.
extends SceneTree

const OUT := "res://ui/theme/tactical_theme.tres"

# palette
const INK        := Color(0.055, 0.090, 0.140)   # deep hull navy
const STEEL      := Color(0.115, 0.175, 0.255)   # button face
const STEEL_HI   := Color(0.165, 0.245, 0.345)   # hover face
const STEEL_LO   := Color(0.080, 0.120, 0.175)   # pressed face
const EDGE       := Color(0.290, 0.430, 0.590)   # steel-blue rim
const EDGE_HI    := Color(0.470, 0.680, 0.880)   # hover rim
const GOLD       := Color(0.850, 0.700, 0.350)   # accent rim (pressed)
const TEXT       := Color(0.870, 0.920, 0.985)
const TEXT_HI    := Color(1.0, 1.0, 1.0)
const TEXT_DIM   := Color(0.420, 0.470, 0.540)
const PANEL_BG   := Color(0.050, 0.085, 0.135, 0.92)

func _initialize() -> void:
	var th := Theme.new()
	th.default_font_size = 16

	# ---- Button ----
	th.set_stylebox("normal", "Button", _btn(STEEL, EDGE, 1.0))
	th.set_stylebox("hover", "Button", _btn(STEEL_HI, EDGE_HI, 1.0))
	th.set_stylebox("pressed", "Button", _btn(STEEL_LO, GOLD, 1.0))
	th.set_stylebox("disabled", "Button", _btn(Color(0.085, 0.105, 0.135, 0.7), Color(0.20, 0.24, 0.30), 1.0))
	th.set_stylebox("focus", "Button", _focus())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", TEXT_HI)
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_disabled_color", "Button", TEXT_DIM)
	th.set_font_size("font_size", "Button", 16)

	# ---- Panels (Panel + PanelContainer) ----
	var panel := _panel()
	th.set_stylebox("panel", "Panel", panel)
	th.set_stylebox("panel", "PanelContainer", panel)

	# ---- ProgressBar ----
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.035, 0.055, 0.085)
	bar_bg.set_border_width_all(1)
	bar_bg.border_color = Color(0.20, 0.30, 0.42)
	bar_bg.set_corner_radius_all(3)
	th.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = EDGE_HI
	bar_fill.set_corner_radius_all(3)
	th.set_stylebox("fill", "ProgressBar", bar_fill)

	# ---- Label ----
	th.set_color("font_color", "Label", TEXT)

	var err := ResourceSaver.save(th, OUT)
	print("build_theme: saved %s (err %d)" % [OUT, err])
	quit()

func _btn(fill: Color, edge: Color, edge_w: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(int(edge_w))
	sb.border_color = edge
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	sb.anti_aliasing = true
	return sb

func _panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_border_width_all(1)
	sb.border_color = Color(0.245, 0.375, 0.520)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	return sb

func _focus() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(1)
	sb.border_color = Color(EDGE_HI.r, EDGE_HI.g, EDGE_HI.b, 0.6)
	sb.set_corner_radius_all(5)
	return sb
