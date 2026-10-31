## Pre-match VERSUS reveal — a shareable "challenge" screen. Landscape split down the middle: YOUR
## fleet (equipped skins, cinematic broadside shots) up top, the ENEMY fleet below, a VS badge across
## the divide. Everything slides/pops in for a cinematic entrance, then BATTLE! proceeds to
## MatchSession.versus_next (defaults to placement). Enemy uses default skins until we transmit the
## opponent's cosmetics.
extends Control

const W := 1024.0
const H := 600.0
const TILE := 128.0
const GAP := 12.0
const ALLY := Color(0.10, 0.30, 0.55)
const ENEMY := Color(0.45, 0.11, 0.13)
const GOLD := Color(1.0, 0.82, 0.30)

var _next := "res://scenes/ui/placement_screen.tscn"
var _battle: TextureButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if MatchSession.versus_next != "":
		_next = MatchSession.versus_next
	_build()
	if "--shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.6).timeout   # let the entrance settle
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_vs.png")
		get_tree().quit()

func _build() -> void:
	Audio.play("versus")   # cinematic sting across the whole reveal
	# Tinted halves + a bright divider.
	_half(Vector2(0, 0), Vector2(W, H * 0.5), ALLY.darkened(0.62))
	_half(Vector2(0, H * 0.5), Vector2(W, H * 0.5), ENEMY.darkened(0.62))
	var line := ColorRect.new()
	line.color = GOLD
	line.position = Vector2(0, H * 0.5 - 1.5); line.size = Vector2(W, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	# Captain names so you can see who you're facing. Yours is your setting; theirs rides in on the
	# match (empty in hot-seat, where both fleets are you).
	var enemy_name: String = MatchSession.versus_enemy_name
	MatchSession.versus_enemy_name = ""   # one-shot: don't leak into the next game
	_side_label("YOUR FLEET  ·  %s" % Settings.captain_name().to_upper(), 12, GOLD)
	var enemy_label := "%s'S FLEET" % enemy_name.strip_edges().to_upper() if enemy_name.strip_edges() != "" else "ENEMY FLEET"
	_side_label(enemy_label, 494, Color(1.0, 0.6, 0.55))

	# Each side draws from a skin loadout (ship_id -> skin_key). Yours is your equipped Cosmetics;
	# the enemy's comes from the opponent online, or mirrors yours in hot-seat (both fleets are you).
	var your_skins: Dictionary = Cosmetics.active
	var enemy_skins: Dictionary = MatchSession.versus_enemy_skins
	MatchSession.versus_enemy_skins = {}   # one-shot: don't leak these into the next game
	if enemy_skins.is_empty():
		enemy_skins = your_skins

	var roster := ShipCatalog.all()
	var n := roster.size()
	var total := n * TILE + (n - 1) * GAP
	var start_x := (W - total) * 0.5

	for i in n:
		var def: ShipDef = roster[i]
		var x := start_x + i * (TILE + GAP)
		var key := String(def.id)
		# Yours (top) — your equipped skin; slides down from above.
		var top := _make_tile(BoardView.ship_side_skinned(def.id, String(your_skins.get(key, ""))),
			def.display_name, GOLD)
		top.position = Vector2(x, 38)
		add_child(top)
		_enter(top, Vector2(0, -50), i * 0.07)
		# Enemy (bottom) — opponent's skin; slides up from below.
		var bot := _make_tile(BoardView.ship_side_skinned(def.id, String(enemy_skins.get(key, ""))),
			def.display_name, Color(1.0, 0.55, 0.5))
		bot.position = Vector2(x, 362)
		add_child(bot)
		_enter(bot, Vector2(0, 50), i * 0.07)

	# VS badge, pops in after the fleets.
	var badge := VsBadge.new()
	badge.size = Vector2(118, 118)
	badge.position = Vector2(W * 0.5 - 59, H * 0.5 - 59)
	badge.pivot_offset = badge.size * 0.5
	badge.scale = Vector2.ZERO
	add_child(badge)
	var bt := create_tween()
	bt.tween_interval(n * 0.07 + 0.15)
	bt.tween_property(badge, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_battle = TextureButton.new()
	_battle.texture_normal = load("res://assests/UI/battle_button.png")
	_battle.ignore_texture_size = true
	_battle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_battle.size = Vector2(240, 74)
	_battle.position = Vector2(W * 0.5 - 120, 522)
	_battle.modulate.a = 0.0
	_battle.pressed.connect(func(): get_tree().change_scene_to_file(_next))
	add_child(_battle)
	create_tween().tween_property(_battle, "modulate:a", 1.0, 0.4).set_delay(n * 0.07 + 0.6)

func _half(pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col; r.position = pos; r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _side_label(text: String, y: float, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.position = Vector2(0, y); l.size = Vector2(W, 26)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)

## A framed square tile: cinematic ship shot + name.
func _make_tile(tex: Texture2D, sname: String, accent: Color) -> Control:
	var c := Control.new()
	c.size = Vector2(TILE, TILE)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.11, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.position = Vector2(6, 6); img.size = Vector2(TILE - 12, TILE - 34)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(img)
	var lbl := Label.new()
	lbl.text = sname
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	lbl.position = Vector2(0, TILE - 25); lbl.size = Vector2(TILE, 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(lbl)
	return c

## Slide + fade a tile into its resting position from `offset`, after `delay` seconds.
func _enter(node: Control, offset: Vector2, delay: float) -> void:
	var dest := node.position
	node.position = dest + offset
	node.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "position", dest, 0.42).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.30).set_delay(delay)

## The central VS emblem: a gold-edged diamond with "VS".
class VsBadge extends Control:
	const GOLD := Color(1.0, 0.82, 0.30)
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var d := PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r * 0.82, 0), c + Vector2(0, r), c + Vector2(-r * 0.82, 0)])
		draw_colored_polygon(d, Color(0.06, 0.09, 0.14))
		var loop := PackedVector2Array([d[0], d[1], d[2], d[3], d[0]])
		draw_polyline(loop, GOLD, 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(c.x - 40, c.y + 18), "VS",
			HORIZONTAL_ALIGNMENT_CENTER, 80, 46, GOLD)
