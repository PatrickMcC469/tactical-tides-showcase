## Server wallet (autoload `Wallet`). Reads the player's coin balance and claims the daily reward from
## their Supabase `profiles` row, authenticated with the account JWT. Server-authoritative: the client
## never mints coins — it reads the balance and calls the SECURITY DEFINER `claim_daily()` RPC, which
## decides + grants using the SERVER date (no clock-faking). Falls back gracefully when offline / signed
## out (returns -1 / {}), so callers keep working on the local Cosmetics placeholder.
extends Node

## The player's current server coin balance (RLS: own row only). -1 if unavailable.
func balance() -> int:
	var r: Variant = await _rest_get("/rest/v1/profiles?select=coins")
	if r is Array and not (r as Array).is_empty():
		return int((r as Array)[0].get("coins", 0))
	return -1

## Daily-reward status: {coins, streak, last_daily, claimable}. Empty {} if unavailable.
func daily_status() -> Dictionary:
	var r: Variant = await _rest_get("/rest/v1/profiles?select=coins,last_daily,daily_streak")
	if not (r is Array) or (r as Array).is_empty():
		return {}
	var p: Dictionary = (r as Array)[0]
	var last := str(p.get("last_daily", ""))
	return {
		"coins": int(p.get("coins", 0)),
		"streak": int(p.get("daily_streak", 0)),
		"last_daily": last,
		"claimable": last != _today(),
	}

## Claim today's reward (the server decides + grants). {ok, claimed, streak, reward, coins} or {}.
func claim_daily() -> Dictionary:
	var r: Variant = await _rest_post("/rest/v1/rpc/claim_daily", {})
	return r if r is Dictionary else {}

## Today's date (UTC) as yyyy-mm-dd — matches how Postgres serializes the `date` column.
func _today() -> String:
	return Time.get_date_string_from_system(true)

## Yesterday (UTC) — for the client-side "will my streak continue?" hint (the server is authoritative).
func yesterday() -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)

# --- REST plumbing (apikey + the player's Bearer token) ---

func _rest_get(path: String) -> Variant:
	return await _req(HTTPClient.METHOD_GET, path, null)

func _rest_post(path: String, body: Dictionary) -> Variant:
	return await _req(HTTPClient.METHOD_POST, path, body)

func _req(method: int, path: String, body: Variant) -> Variant:
	if not Auth.signed():
		return null
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray([
		"apikey: " + Auth.api_key(),
		"Authorization: Bearer " + Auth.access_token,
		"Content-Type: application/json",
	])
	var payload := JSON.stringify(body) if body != null else ""
	var err := http.request(Auth.api_url() + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return null
	var res: Array = await http.request_completed
	http.queue_free()
	var code := int(res[1])
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	if code < 200 or code >= 300:
		push_warning("Wallet %s -> HTTP %d" % [path, code])
		return null
	return JSON.parse_string(text) if text != "" else null
