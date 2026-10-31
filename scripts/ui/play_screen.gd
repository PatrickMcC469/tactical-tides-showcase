## Phase A hot-seat screen: shows ONE board at a time with a button to flip between
## "My Fleet" (your ships, movement/defense) and "Enemy Waters" (where you aim — fogged for now).
## No turn interaction yet; this just proves the engine renders. Built programmatically.
extends Control

var gs: GameState
var board_view: BoardView
var title: Label
var flip_button: Button
var showing_own := true

func _ready() -> void:
	gs = _make_demo()
	_build_ui()
	_update_view()
	# Headless verification (can't see pixels there): dump the board as text, then exit.
	if DisplayServer.get_name() == "headless":
		print(_ascii(gs.boards[0]))
		get_tree().quit()

func _build_ui() -> void:
	title = Label.new()
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	board_view = BoardView.new()
	board_view.position = Vector2(20, 52)
	add_child(board_view)

	flip_button = Button.new()
	flip_button.position = Vector2(20, 52 + board_view.cell_size * Sectors.BOARD_SIZE + 14)
	flip_button.custom_minimum_size = Vector2(board_view.cell_size * Sectors.BOARD_SIZE, 44)
	flip_button.pressed.connect(_on_flip)
	add_child(flip_button)

func _on_flip() -> void:
	showing_own = not showing_own
	_update_view()

func _update_view() -> void:
	if showing_own:
		title.text = "MY FLEET"
		flip_button.text = "Flip to Enemy Waters  ▶"
		board_view.set_board(gs.boards[0], true)
	else:
		title.text = "ENEMY WATERS  (fog of war)"
		flip_button.text = "◀  Flip to My Fleet"
		board_view.set_board(gs.boards[1], false)

# --- demo setup ---

func _make_demo() -> GameState:
	var g := GameState.new()
	_place(g, &"battleship", 0, Vector2i(2, 2))
	_place(g, &"aircraft_carrier", 0, Vector2i(8, 2))
	_place(g, &"cruiser", 0, Vector2i(14, 6))
	_place(g, &"submarine", 0, Vector2i(4, 14))
	_place(g, &"destroyer", 0, Vector2i(10, 14))
	_place(g, &"drone_ship", 0, Vector2i(16, 15))
	_place(g, &"battleship", 1, Vector2i(3, 3))   # enemy fleet (hidden in UI)
	g.boards[0].powerups.append(Powerup.new(GameEnums.PowerupKind.REPAIR, Vector2i(12, 12)))
	return g

func _place(g: GameState, id: StringName, owner: int, origin: Vector2i) -> void:
	for d in ShipCatalog.all():
		if d.id == id:
			g.boards[owner].place(ShipInstance.create(d, owner, origin, GameEnums.Facing.NORTH))
			return

func _ascii(b: Board) -> String:
	var rows: Array[String] = []
	for y in Sectors.BOARD_SIZE:
		var row := ""
		for x in Sectors.BOARD_SIZE:
			var c := Vector2i(x, y)
			var ch := "."
			for ship in b.ships:
				if c in ship.cells():
					ch = ship.def.display_name.substr(0, 1)
					break
			if b.powerup_at(c) != null:
				ch = "*"
			row += ch
		rows.append(row)
	return "MY FLEET (ascii, '.'=water, letter=ship, '*'=powerup):\n" + "\n".join(rows)
