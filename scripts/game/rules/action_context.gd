## Everything an Ability.execute() needs to resolve itself against the match. The UI (and
## later the server) fills in whichever fields the chosen ability's target_kind requires.
class_name ActionContext
extends RefCounted

var state: GameState
var acting_player: int = 0
var acting_ship: ShipInstance = null    # the firing ship (optional; null for Emergency Shot)
## The board this action resolves against: the ENEMY board for attacks/scans, the player's
## OWN board for movement. The caller sets it (usually state.enemy_board(acting_player)).
var board: Board = null

# Targeting payload — only the relevant fields are used per ability:
var cells: Array[Vector2i] = []         # SINGLE/MULTI/LINE/CROSS volley cells
var point: Vector2i = Vector2i.ZERO     # a single point (Air Strafe centre, placement)
var sector: Vector2i = Vector2i.ZERO    # a 5x5 sector (Active Radar, Barrage Zone)
var line_start: Vector2i = Vector2i.ZERO  # Torpedo origin
var line_dir: Vector2i = Vector2i.ZERO    # Torpedo direction (unit vector)
