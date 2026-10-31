## Verifies the Supabase-backed match server end to end. FIRST run docs/supabase/schema.sql in the
## Supabase SQL editor, then set your service key in the environment (never paste it anywhere):
##   Windows (PowerShell):  $env:SUPABASE_SERVICE_KEY = "sb_secret_..."
## then run headless:
##   Godot_v4.6-stable_win64.exe --headless --path . server/supabase_test.tscn
extends Node

func _ready() -> void:
	var srv := SupabaseServer.new(self)
	if not srv.configured():
		print("SET the SUPABASE_SERVICE_KEY environment variable first (never paste it in chat).")
		get_tree().quit()
		return
	print("--- Supabase round-trip ---")
	var c := await srv.create_match("alice", {"battleship": "battleship_void"})
	print("create  -> ok=%s id=%s code=%s" % [c.get("ok"), c.get("match_id"), c.get("invite_code")])
	if not c.get("ok", false):
		print("  (create failed — did you run schema.sql and set the SERVICE key?)")
		get_tree().quit()
		return
	var mid := String(c.get("match_id"))
	var j := await srv.join_match(String(c.get("invite_code")), "bob", {"battleship": "battleship_gold"})
	print("join    -> ok=%s" % j.get("ok"))
	var v := await srv.get_view(mid, "alice")
	print("view    -> own_ships=%d  opponent_skins=%s  your_turn=%s  enemy_fleet_hidden=%s"
		% [v.get("own_ships", []).size(), v.get("opponent_skins"), v.get("your_turn"), not v.has("boards")])
	var turn := {"player": 0, "move_ship": "", "move_steps": [], "special_id": "", "special_aim": [],
		"special_orient": 0, "powerup_picks": [], "fire_id": "cross_shot", "fire_aim": [[8, 2]], "fire_orient": 0}
	var r := await srv.submit_turn(mid, "alice", turn)
	print("submit  -> ok=%s hits=%d winner=%s reward=%s" % [r.get("ok"), r.get("hits", []).size(), r.get("winner"), r.get("reward")])
	var v2 := await srv.get_view(mid, "bob")
	print("re-fetch-> turn=%s your_turn=%s  (state PERSISTED + advanced)" % [v2.get("turn_number"), v2.get("your_turn")])
	print("--- done ---")
	get_tree().quit()
