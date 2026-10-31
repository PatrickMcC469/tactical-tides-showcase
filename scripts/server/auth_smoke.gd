## Headless smoke test for the Auth autoload. Run:
##   Godot --headless --script res://scripts/server/auth_smoke.gd
## Without SUPABASE_ANON_KEY it just proves the script compiles and configured()==false.
## With SUPABASE_ANON_KEY set (and "Allow anonymous sign-ins" enabled in Supabase) it performs a
## real anonymous sign-in and prints the account UUID + token length (never the token itself).
extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	var a: Node = load("res://scripts/game/auth.gd").new()
	get_root().add_child(a)
	await process_frame
	print("configured = ", a.configured())
	if a.configured():
		var ok: bool = await a.sign_in_anonymous()
		print("anon sign-in ok = ", ok)
		print("user_id = ", a.user_id)
		print("is_anonymous = ", a.is_anonymous)
		print("access_token length = ", a.access_token.length())
		print("signed() = ", a.signed())
	else:
		print("(set SUPABASE_ANON_KEY to run a live anonymous sign-in)")
	quit()
