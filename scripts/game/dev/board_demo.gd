## Phase 0 dev demo for the board + turn state. Sets up a tiny match with TWO separate boards
## (Battleship-style), then exercises sector scanning, turn flow, the emergency-shot rule,
## per-cell damage/sinking/win, and the torpedo's first-unstruck behavior. Print-only.
class_name BoardDemo
extends RefCounted

static func run() -> void:
	var gs := GameState.new()
	# Player 0's fleet — on Player 0's own board.
	_add(gs, &"aircraft_carrier", 0, Vector2i(1, 14), GameEnums.Facing.NORTH)
	_add(gs, &"battleship", 0, Vector2i(5, 13), GameEnums.Facing.NORTH)
	_add(gs, &"submarine", 0, Vector2i(10, 17), GameEnums.Facing.NORTH)
	# Player 1's fleet — on Player 1's OWN, separate board.
	_add(gs, &"battleship", 1, Vector2i(1, 1), GameEnums.Facing.NORTH)
	_add(gs, &"destroyer", 1, Vector2i(8, 1), GameEnums.Facing.NORTH)
	_add(gs, &"drone_ship", 1, Vector2i(15, 1), GameEnums.Facing.NORTH)
	_add(gs, &"cruiser", 1, Vector2i(15, 6), GameEnums.Facing.NORTH)
	gs.begin_turn()

	print("=== BOARD + TURN STATE DEMO (two separate boards, Battleship-style) ===\n")

	# --- The 5x5 sector grid (each board uses the same A1..D4 layout) ---
	print("Sector grid (each player's own 20x20 -> 16 zones):")
	for sy in Sectors.SECTORS_PER_AXIS:
		var row := ""
		for sx in Sectors.SECTORS_PER_AXIS:
			row += "  " + Sectors.label(Vector2i(sx, sy))
		print(row)
	print("")

	# --- Active Radar: Player 0 scans the ENEMY board (can't see it directly) ---
	print("Active Radar — Player 0 scans the ENEMY board:")
	for s in Sectors.all_sectors():
		var n := gs.enemy_board(0).count_ships_in_sector(s)
		if n > 0:
			print("  %s -> %d enemy ship(s)" % [Sectors.label(s), n])
	print("")

	# --- Barrage Zone: Player 0 marks a sector of the ENEMY board ---
	var target := Sectors.from_label("A2")
	var caught := gs.enemy_board(0).ships_in_sector(target)
	print("Barrage Zone — Player 0 marks ENEMY sector %s (%d cells):" % [
		Sectors.label(target), Sectors.cells_in_sector(target).size()])
	for ship in caught:
		print("  would hit the enemy %s" % ship.def.display_name)
	print("")

	# --- Turn flow ---
	print("Turn flow:")
	print("  Turn %d, Player %d. Can fire? %s" % [
		gs.turn_number, gs.current_player, gs.can_player_fire(gs.current_player)])
	gs.has_moved = true
	gs.has_fired = true
	print("  (moved a ship, fired a ship) -> ending turn")
	gs.end_turn()
	print("  Now Turn %d, Player %d. Powerup turn? %s" % [
		gs.turn_number, gs.current_player, gs.is_powerup_turn()])
	print("")

	# --- Emergency-shot rule ---
	for ship in gs.own_board(0).ships:
		ship.reload_cooldown = 2   # force all of Player 0's ships onto cooldown
	var emergency := AbilityRegistry.get_ability(&"emergency_shot")
	print("Emergency-shot check (all Player 0 ships reloading):")
	print("  Player 0 needs emergency shot? %s" % gs.needs_emergency_shot(0))
	print("  -> %s: %s" % [emergency.display_name, emergency.describe()])

	# --- Combat: Player 0 fires at the ENEMY board; per-cell damage, sinking, win ---
	print("\n=== COMBAT / DAMAGE DEMO ===")
	var g2 := GameState.new()
	_add(g2, &"destroyer", 0, Vector2i(1, 15), GameEnums.Facing.NORTH)   # P0 fleet (keeps P0 alive)
	_add(g2, &"drone_ship", 1, Vector2i(15, 1), GameEnums.Facing.NORTH)  # P1 fleet (the targets)
	_add(g2, &"cruiser", 1, Vector2i(5, 5), GameEnums.Facing.NORTH)
	g2.begin_turn()
	var drone := g2.boards[1].ships[0]
	var cruiser := g2.boards[1].ships[1]
	print("Start — enemy Drone HP %d, enemy Cruiser HP %d, winner %d" % [drone.hp(), cruiser.hp(), g2.winner()])

	var ms := AbilityRegistry.get_ability(&"multi_shot")
	print("P0 Multi-Shot at the enemy Drone's cells -> %s" % _fire(g2, ms, 0, drone.cells()))
	print("  Enemy Drone alive? %s" % drone.is_alive())

	var ss := AbilityRegistry.get_ability(&"single_shot")
	print("P0 Single Shot at one enemy Cruiser cell -> %s" % _fire(g2, ss, 0, [cruiser.cells()[0]]))
	print("  Enemy Cruiser HP now %d/%d (one cell blown off)" % [cruiser.hp(), cruiser.def.max_health])

	var radar := AbilityRegistry.get_ability(&"active_radar")
	var rc := ActionContext.new()
	rc.state = g2
	rc.board = g2.enemy_board(0)
	rc.acting_player = 0
	rc.sector = Sectors.sector_of(Vector2i(5, 5))
	print("P0 %s" % radar.execute(rc).info)

	print("P0 finishes the enemy Cruiser -> %s" % _fire(g2, ms, 0, cruiser.cells()))
	print("  Winner: Player %d  (-1 = ongoing)" % g2.winner())

	# --- Torpedo: hits the FIRST UNSTRUCK cell, passes through already-damaged ones ---
	print("\n=== TORPEDO VERIFICATION (range 5) ===")
	var g3 := GameState.new()
	_add(g3, &"submarine", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)   # keep P0 'alive'
	_add(g3, &"destroyer", 1, Vector2i(5, 5), GameEnums.Facing.NORTH)   # enemy hull: (5,5)(5,6)(5,7)(5,8)
	g3.begin_turn()
	var hull := g3.boards[1].ships[0]
	var torp := AbilityRegistry.get_ability(&"torpedo")
	print("Enemy Destroyer hull: %s (HP %d)" % [hull.cells(), hull.hp()])
	for shot in 3:
		var tc := ActionContext.new()
		tc.state = g3
		tc.board = g3.enemy_board(0)
		tc.acting_player = 0
		tc.line_start = Vector2i(5, 5)   # aim at the SAME tip each time
		tc.line_dir = Vector2i(0, 1)     # drag south down the hull
		var tr := torp.execute(tc)
		print("Torpedo #%d aimed at tip (5,5) -> hit %s | Destroyer HP %d | stunned %d turn(s)" % [
			shot + 1, str(tr.hits), hull.hp(), hull.stunned_turns])

	# --- Movement: spend points one at a time; translate by ceil(length/2); rotate on pivot ---
	print("\n=== MOVEMENT DEMO ===")
	var g4 := GameState.new()
	_add(g4, &"destroyer", 0, Vector2i(10, 10), GameEnums.Facing.NORTH)  # FAST, length 4
	g4.begin_turn()
	var d := g4.boards[0].ships[0]
	g4.begin_move(d)
	print("Destroyer (FAST): %d move points, each translate = %d cells" % [
		g4.move_points_left, g4.move_step_distance(d)])
	print("  start: cells %s, pivot %s" % [d.cells(), d.pivot_board()])
	print("  translate forward: ok=%s -> cells %s (points left %d)" % [
		g4.try_translate(1), d.cells(), g4.move_points_left])
	print("  rotate 90°: ok=%s -> cells %s, pivot still %s (points left %d, first turn free)" % [
		g4.try_rotate(), d.cells(), d.pivot_board(), g4.move_points_left])
	print("  translate forward (now facing east): ok=%s -> cells %s (points left %d)" % [
		g4.try_translate(1), d.cells(), g4.move_points_left])

	var g5 := GameState.new()
	_add(g5, &"submarine", 0, Vector2i(5, 1), GameEnums.Facing.NORTH)
	g5.begin_turn()
	var sub := g5.boards[0].ships[0]
	g5.begin_move(sub)
	print("Off-board guard — Sub at top edge %s, translate forward (would leave board): ok=%s (expect false)" % [
		sub.cells(), g5.try_translate(1)])

	# --- Mines: immediate on placement, mid-move detonation, and timed expiry (plus-blast) ---
	print("\n=== MINES DEMO ===")
	var g6 := GameState.new()
	_add(g6, &"destroyer", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)
	_add(g6, &"cruiser", 1, Vector2i(10, 10), GameEnums.Facing.NORTH)  # plus hull, centre at (11,11)
	g6.begin_turn()
	var ml := AbilityRegistry.get_ability(&"mine_lay")
	var mc := ActionContext.new()
	mc.state = g6; mc.board = g6.enemy_board(0); mc.acting_player = 0; mc.point = Vector2i(10, 16)
	print("P0 lays a mine on empty (10,16): %s" % ml.execute(mc).message)
	var mc2 := ActionContext.new()
	mc2.state = g6; mc2.board = g6.enemy_board(0); mc2.acting_player = 0; mc2.point = Vector2i(11, 11)
	var cruiser_hp_before := g6.boards[1].ships[0].hp()
	var r6 := ml.execute(mc2)
	var cruiser_alive := not g6.boards[1].ships.is_empty()
	print("P0 lays a mine onto the cruiser's centre (11,11): %s (hits %d) — a + blast on the + hull's centre took all %d nodes; cruiser alive=%s" % [
		r6.message, r6.hits.size(), cruiser_hp_before, cruiser_alive])

	var g7 := GameState.new()
	_add(g7, &"destroyer", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)
	_add(g7, &"submarine", 1, Vector2i(10, 10), GameEnums.Facing.NORTH)  # hull (10,10)(10,11)(10,12)
	g7.boards[1].try_place_mine(0, Vector2i(10, 13), 3)                  # P0 mine below the sub
	g7.current_player = 1
	g7.begin_turn()
	var sub2 := g7.boards[1].ships[0]
	print("P1 Sub %s HP %d; a hidden mine sits at (10,13)" % [sub2.cells(), sub2.hp()])
	g7.begin_move(sub2)
	var moved := g7.try_translate(-1)   # slide backward (south) over the mine
	print("Sub slides south over the mine: ok=%s -> now %s, HP %d (blew mid-move, sub kept going)" % [
		moved, sub2.cells(), sub2.hp()])

	var g8 := GameState.new()
	_add(g8, &"destroyer", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)
	_add(g8, &"cruiser", 1, Vector2i(10, 10), GameEnums.Facing.NORTH)  # plus hull has a cell at (12,11)
	g8.boards[1].try_place_mine(0, Vector2i(13, 11), 1)                # adjacent (east of that cell), fuse 1
	var cru := g8.boards[1].ships[0]
	print("Timed mine — cruiser HP before expiry: %d" % cru.hp())
	g8.current_player = 1
	g8.begin_turn()   # P1's turn start -> mine fuse 1->0 -> plus-blast clips the adjacent cell
	print("After expiry at P1's turn start: cruiser HP %d (adjacent cell caught by the + blast)" % cru.hp())

	# --- Battleship's normal fire = plus formation ---
	print("\n=== BATTLESHIP PLUS-FIRE ===")
	var g9 := GameState.new()
	_add(g9, &"battleship", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)
	_add(g9, &"cruiser", 1, Vector2i(10, 10), GameEnums.Facing.NORTH)
	g9.begin_turn()
	var cs := AbilityRegistry.get_ability(&"cross_shot")
	var csx := ActionContext.new()
	csx.state = g9; csx.board = g9.enemy_board(0); csx.acting_player = 0; csx.point = Vector2i(11, 11)
	var csr := cs.execute(csx)
	print("Battleship plus-fire on the cruiser's centre (11,11): hits %d (+ fire perfectly overlaps the + hull)" % csr.hits.size())

	# --- Drones: live recon distance to the nearest enemy ship node ---
	print("\n=== DRONE RECON DEMO ===")
	var g10 := GameState.new()
	_add(g10, &"drone_ship", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)
	_add(g10, &"cruiser", 1, Vector2i(10, 10), GameEnums.Facing.NORTH)  # nodes incl (10,10) and (11,11)
	g10.begin_turn()
	var dd := AbilityRegistry.get_ability(&"deploy_drones")
	var dctx := ActionContext.new()
	dctx.state = g10; dctx.board = g10.enemy_board(0); dctx.acting_player = 0
	dctx.cells = [Vector2i(10, 5), Vector2i(11, 11)]   # one far, one sitting on a ship node
	print("P0 %s" % dd.execute(dctx).message)
	for r in g10.drone_readings(0):
		print("  drone at %s -> %d spaces from nearest enemy node" % [r.cell, r.distance])

	# --- Barrage Zone: 3 random plus-blasts at start & end of the victim's turn, for 3 turns ---
	print("\n=== BARRAGE ZONE DEMO ===")
	seed(20260627)
	var g11 := GameState.new()
	_add(g11, &"battleship", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)   # the caster
	_add(g11, &"aircraft_carrier", 1, Vector2i(5, 5), GameEnums.Facing.NORTH)   # enemy ship in sector B2
	g11.begin_turn()
	var bz := AbilityRegistry.get_ability(&"barrage_zone")
	var bctx := ActionContext.new()
	bctx.state = g11; bctx.board = g11.enemy_board(0); bctx.acting_player = 0
	bctx.acting_ship = g11.boards[0].ships[0]
	bctx.sector = Sectors.from_label("B2")
	print("P0 %s" % bz.execute(bctx).message)
	var carrier := g11.boards[1].ships[0]
	print("Enemy Carrier HP %d; barrage active." % carrier.hp())
	for i in 6:                       # 6 end_turns = 3 full victim (P1) turns
		g11.end_turn()
		if g11.current_player == 0:   # just finished one of P1's turns
			print("  after a P1 turn: Carrier HP %d, barrages still on P1 board: %d" % [
				carrier.hp(), g11.boards[1].effects.size()])

	# --- Barrage ends early if the casting Battleship is sunk ---
	print("\n=== BARRAGE ENDS-EARLY CHECK ===")
	var g12 := GameState.new()
	_add(g12, &"battleship", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)
	_add(g12, &"destroyer", 1, Vector2i(10, 10), GameEnums.Facing.NORTH)
	g12.begin_turn()
	var caster := g12.boards[0].ships[0]
	var b2ctx := ActionContext.new()
	b2ctx.state = g12; b2ctx.board = g12.enemy_board(0); b2ctx.acting_player = 0
	b2ctx.acting_ship = caster; b2ctx.sector = Sectors.from_label("C3")
	bz.execute(b2ctx)
	print("  barrage placed -> caster alive=%s, barrage done=%s" % [
		caster.is_alive(), g12.boards[1].effects[0].is_done()])
	g12.boards[0].apply_hits(caster.all_cells())   # sink the casting battleship
	print("  caster sunk      -> caster alive=%s, barrage done=%s (ends early)" % [
		caster.is_alive(), g12.boards[1].effects[0].is_done()])

	# --- Powerups: spawn every 4 turns (same type, different cells), collect by moving, mine sweep ---
	print("\n=== POWERUPS DEMO ===")
	var g14 := GameState.new()
	g14.rng.seed = 42
	_add(g14, &"destroyer", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)
	_add(g14, &"submarine", 1, Vector2i(0, 0), GameEnums.Facing.NORTH)
	g14.begin_turn()
	while g14.turn_number < 4:
		g14.end_turn()
	print("Reached turn %d -> powerups: P0 board %d, P1 board %d" % [
		g14.turn_number, g14.boards[0].powerups.size(), g14.boards[1].powerups.size()])
	if not g14.boards[0].powerups.is_empty() and not g14.boards[1].powerups.is_empty():
		var pa := g14.boards[0].powerups[0]
		var pb := g14.boards[1].powerups[0]
		print("  same type=%s (%s); different cells: P0 %s vs P1 %s" % [
			pa.kind == pb.kind, Powerup.kind_name(pa.kind), pa.cell, pb.cell])

	print("\n--- collect a Repair by moving onto it ---")
	var g13 := GameState.new()
	_add(g13, &"destroyer", 0, Vector2i(10, 10), GameEnums.Facing.NORTH)
	_add(g13, &"submarine", 1, Vector2i(0, 0), GameEnums.Facing.NORTH)
	g13.boards[0].apply_hits([Vector2i(10, 13)])   # knock a cell off the destroyer first
	g13.boards[0].powerups.append(Powerup.new(GameEnums.PowerupKind.REPAIR, Vector2i(10, 8)))
	g13.begin_turn()
	var d2 := g13.boards[0].ships[0]
	print("Destroyer HP %d; Repair powerup at (10,8)" % d2.hp())
	g13.begin_move(d2)
	g13.try_translate(1)   # slide forward (up) onto the powerup
	print("After moving onto Repair: Destroyer HP %d, powerups left %d" % [
		d2.hp(), g13.boards[0].powerups.size()])

	print("\n--- Mine Sweep: defuse a sector of your own board ---")
	var g15 := GameState.new()
	_add(g15, &"destroyer", 0, Vector2i(0, 0), GameEnums.Facing.NORTH)
	_add(g15, &"submarine", 1, Vector2i(0, 0), GameEnums.Facing.NORTH)
	g15.boards[0].try_place_mine(1, Vector2i(11, 11), 3)   # enemy hazards on P0's board, sector C3
	g15.boards[0].try_place_mine(1, Vector2i(12, 12), 3)
	g15.boards[0].add_effect(Drone.new(1, Vector2i(13, 13), 4))
	g15.mine_sweeps[0] = 1
	print("P0 board has %d hazards in C3; sweeping..." % g15.boards[0].effects.size())
	var swept_n := g15.use_mine_sweep(0, Sectors.from_label("C3"))
	print("  defused %d mines/drones, hazards left %d (no detonation)" % [swept_n, g15.boards[0].effects.size()])


## Place a ship on its owner's board.
static func _add(gs: GameState, ship_id: StringName, owner: int, origin: Vector2i, facing: GameEnums.Facing) -> void:
	var def := _def(ship_id)
	var inst := ShipInstance.create(def, owner, origin, facing)
	if not gs.boards[owner].place(inst):
		push_error("BoardDemo: failed to place %s at %s" % [ship_id, origin])

## Fire an ability at the ENEMY board and return a short outcome summary.
static func _fire(state: GameState, ability: Ability, player: int, cells: Array[Vector2i]) -> String:
	var ctx := ActionContext.new()
	ctx.state = state
	ctx.board = state.enemy_board(player)
	ctx.acting_player = player
	ctx.cells.assign(cells)
	var r := ability.execute(ctx)
	return "hits %d, sunk %d" % [r.hits.size(), r.sunk.size()]

static func _def(ship_id: StringName) -> ShipDef:
	for d in ShipCatalog.all():
		if d.id == ship_id:
			return d
	push_error("BoardDemo: unknown ship id %s" % ship_id)
	return null
