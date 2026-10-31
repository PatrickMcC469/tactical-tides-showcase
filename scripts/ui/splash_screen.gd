## Launch splash: shows the Tactical Tides splash art, then advances to the main menu
## (auto after a few seconds, or on tap).
extends Control

var _advanced := false
var _account_ready := false

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assests/UI/TT_splash_screen.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	_prepare_account()   # runs during the splash so the menu opens with a real account ready
	await get_tree().create_timer(2.5).timeout
	_go()

## Restore-or-create the player's account while the splash art is showing (see Auth.ensure_account()).
func _prepare_account() -> void:
	await Auth.ensure_account()
	_account_ready = true

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_go()

func _go() -> void:
	if _advanced:
		return
	_advanced = true
	# Don't enter the menu until the account attempt finishes (usually already done by now). If Auth
	# isn't configured (no key / offline), fall straight through — Net keeps a guest id as fallback.
	while not _account_ready and Auth.configured():
		await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
