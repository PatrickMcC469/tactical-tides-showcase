## Gives a button a tactile "push" feel: it dips inward on press and springs back on release, so a tap
## always feels registered. Works on any BaseButton (Button, TextureButton). Scale-only — it never
## touches modulate, so it won't fight buttons that use modulate for enabled/disabled dimming.
##   Press.attach(my_button)
class_name Press
extends RefCounted

static func attach(btn: BaseButton, dip: float = 0.90) -> void:
	btn.button_down.connect(func(): _dip(btn, dip))
	btn.button_up.connect(func(): _dip(btn, 1.0))
	btn.mouse_exited.connect(func(): if btn.scale != Vector2.ONE: _dip(btn, 1.0))

static func _dip(btn: Control, s: float) -> void:
	btn.pivot_offset = btn.size * 0.5   # scale from the button's center (size is valid at press time)
	var tw := btn.create_tween()
	# Quick dip going down; a little spring/overshoot coming back up — that's the satisfying part.
	tw.set_trans(Tween.TRANS_BACK if is_equal_approx(s, 1.0) else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(s, s), 0.09)
