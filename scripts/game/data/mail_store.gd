## Local persistence for mailroom state (user://mail.cfg), keyed by message id: which messages the
## player has read or deleted, remembered across sessions. The mail seeds are static for now; when
## real server mail lands, this same read/deleted bookkeeping carries over.
class_name MailStore

const PATH := "user://mail.cfg"

static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)   # a missing file just yields an empty config
	return c

static func is_deleted(id: String) -> bool:
	return bool(_cfg().get_value("deleted", id, false))

static func is_read(id: String) -> bool:
	return bool(_cfg().get_value("read", id, false))

static func mark_read(id: String) -> void:
	var c := _cfg()
	c.set_value("read", id, true)
	c.save(PATH)

static func mark_deleted(id: String) -> void:
	var c := _cfg()
	c.set_value("deleted", id, true)
	c.save(PATH)

## How many of the given message ids are neither read nor deleted (for a future menu unread badge).
static func unread_count(ids: Array) -> int:
	var c := _cfg()
	var n := 0
	for id in ids:
		if not bool(c.get_value("deleted", id, false)) and not bool(c.get_value("read", id, false)):
			n += 1
	return n
