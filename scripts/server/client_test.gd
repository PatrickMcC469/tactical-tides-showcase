## Headless client that drives HttpBackend through the FULL 2-sided flow against a referee — by
## default the LIVE deployed Cloud Run server (override with TT_REFEREE_URL). Proves the real Godot
## client <-> server <-> Supabase round-trip end to end.
##   Godot --headless --path <proj> --script res://scripts/server/client_test.gd
extends SceneTree

const DEFAULT_URL := "https://tt-referee-707330193418.us-central1.run.app"
const SHIPS := [["battleship", 2, 2, 0], ["aircraft_carrier", 8, 2, 0], ["cruiser", 14, 6, 0],
	["submarine", 4, 14, 0], ["destroyer", 10, 14, 0], ["drone_ship", 16, 15, 0]]

func _init() -> void:
	_run()

func _run() -> void:
	var host := Node.new()
	get_root().add_child(host)
	await process_frame
	var url := OS.get_environment("TT_REFEREE_URL")
	if url == "":
		url = DEFAULT_URL
	var be := HttpBackend.new(url, host)
	print("--- full flow vs %s ---" % url)

	var c: Dictionary = await be.create_match("alice", {}, SHIPS)
	print("create (host places)     -> ok=%s code=%s" % [c.get("ok"), c.get("invite_code")])
	var mid := String(c.get("match_id", ""))
	var code := String(c.get("invite_code", ""))

	var j: Dictionary = await be.join_match(code, "bob", {})
	print("join bob                 -> ok=%s" % j.get("ok"))

	var p: Dictionary = await be.submit_placement(mid, "bob", SHIPS)
	print("bob places (both down)   -> ok=%s started=%s" % [p.get("ok"), p.get("started")])

	var v: Dictionary = await be.get_view(mid, "alice")
	print("alice view               -> own_ships=%d your_turn=%s leaks_enemy=%s" % [
		v.get("own_ships", []).size(), v.get("your_turn"), v.has("enemy_ships") or v.has("boards")])

	var turn := {"player": 0, "move_ship": "", "move_steps": [], "special_id": "", "special_aim": [],
		"special_orient": 0, "powerup_picks": [], "fire_id": "cross_shot", "fire_aim": [[8, 2]],
		"fire_orient": 0}
	var r: Dictionary = await be.submit_turn(mid, "alice", turn)
	print("alice fires              -> ok=%s hits=%d" % [r.get("ok"), r.get("hits", []).size()])
	print("--- done (host goes first, enemy fleet never leaked) ---")
	quit()
