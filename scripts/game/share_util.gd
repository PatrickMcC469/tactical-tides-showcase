## Cross-platform "share this text" helper. On mobile it opens the OS native share sheet via a
## bundled Godot Android/iOS share plugin (added at export time — e.g. in Codemagic — NOT part of
## this repo). Everywhere the plugin isn't present (editor, desktop, or before it's bundled) it
## falls back to copying to the clipboard so nothing breaks and the code stays testable.
##
## To wire the real share sheet: bundle a share plugin in the Android/iOS export and set SINGLETON
## below to its singleton name. Common Godot share plugins expose `shareText(title, subject, content)`
## or `share(content)`. This wrapper probes for either, so most plugins work without code changes.
class_name ShareUtil
extends RefCounted

## The plugin singleton name (set to match whatever share plugin you bundle at export).
const SINGLETON := "GodotShare"

## Open the OS share sheet with `text`. Returns true if the native sheet was invoked, false if it
## fell back to the clipboard (the caller can then show a "copied — paste it to your friend" toast).
static func share_text(text: String, subject: String = "Tactical Tides") -> bool:
	if Engine.has_singleton(SINGLETON):
		var s := Engine.get_singleton(SINGLETON)
		if s.has_method("shareText"):
			s.shareText(subject, subject, text)   # title, subject, content
			return true
		if s.has_method("share"):
			s.share(text)
			return true
	# Fallback: no plugin (editor / desktop / not-yet-bundled) — copy so it can be pasted anywhere.
	DisplayServer.clipboard_set(text)
	return false

## True when the native share sheet is actually available (a real device with the plugin bundled).
static func native_available() -> bool:
	return Engine.has_singleton(SINGLETON)
