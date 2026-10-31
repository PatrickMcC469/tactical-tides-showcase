## Headless entrypoint for the referee (Cloud Run and local). Runs as a --script main loop so NONE of
## the game autoloads (Audio, Cosmetics, Net, …) initialize — the server needs only the pure rules +
## net classes (all class_name globals), never a texture or audio stream. Boots the referee node and
## lets the SceneTree tick it forever (we don't override _process, so the node's _process still runs).
##   Godot --headless --path <proj> --script res://scripts/server/server_main.gd
extends SceneTree

func _initialize() -> void:
	root.add_child(load("res://scripts/server/referee_server.gd").new())
	print("server_main: referee started")
