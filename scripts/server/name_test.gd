## Verify captain names travel with a match: host "Tevin" vs guest "Kade" -> each sees the other's
## name in get_view (versus screen) and list_matches (games list).
extends SceneTree

const FLEET := [["battleship", 2, 2, 0], ["aircraft_carrier", 8, 2, 0], ["cruiser", 14, 6, 0],
	["submarine", 4, 14, 0], ["destroyer", 10, 14, 0], ["drone_ship", 16, 15, 0]]

func _init() -> void:
	_run()

func _run() -> void:
	var srv := LocalServer.new()
	var a: Dictionary = srv.create_match("host1", {}, FLEET, "Tevin")
	srv.join_match(a.invite_code, "guest1", {}, "Kade")
	srv.submit_placement(a.match_id, "guest1", FLEET)

	var vh: Dictionary = srv.get_view(a.match_id, "host1")
	var vg: Dictionary = srv.get_view(a.match_id, "guest1")
	print("host sees opponent  = ", vh.get("opponent_name"))
	print("guest sees opponent = ", vg.get("opponent_name"))
	var list: Array = srv.list_matches("host1")
	print("host games-list opponent = ", list[0].opponent if not list.is_empty() else "?")

	var ok: bool = vh.get("opponent_name") == "Kade" and vg.get("opponent_name") == "Tevin" \
		and not list.is_empty() and list[0].opponent == "Kade"
	print("PASS" if ok else "FAIL")
	quit()
