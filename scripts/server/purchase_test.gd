## Verifies the IAP coin grant end to end (the DB core the webhook calls). Needs:
##   $env:SUPABASE_SERVICE_KEY = "<service key>"    # secret
##   (schema.sql must be run so grant_purchase + processed_purchases exist)
## Makes a throwaway account, grants a coins_500 purchase, then grants the SAME transaction again to
## prove a retry does NOT double-credit.
##   Godot --headless --path <proj> --script res://scripts/server/purchase_test.gd
extends SceneTree

const URL := "https://YOUR_PROJECT.supabase.co"
const ANON := "sb_publishable_vdAlH5L7JlYYMigxFByz_A_90_de_tT"

func _init() -> void:
	_run()

func _run() -> void:
	var host := Node.new()
	get_root().add_child(host)
	await process_frame
	var store := SupabaseStore.new(host)
	if not store.configured():
		print("FAIL: set SUPABASE_SERVICE_KEY first")
		quit(); return
	var acct := await _signup(host)
	if acct.id == "":
		print("FAIL: could not create test account")
		quit(); return
	print("test account = ", acct.id)

	var coins := CoinProducts.coins_for("coins_500")   # 500
	var txn := "test_txn_%d" % int(Time.get_unix_time_from_system())

	await store.rpc("grant_purchase", {"p_txn": txn, "p_uid": acct.id, "p_coins": coins})
	var b1 := await store.select("profiles", "id=eq." + acct.id)
	var c1 := int(b1[0].get("coins", -1)) if b1.size() > 0 else -1
	print("after 1st grant  coins = ", c1, "  (want 500)")

	await store.rpc("grant_purchase", {"p_txn": txn, "p_uid": acct.id, "p_coins": coins})   # retry
	var b2 := await store.select("profiles", "id=eq." + acct.id)
	var c2 := int(b2[0].get("coins", -1)) if b2.size() > 0 else -1
	print("after retry      coins = ", c2, "  (want 500 — NOT 1000)")

	print("PASS" if (c1 == 500 and c2 == 500) else "FAIL")
	quit()

func _signup(host: Node) -> Dictionary:
	var http := HTTPRequest.new()
	host.add_child(http)
	http.request(URL + "/auth/v1/signup",
		PackedStringArray(["apikey: " + ANON, "Content-Type: application/json"]),
		HTTPClient.METHOD_POST, "{}")
	var res: Array = await http.request_completed
	http.queue_free()
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if d is Dictionary and (d as Dictionary).has("access_token"):
		var u: Variant = (d as Dictionary).get("user", {})
		return {"id": (u as Dictionary).get("id", "") if u is Dictionary else ""}
	return {"id": ""}
