## Autoload that carries the live match (the GameState with both placed fleets) across the
## scene change from placement to the battle screen.
extends Node

var state: GameState = null    # the local hot-seat match (both fleets)
var online: bool = false       # true when the battle screen should submit turns to the server
var match_id: String = ""      # the online match to play (when online)
var versus_next: String = ""   # scene the VERSUS reveal proceeds to (set before showing it)
var invite_code: String = ""   # shareable code shown on the invite screen after creating a match
var placement_mode: String = "hotseat"   # "hotseat" (dev) | "online_create" (host) | "online_join" (guest)
var versus_enemy_skins: Dictionary = {}   # opponent's equipped skins for the VERSUS enemy fleet
                                          # (ship_id -> skin_key); empty in hot-seat -> mirror yours
var versus_enemy_name: String = ""        # opponent's captain name shown on the VERSUS reveal
