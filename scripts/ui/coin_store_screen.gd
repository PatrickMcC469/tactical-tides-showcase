## Coin Store — the LAYOUT (backdrop, hotspots, back button, toast) lives in coin_store_screen.tscn and
## is editable in the editor. This script only wires the buttons and shows the toast. Purchases/ads are
## placeholders ("coming soon") until the IAP + rewarded-ad systems land.
extends Control

@onready var _toast: Label = $Toast

func _ready() -> void:
	Press.attach($Back)   # tactile dip on the visible back button
	if OS.get_cmdline_args().has("--shot") or OS.get_cmdline_user_args().has("--shot"):
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/tt_coinstore.png")
		get_tree().quit()

func _on_coins() -> void: _soon("Coins")
func _on_buy() -> void: _soon("Purchases")
func _on_watch_ad() -> void: _soon("Rewarded ads")
func _on_boost() -> void: _soon("Win booster")
func _on_bundles() -> void: get_tree().change_scene_to_file("res://scenes/ui/bundles_screen.tscn")
func _on_skins() -> void: get_tree().change_scene_to_file("res://scenes/ui/ship_skins_screen.tscn")
func _on_back() -> void: get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _soon(feature: String) -> void:
	_toast.text = "%s — coming soon" % feature
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
