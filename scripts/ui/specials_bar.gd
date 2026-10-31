## A row of the six special tokens for the current player's fleet. Each token is dim with a
## bottom-up fill while its special charges, then full-brightness with a glowing ring when ready.
## Tapping a ready token arms that ship's special.
class_name SpecialsBar
extends Control

signal special_selected(ship: ShipInstance)

const TOKENS := {
	&"battleship": preload("res://assests/special_tokens/battleship_special.png"),
	&"aircraft_carrier": preload("res://assests/special_tokens/aircraft_carrier_special.png"),
	&"cruiser": preload("res://assests/special_tokens/cruiser_special.png"),
	&"destroyer": preload("res://assests/special_tokens/destroyer_special.png"),
	&"submarine": preload("res://assests/special_tokens/submarine_special.png"),
	&"drone_ship": preload("res://assests/special_tokens/drone_special.png"),
}

var entries: Array = []   # each: {ship, frac (0..1), ready (bool)}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 44)

func set_entries(e: Array) -> void:
	entries = e
	queue_redraw()

func _slot() -> float:
	return size.x / maxf(float(entries.size()), 1.0)

func _gui_input(event: InputEvent) -> void:
	var pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return
	var i := int(pos.x / _slot())
	if i >= 0 and i < entries.size() and entries[i].ready:
		special_selected.emit(entries[i].ship)

func _draw() -> void:
	if entries.is_empty():
		return
	var slot := _slot()
	var ts := minf(slot - 8.0, size.y - 6.0)
	for i in entries.size():
		var e = entries[i]
		var tex: Texture2D = TOKENS.get(e.ship.def.id)
		if tex == null:
			continue
		var rect := Rect2(i * slot + (slot - ts) * 0.5, (size.y - ts) * 0.5, ts, ts)
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, 1.0 if e.ready else 0.5))
		if e.ready:
			draw_arc(rect.get_center(), ts * 0.52, 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.95), 2.5)
		else:
			var fill_h := rect.size.y * clampf(float(e.frac), 0.0, 1.0)
			draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, rect.size.y - fill_h), Color(0, 0, 0, 0.5))
