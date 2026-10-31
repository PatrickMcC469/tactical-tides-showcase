## Live test for the guest->Google wallet merge. Needs BOTH keys set:
##   $env:SUPABASE_SERVICE_KEY = "<service key>"    # secret — server role
##   (the publishable/anon key is baked in below)
## Run FIRST-time only after re-running docs/supabase/schema.sql (adds merge_profiles()).
##   Godot --headless --path <proj> --script res://scripts/server/merge_test.gd
## It makes two throwaway anonymous accounts, gives the SOURCE 250 coins, merges SOURCE->DEST via
## SupabaseServer.merge_accounts (which verifies both tokens), then prints the resulting balances.
## Expect: merge = {ok:true, merged:true}, dest coins = 250, src coins = 0.
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
		print("FAIL: set SUPABASE_SERVICE_KEY in the environment first")
		quit(); return

	var src := await _signup(host)
	var dest := await _signup(host)
	if src.id == "" or dest.id == "":
		print("FAIL: could not create the two test accounts")
		quit(); return
	print("src  = ", src.id)
	print("dest = ", dest.id)

	await store.rpc("add_coins", {"uid": src.id, "amount": 250})   # give the guest a balance to carry

	var srv := SupabaseServer.new(host)
	var res: Dictionary = await srv.merge_accounts(dest.token, src.token)
	print("merge = ", res)

	var pa := await store.select("profiles", "id=eq." + src.id)
	var pb := await store.select("profiles", "id=eq." + dest.id)
	print("src  coins after = ", int(pa[0].get("coins", -1)) if pa.size() > 0 else "?")
	print("dest coins after = ", int(pb[0].get("coins", -1)) if pb.size() > 0 else "?")
	print("PASS" if (res.get("merged") == true and pb.size() > 0 and int(pb[0].coins) == 250) else "CHECK ABOVE")
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
		return {"token": d["access_token"], "id": (u as Dictionary).get("id", "") if u is Dictionary else ""}
	return {"token": "", "id": ""}
