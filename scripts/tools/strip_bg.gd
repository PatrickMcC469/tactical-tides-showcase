## One-off tool: make the baked light-gray background of the sprite art transparent.
## Flood-fills from the image edges (so light pixels INSIDE a ship are kept) and writes the PNG
## back in place. Run: godot --headless --path <proj> --script res://scripts/tools/strip_bg.gd
extends SceneTree

const FOLDERS := [
	"res://assests/ships", "res://assests/mines", "res://assests/drones", "res://assests/bomber",
]
const TOL := 34   # per-channel closeness (0-255) to the corner color counted as background

func _initialize() -> void:
	var files: Array[String] = []
	for f in FOLDERS:
		_collect(f, files)
	var done := 0
	for path in files:
		if _strip(path):
			done += 1
	print("strip_bg: processed %d / %d PNGs" % [done, files.size()])
	quit()

func _collect(dir: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var n := da.get_next()
	while n != "":
		var p := dir + "/" + n
		if da.current_is_dir():
			_collect(p, out)
		elif n.to_lower().ends_with(".png"):
			out.append(p)
		n = da.get_next()
	da.list_dir_end()

func _strip(res_path: String) -> bool:
	var abs_path := ProjectSettings.globalize_path(res_path)
	var img := Image.load_from_file(abs_path)
	if img == null:
		return false
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	if data[3] < 200:
		return false   # corner already transparent -> nothing to do
	var br := data[0]; var bgc := data[1]; var bb := data[2]
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + (w - 1))
	while stack.size() > 0:
		var idx := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if idx < 0 or idx >= w * h or visited[idx] != 0:
			continue
		visited[idx] = 1
		var o := idx * 4
		if abs(data[o] - br) <= TOL and abs(data[o + 1] - bgc) <= TOL and abs(data[o + 2] - bb) <= TOL:
			data[o + 3] = 0
			var x := idx % w
			var y := idx / w
			if x > 0: stack.append(idx - 1)
			if x < w - 1: stack.append(idx + 1)
			if y > 0: stack.append(idx - w)
			if y < h - 1: stack.append(idx + w)
	var outimg := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	outimg.save_png(abs_path)
	return true
