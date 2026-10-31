## Thin PostgREST client for Supabase, used by the SERVER (referee) only. The service-role key
## bypasses RLS so the referee can read/write the hidden match state; it is read from the
## SUPABASE_SERVICE_KEY environment variable and NEVER hardcoded or logged. The project URL is
## public (SUPABASE_URL env, or the baked default). HTTPRequest needs a Node in the tree, so pass
## a parent (the referee server node).
class_name SupabaseStore
extends RefCounted

const DEFAULT_URL := "https://YOUR_PROJECT.supabase.co"   # public project URL (safe)

var url: String
var _key: String
var _parent: Node

func _init(parent: Node) -> void:
	_parent = parent
	url = OS.get_environment("SUPABASE_URL")
	if url == "":
		url = DEFAULT_URL
	url = url.rstrip("/")
	_key = OS.get_environment("SUPABASE_SERVICE_KEY")   # secret — set in the environment only

## True once the service key is available (otherwise the referee falls back to in-memory storage).
func configured() -> bool:
	return _key != ""

## Insert one row; returns the inserted row (or null on error).
func insert(table: String, row: Dictionary) -> Variant:
	var rows: Variant = await _req(HTTPClient.METHOD_POST, "/" + table, row)
	if rows is Array and not (rows as Array).is_empty():
		return (rows as Array)[0]
	return null

## Select rows with a raw PostgREST query (e.g. "invite_code=eq.ABC123"). Returns an Array (maybe empty).
func select(table: String, query: String = "") -> Array:
	var q := ("?" + query) if query != "" else ""
	var rows: Variant = await _req(HTTPClient.METHOD_GET, "/" + table + q, null)
	return rows if rows is Array else []

## Patch rows matching the query. Returns the updated rows.
func update(table: String, query: String, patch: Dictionary) -> Array:
	var rows: Variant = await _req(HTTPClient.METHOD_PATCH, "/" + table + "?" + query, patch)
	return rows if rows is Array else []

## Bump a numeric column by calling a Postgres RPC (atomic increment; see schema.sql add_coins()).
func rpc(fn: String, args: Dictionary) -> Variant:
	return await _req(HTTPClient.METHOD_POST, "/rpc/" + fn, args)

## Validate a user access token by asking GoTrue who it belongs to. Returns the account's uuid, or
## "" if the token is missing/invalid/expired. Lets the referee prove a caller owns an account before
## merging profiles (so nobody can transfer a stranger's coins). Hits /auth/v1, not /rest/v1.
func verify_user(token: String) -> String:
	if token == "" or _key == "":
		return ""
	var http := HTTPRequest.new()
	_parent.add_child(http)
	var headers := PackedStringArray([
		"apikey: " + _key,
		"Authorization: Bearer " + token,
	])
	var err := http.request(url + "/auth/v1/user", headers, HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return ""
	var res: Array = await http.request_completed   # [result, code, headers, body]
	http.queue_free()
	if int(res[1]) != 200:
		return ""
	var body: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return str(body.get("id", "")) if body is Dictionary else ""

func _req(method: int, path: String, body: Variant) -> Variant:
	if _key == "":
		return null
	var http := HTTPRequest.new()
	_parent.add_child(http)
	var headers := PackedStringArray([
		"apikey: " + _key,
		"Authorization: Bearer " + _key,
		"Content-Type: application/json",
		"Prefer: return=representation",
	])
	var payload := JSON.stringify(body) if body != null else ""
	var err := http.request(url + "/rest/v1" + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		push_warning("supabase: request could not start (%d)" % err)
		return null
	var res: Array = await http.request_completed   # [result, code, headers, body]
	http.queue_free()
	var code := int(res[1])
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	if code < 200 or code >= 300:
		push_warning("supabase %s %s -> HTTP %d" % [method, path, code])   # body may contain data; don't log it
		return null
	if text == "":
		return []
	return JSON.parse_string(text)
