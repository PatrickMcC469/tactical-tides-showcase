## Verifies the LIVE /admob-ssv rewarded-ad endpoint end to end. Needs:
##   $env:ADMOB_SSV_SECRET = "<the secret you put in Secret Manager / the AdMob URL>"   # secret
## Makes a throwaway account, calls the deployed endpoint the way AdMob would (secret + custom_data
## "<uid>:free_coins" + a transaction_id), then reads the account's OWN profile (RLS allows) to prove
## exactly FREE_COINS_REWARD (75) landed, and replays the SAME transaction to prove no double-credit.
## Also confirms a WRONG secret is rejected (no coins).
##   Godot --headless --path <proj> --script res://scripts/server/admob_ssv_test.gd
extends SceneTree

const SUPA := "https://YOUR_PROJECT.supabase.co"
const ANON := "sb_publishable_vdAlH5L7JlYYMigxFByz_A_90_de_tT"
const REFEREE := "https://tt-referee-707330193418.us-central1.run.app"
const REWARD := 75

func _init() -> void:
	_run()

func _run() -> void:
	var host := Node.new()
	get_root().add_child(host)
	await process_frame

	var secret := OS.get_environment("ADMOB_SSV_SECRET")
	if secret == "":
		print("FAIL: set $env:ADMOB_SSV_SECRET to the deployed secret first")
		quit(); return

	var acct := await _signup(host)
	if acct.get("id", "") == "" or acct.get("token", "") == "":
		print("FAIL: could not create test account")
		quit(); return
	var uid: String = acct.id
	var token: String = acct.token
	print("test account = ", uid)

	var txn := "test_%d" % int(Time.get_unix_time_from_system())
	var good := "%s/admob-ssv?s=%s&custom_data=%s&transaction_id=%s" % [
		REFEREE, secret.uri_encode(), (uid + ":free_coins").uri_encode(), txn]
	var bad := "%s/admob-ssv?s=%s&custom_data=%s&transaction_id=%s" % [
		REFEREE, "not-the-secret", (uid + ":free_coins").uri_encode(), "test_wrong_%d" % int(Time.get_unix_time_from_system())]

	# 1) wrong secret -> unauthorized, no coins
	await _http_get(host, bad, [])
	var c0 := await _coins(host, uid, token)
	print("after WRONG secret   coins = ", c0, "  (want 0)")

	# 2) real callback -> 75 coins
	await _http_get(host, good, [])
	var c1 := await _coins(host, uid, token)
	print("after real callback  coins = ", c1, "  (want 75)")

	# 3) replay same transaction -> still 75 (idempotent)
	await _http_get(host, good, [])
	var c2 := await _coins(host, uid, token)
	print("after replay         coins = ", c2, "  (want 75 — NOT 150)")

	var verdict := "PASS" if (c0 == 0 and c1 == REWARD and c2 == REWARD) else "FAIL"
	print(verdict)
	var f := FileAccess.open("res://scripts/server/_admob_result.txt", FileAccess.WRITE)   # GUI exe has no console; read this
	if f:
		f.store_string("c0=%d (want 0)  c1=%d (want 75)  c2=%d (want 75)  => %s" % [c0, c1, c2, verdict])
		f.close()
	quit()

func _signup(host: Node) -> Dictionary:
	var http := HTTPRequest.new()
	host.add_child(http)
	http.request(SUPA + "/auth/v1/signup",
		PackedStringArray(["apikey: " + ANON, "Content-Type: application/json"]),
		HTTPClient.METHOD_POST, "{}")
	var res: Array = await http.request_completed
	http.queue_free()
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if d is Dictionary and (d as Dictionary).has("access_token"):
		var u: Variant = (d as Dictionary).get("user", {})
		return {"id": (u as Dictionary).get("id", "") if u is Dictionary else "",
			"token": (d as Dictionary).get("access_token", "")}
	return {}

## Read this account's own coin balance (RLS policy profiles_read_own allows auth.uid() = id).
func _coins(host: Node, uid: String, token: String) -> int:
	var url := SUPA + "/rest/v1/profiles?id=eq." + uid + "&select=coins"
	var body := await _http_get(host, url, ["apikey: " + ANON, "Authorization: Bearer " + token])
	var d: Variant = JSON.parse_string(body)
	if d is Array and (d as Array).size() > 0:
		return int((d as Array)[0].get("coins", -1))
	return -1

func _http_get(host: Node, url: String, headers: Array) -> String:
	var http := HTTPRequest.new()
	host.add_child(http)
	http.request(url, PackedStringArray(headers), HTTPClient.METHOD_GET)
	var res: Array = await http.request_completed
	http.queue_free()
	return (res[3] as PackedByteArray).get_string_from_utf8()
