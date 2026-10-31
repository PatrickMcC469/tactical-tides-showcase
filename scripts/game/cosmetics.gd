## LOCAL placeholder cosmetics wallet + ownership (coins, owned skins, active skin per ship).
##
## IMPORTANT: this is a stand-in so the shop UI is usable now. Per the project plan the REAL
## source of truth for currency + entitlements is the authoritative SERVER account (never trust
## the client). When that lands, this reads through to the server instead of a local save file.
extends Node

const SAVE_PATH := "user://cosmetics.save"
const START_COINS := 0   # players earn coins by winning (post-game reward wheel is the faucet)

var coins: int = START_COINS
var owned: Dictionary = {}           # purchased skin_key -> true (free skins aren't stored here)
var active: Dictionary = {}          # ship_id (String) -> skin_key

func _ready() -> void:
	_load()

func is_purchased(key: String) -> bool:
	return owned.has(key)

## Try to buy at the given price; returns false only when there aren't enough coins.
func buy(key: String, price: int) -> bool:
	if owned.has(key):
		return true
	if price > 0 and coins < price:
		return false
	coins -= price
	owned[key] = true
	_save()
	return true

## Buy a fleet bundle: charge `price` and grant every skin key in it. Returns false if too poor.
func buy_bundle(keys: Array, price: int) -> bool:
	if price > 0 and coins < price:
		return false
	coins -= price
	for k in keys:
		owned[k] = true
	_save()
	return true

## Add coins (post-game reward wheel, etc). LOCAL/testing faucet only — in the real economy the
## authoritative SERVER banks rewards to the account; the client never mints its own currency.
func add_coins(n: int) -> void:
	if n <= 0:
		return
	coins += n
	_save()

func active_skin(ship_id: String) -> String:
	return String(active.get(ship_id, ""))

## Set the active skin for a ship. Callers only equip skins the player owns (free or purchased).
func set_active(ship_id: String, key: String) -> void:
	active[ship_id] = key
	_save()

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"coins": coins, "owned": owned, "active": active}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	coins = int(d.get("coins", START_COINS))
	owned = d.get("owned", {})
	active = d.get("active", {})
