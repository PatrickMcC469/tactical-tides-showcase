## Minimal HTTP server that exposes the authoritative referee over the network. It wraps the same
## LocalServer logic the game already uses, so every request is validated by the rules brain and
## the enemy fleet is never returned. Run headless:
##   Godot_v4.6-stable_win64.exe --headless --path <proj> server/referee_server.tscn
##
## Endpoints (all POST, JSON body): /create /join /submit /view /matches, plus GET /health.
## Storage is in-memory for local play/testing; the Cloud Run build swaps LocalServer's store for
## Supabase Postgres (same endpoints, same shapes).
extends Node

const DEFAULT_PORT := 8787
const NAME_MAX := 24                 # server-side cap on captain names (client caps at 20)
const RATE_MAX := 120                # max requests per session token per window (runaway/abuse guard)
const RATE_WINDOW := 60.0            # seconds
const FREE_COINS_REWARD := 75        # coins for watching a "free coins" rewarded ad (server-decided)

var _server := TCPServer.new()
var _store: Variant                 # SupabaseServer (persistent) or LocalServer (in-memory)
var _persistent := false
var _re_mid := RegEx.new()          # ^m_<digits>_<digits>$ — valid Supabase match ids
var _re_code := RegEx.new()         # ^[A-Z0-9]{6}$ — valid invite codes
var _rate := {}                     # session token -> {n, t0}: fixed-window request counter

func _ready() -> void:
	_re_mid.compile("^m_[0-9]+_[0-9]+$")
	_re_code.compile("^[A-Z0-9]{6}$")
	var sb := SupabaseServer.new(self)
	if sb.configured():
		_store = sb
		_persistent = true
		print("Referee: Supabase persistence ENABLED")
	else:
		_store = LocalServer.new()
		print("Referee: in-memory storage (set SUPABASE_SERVICE_KEY to persist)")
	# Cloud Run (and most PaaS) inject the port to bind via $PORT; fall back to DEFAULT_PORT locally.
	var port := int(OS.get_environment("PORT")) if OS.get_environment("PORT") != "" else DEFAULT_PORT
	var err := _server.listen(port, "0.0.0.0")   # bind all interfaces so the container is reachable
	if err != OK:
		push_error("referee: could not listen on %d (err %d)" % [port, err])
		return
	print("Referee listening on 0.0.0.0:%d" % port)

func _process(_dt: float) -> void:
	while _server.is_connection_available():
		_handle(_server.take_connection())

func _handle(peer: StreamPeerTCP) -> void:
	var req := _read_request(peer)
	var body := {}
	if req.get("body", "") != "":
		var parsed: Variant = JSON.parse_string(req.body)
		if typeof(parsed) == TYPE_DICTIONARY:
			body = parsed
	var resp: Dictionary = await _route(String(req.get("path", "/")), body, String(req.get("auth_token", "")))
	_write_json(peer, resp)
	peer.disconnect_from_host()

## Same shapes either way; the Supabase backend is async (await), the in-memory one is synchronous.
func _route(path: String, b: Dictionary, auth_token: String) -> Dictionary:
	# AdMob SSV is a GET with params in the URL — split any query string off the path.
	var query := {}
	var qi := path.find("?")
	if qi != -1:
		query = _parse_query(path.substr(qi + 1))
		path = path.substr(0, qi)
	if path == "/health":
		return {"ok": true, "persistent": _persistent}
	if path == "/admob-ssv":
		return await _admob_ssv(query)                     # rewarded-ad reward -> credit coins
	if path == "/rc-webhook":
		return await _revenuecat_webhook(auth_token, b)   # RevenueCat purchase -> credit coins
	# Rate limit per session token FIRST (before the JWT check, so it also caps the GoTrue verify
	# calls) — a runaway client or abuse can't rack up compute/DB cost.
	if not _rate_ok(auth_token):
		return {"ok": false, "reason": "slow down — too many requests"}
	# Identity: on the persistent (production) backend, the player is whoever the JWT says they are —
	# never the client-supplied body field. That stops a caller acting as another account. /merge does
	# its own two-token verification, so it's exempt here. In-memory dev trusts the body for convenience.
	var pid := String(b.get("player_id", ""))
	if _persistent and path != "/merge":
		pid = await _store.verify_token(auth_token)
		if pid == "":
			return {"ok": false, "reason": "unauthorized"}
	# Sanitize client-supplied inputs before they reach any query. Cap the captain name (a hacked
	# client could send a huge string), and on the production/PostgREST path reject malformed ids/codes
	# so a crafted value can't manipulate a REST filter. (In-memory dev uses dict keys — no such risk.)
	var mid := String(b.get("match_id", ""))
	var code := String(b.get("code", "")).strip_edges().to_upper()
	var name := String(b.get("name", "")).strip_edges().substr(0, NAME_MAX)
	if _persistent:
		if mid != "" and not _re_mid.search(mid):
			return {"ok": false, "reason": "invalid match id"}
		if path == "/join" and not _re_code.search(code):
			return {"ok": false, "reason": "invalid code"}
	match path:
		"/create":
			if _persistent: return await _store.create_match(pid, b.get("skins", {}), b.get("ships", []), name)
			return _store.create_match(pid, b.get("skins", {}), b.get("ships", []), name)
		"/place":
			if _persistent: return await _store.submit_placement(mid, pid, b.get("ships", []))
			return _store.submit_placement(mid, pid, b.get("ships", []))
		"/join":
			if _persistent: return await _store.join_match(code, pid, b.get("skins", {}), name)
			return _store.join_match(code, pid, b.get("skins", {}), name)
		"/submit":
			if _persistent: return await _store.submit_turn(mid, pid, b.get("turn", {}))
			return _store.submit_turn(mid, pid, b.get("turn", {}))
		"/view":
			if _persistent: return await _store.get_view(mid, pid)
			return _store.get_view(mid, pid)
		"/matches":
			if _persistent: return {"matches": await _store.list_matches(pid)}
			return {"matches": _store.list_matches(pid)}
		"/merge":
			# Carry a guest account's wallet into the player's new Google account. Both tokens are
			# verified server-side (SupabaseServer) so a caller can only merge accounts they own.
			var dst := String(b.get("dest_token", ""))
			var src := String(b.get("src_token", ""))
			if _persistent: return await _store.merge_accounts(dst, src)
			return _store.merge_accounts(dst, src)
	return {"ok": false, "reason": "unknown path '%s'" % path}

## Parse a URL query string into a Dictionary (values uri-decoded).
func _parse_query(q: String) -> Dictionary:
	var out := {}
	for pair in q.split("&"):
		if pair == "":
			continue
		var kv := pair.split("=", true, 1)
		out[kv[0]] = kv[1].uri_decode() if kv.size() == 2 else ""
	return out

## AdMob rewarded-ad Server-Side Verification. AdMob calls this (GET) only after a REAL ad completes,
## so the client can't fake it. We authenticate with a secret query param baked into the SSV URL (only
## AdMob has it), read the player + purpose from custom_data, and credit a SERVER-decided amount
## (custom_data amounts are never trusted). Idempotent by AdMob's transaction id.
func _admob_ssv(q: Dictionary) -> Dictionary:
	var expected := OS.get_environment("ADMOB_SSV_SECRET")
	if expected == "" or String(q.get("s", "")) != expected:
		return {"ok": false, "reason": "unauthorized"}
	if not _persistent:
		return {"ok": true}
	# custom_data = "<player-uuid>:<purpose>" (set by the client when requesting the ad).
	var parts := String(q.get("custom_data", "")).split(":")
	var uid := String(parts[0]) if parts.size() > 0 else ""
	var purpose := String(parts[1]) if parts.size() > 1 else ""
	var txn := String(q.get("transaction_id", ""))
	if uid == "" or txn == "":
		return {"ok": true}
	var coins := 0
	match purpose:
		"free_coins":
			coins = FREE_COINS_REWARD
		# "double_spin" / "spin_again" come later — they need the match's server-side spin amount.
	if coins <= 0:
		return {"ok": true}
	await _store.grant_purchase("admob_" + txn, uid, coins)   # reuse the idempotent credit path
	return {"ok": true}

## RevenueCat purchase webhook. RevenueCat has ALREADY validated the receipt with Apple/Google, so we
## only verify the shared secret it sends, map the product to coins, and credit them idempotently.
func _revenuecat_webhook(secret: String, b: Dictionary) -> Dictionary:
	var expected := OS.get_environment("RC_WEBHOOK_SECRET")
	if expected == "" or secret != expected:
		return {"ok": false, "reason": "unauthorized"}
	if not _persistent:
		return {"ok": true}   # dev/in-memory: no wallet to credit
	var ev: Dictionary = b.get("event", {})
	var etype := String(ev.get("type", ""))
	# Consumables arrive as NON_RENEWING_PURCHASE (INITIAL_PURCHASE as a safety net); ignore the rest.
	if etype != "NON_RENEWING_PURCHASE" and etype != "INITIAL_PURCHASE":
		return {"ok": true}
	var uid := String(ev.get("app_user_id", ""))                       # = the player's Supabase uuid
	var product := String(ev.get("product_id", ""))
	var txn := String(ev.get("transaction_id", ev.get("id", "")))      # idempotency key
	var coins := CoinProducts.coins_for(product)
	if uid == "" or txn == "" or coins <= 0:
		return {"ok": true}   # unknown product / missing ids -> grant nothing
	await _store.grant_purchase(txn, uid, coins)
	return {"ok": true}

## Fixed-window rate limit per session token. Returns false once a token exceeds RATE_MAX requests in
## RATE_WINDOW seconds. In-memory per instance (fine as a cost guard; Cloud Run caps instances anyway).
func _rate_ok(key: String) -> bool:
	if key == "":
		return true   # unauthenticated (/health handled earlier) — nothing to meter
	var now := float(Time.get_ticks_msec()) / 1000.0
	if _rate.size() > 4000:                              # opportunistic prune of stale windows
		for k in _rate.keys():
			if now - _rate[k].t0 >= RATE_WINDOW:
				_rate.erase(k)
	var e: Dictionary = _rate.get(key, {"n": 0, "t0": now})
	if now - e.t0 >= RATE_WINDOW:
		e = {"n": 0, "t0": now}                          # window rolled over
	e.n += 1
	_rate[key] = e
	return e.n <= RATE_MAX

## Read a full HTTP request (headers + Content-Length body) with a short timeout.
func _read_request(peer: StreamPeerTCP) -> Dictionary:
	var raw := PackedByteArray()
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var avail := peer.get_available_bytes()
		if avail > 0:
			var got := peer.get_data(avail)
			if got[0] == OK:
				raw.append_array(got[1])
			var text := raw.get_string_from_utf8()
			var he := text.find("\r\n\r\n")
			if he != -1:
				var clen := _content_length(text.substr(0, he))
				if text.length() - (he + 4) >= clen:
					break
		else:
			OS.delay_msec(2)
	var full := raw.get_string_from_utf8()
	var hend := full.find("\r\n\r\n")
	if hend == -1:
		return {}
	var line := full.substr(0, full.find("\r\n")).split(" ")
	# Pull the bearer token out of the Authorization header (identity is derived from it, not the body).
	var auth_token := ""
	for h in full.substr(0, hend).split("\r\n"):
		if h.to_lower().begins_with("authorization:"):
			auth_token = h.substr(h.find(":") + 1).strip_edges()
			if auth_token.to_lower().begins_with("bearer "):
				auth_token = auth_token.substr(7)
	return {
		"method": line[0] if line.size() > 0 else "",
		"path": line[1] if line.size() > 1 else "/",
		"body": full.substr(hend + 4),
		"auth_token": auth_token,
	}

func _content_length(headers: String) -> int:
	for h in headers.split("\r\n"):
		if h.to_lower().begins_with("content-length:"):
			return int(h.split(":")[1].strip_edges())
	return 0

func _write_json(peer: StreamPeerTCP, dict: Dictionary) -> void:
	var body := JSON.stringify(dict).to_utf8_buffer()
	var head := ("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" +
		"Access-Control-Allow-Origin: *\r\nContent-Length: %d\r\nConnection: close\r\n\r\n") % body.size()
	peer.put_data(head.to_utf8_buffer())
	peer.put_data(body)
