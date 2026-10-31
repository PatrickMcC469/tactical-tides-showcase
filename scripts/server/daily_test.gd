## Verifies the daily-reward RPC end to end against LIVE Supabase. No secrets needed — it uses a
## throwaway account's own JWT (claim_daily is granted to `authenticated` and acts on auth.uid()).
## Proves: first claim grants day-1 (25) with streak 1; a SECOND claim the same day is rejected
## (claimed=false); the profile balance ends at exactly 25.
##   Godot --headless --path <proj> --script res://scripts/server/daily_test.gd
extends SceneTree

const SUPA := "https://YOUR_PROJECT.supabase.co"
const ANON := "sb_publishable_vdAlH5L7JlYYMigxFByz_A_90_de_tT"

func _init() -> void:
	_run()

func _run() -> void:
	var host := Node.new()
	get_root().add_child(host)
	await process_frame

	var acct := await _signup(host)
	if acct.get("id", "") == "" or acct.get("token", "") == "":
		print("FAIL: could not create test account"); quit(); return
	var uid: String = acct.id
	var token: String = acct.token
	print("test account = ", uid)

	var r1 := await _rpc(host, token)
	print("1st claim: ", r1)
	var r2 := await _rpc(host, token)          # same day again
	print("2nd claim: ", r2)
	var coins := await _coins(host, uid, token)
	print("balance after = ", coins, "  (want 25)")

	var ok := (bool(r1.get("claimed", false)) and int(r1.get("reward", -1)) == 25
		and int(r1.get("streak", -1)) == 1 and int(r1.get("coins", -1)) == 25
		and bool(r2.get("claimed", true)) == false and coins == 25)
	var verdict := "PASS" if ok else "FAIL"
	print(verdict)
	var f := FileAccess.open("res://scripts/server/_daily_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("r1=%s\nr2=%s\nbalance=%d\n=> %s" % [str(r1), str(r2), coins, verdict]); f.close()
	quit()

func _signup(host: Node) -> Dictionary:
	var body := await _http(host, HTTPClient.METHOD_POST, SUPA + "/auth/v1/signup",
		["apikey: " + ANON, "Content-Type: application/json"], "{}")
	var d: Variant = JSON.parse_string(body)
	if d is Dictionary and (d as Dictionary).has("access_token"):
		var u: Variant = (d as Dictionary).get("user", {})
		return {"id": (u as Dictionary).get("id", "") if u is Dictionary else "",
			"token": (d as Dictionary).get("access_token", "")}
	return {}

func _rpc(host: Node, token: String) -> Dictionary:
	var body := await _http(host, HTTPClient.METHOD_POST, SUPA + "/rest/v1/rpc/claim_daily",
		["apikey: " + ANON, "Authorization: Bearer " + token, "Content-Type: application/json"], "{}")
	var d: Variant = JSON.parse_string(body)
	return d if d is Dictionary else {}

func _coins(host: Node, uid: String, token: String) -> int:
	var body := await _http(host, HTTPClient.METHOD_GET,
		SUPA + "/rest/v1/profiles?id=eq." + uid + "&select=coins",
		["apikey: " + ANON, "Authorization: Bearer " + token], "")
	var d: Variant = JSON.parse_string(body)
	if d is Array and (d as Array).size() > 0:
		return int((d as Array)[0].get("coins", -1))
	return -1

func _http(host: Node, method: int, url: String, headers: Array, payload: String) -> String:
	var http := HTTPRequest.new()
	host.add_child(http)
	http.request(url, PackedStringArray(headers), method, payload)
	var res: Array = await http.request_completed
	http.queue_free()
	return (res[3] as PackedByteArray).get_string_from_utf8()
