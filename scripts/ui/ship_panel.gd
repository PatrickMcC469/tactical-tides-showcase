## Left-side detail panel for the focused ship: its image, HP, reload status, and special charge.
## Ship images load from res://assests/ships/<id>.png if present; otherwise a colored placeholder.
class_name ShipPanel
extends PanelContainer

var name_lbl: Label
var img: TextureRect
var placeholder: ColorRect
var hp_lbl: Label
var hp_bar: ProgressBar
var reload_lbl: Label
var special_lbl: Label
var special_bar: ProgressBar

func _ready() -> void:
	custom_minimum_size = Vector2(232, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.offset_left = 10; v.offset_top = 10; v.offset_right = -10; v.offset_bottom = -10
	add_child(v)

	name_lbl = Label.new()
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lbl)

	var box := Control.new()
	box.custom_minimum_size = Vector2(0, 188)
	v.add_child(box)
	placeholder = ColorRect.new()
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(placeholder)
	img = TextureRect.new()
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(img)

	hp_lbl = Label.new()
	v.add_child(hp_lbl)
	hp_bar = _bar(v, Color(0.45, 0.78, 0.45))
	reload_lbl = Label.new()
	v.add_child(reload_lbl)
	special_lbl = Label.new()
	v.add_child(special_lbl)
	special_bar = _bar(v, Color(0.95, 0.82, 0.30))
	set_ship(null)

func _bar(parent: Node, col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 14)
	b.add_theme_color_override("font_color", Color.TRANSPARENT)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b

func set_ship(ship: ShipInstance) -> void:
	if ship == null:
		name_lbl.text = "— tap a ship —"
		img.visible = false
		placeholder.visible = true
		placeholder.color = Color(0.12, 0.15, 0.20)
		hp_lbl.text = ""
		reload_lbl.text = ""
		special_lbl.text = ""
		hp_bar.visible = false
		special_bar.visible = false
		return
	name_lbl.text = ship.def.display_name
	var tex := BoardView.ship_sprite(ship.def.id)
	if tex != null:
		img.texture = tex
		img.visible = true
		placeholder.visible = false
	else:
		img.visible = false
		placeholder.visible = true
		placeholder.color = BoardView.ship_color(ship.def.id)
	hp_bar.visible = true
	hp_bar.max_value = ship.def.max_health
	hp_bar.value = ship.hp()
	hp_lbl.text = "HP   %d / %d" % [ship.hp(), ship.def.max_health]
	reload_lbl.text = "Reload: Ready" if ship.reload_cooldown == 0 else "Reload: %d turn(s)" % ship.reload_cooldown
	var thr := Tiers.charge_threshold(ship.def.charge)
	special_bar.visible = true
	special_bar.max_value = thr
	special_bar.value = mini(ship.charge, thr)
	special_lbl.text = "Special: READY" if ship.charge_ready() else "Special: %d turn(s)" % (thr - ship.charge)
