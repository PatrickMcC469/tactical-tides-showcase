## Verifies sunk ships survive: sink one, check it moves to board.sunk + find_by_id locates it, then
## round-trip the whole match through MatchCodec and confirm the wreck is still there (online path).
extends SceneTree

const FLEET := [["battleship", 2, 2, 0], ["aircraft_carrier", 8, 2, 0], ["cruiser", 14, 6, 0],
	["submarine", 4, 14, 0], ["destroyer", 10, 14, 0], ["drone_ship", 16, 15, 0]]

func _init() -> void:
	_run()

func _run() -> void:
	var gs := GameState.new()
	Placement.apply(gs, 0, FLEET)
	var b: Board = gs.boards[0]
	b.reindex()
	print("start: alive=%d sunk=%d" % [b.ships.size(), b.sunk.size()])

	var ship: ShipInstance = b.ships[0]
	var res := b.apply_hits(ship.all_cells())   # blow off every cell -> sink
	print("after sink: alive=%d sunk=%d res.sunk=%d" % [b.ships.size(), b.sunk.size(), res.sunk.size()])
	var f := b.find_by_id(&"battleship")
	print("find_by_id(battleship): %s (alive=%s)" % ["FOUND" if f else "NULL", f.is_alive() if f else "-"])

	var gs2 := MatchCodec.decode(MatchCodec.encode(gs))
	var b2: Board = gs2.boards[0]
	var f2 := b2.find_by_id(&"battleship")
	print("after codec: alive=%d sunk=%d  battleship=%s (alive=%s)" % [
		b2.ships.size(), b2.sunk.size(), "FOUND" if f2 else "NULL", f2.is_alive() if f2 else "-"])

	var ok := f != null and not f.is_alive() and b.sunk.size() == 1 \
		and f2 != null and not f2.is_alive() and b2.sunk.size() == 1
	print("PASS" if ok else "FAIL")
	quit()
