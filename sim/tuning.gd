class_name Tuning
extends RefCounted
## Loader for data/tuning.json (CLAUDE.md Section 6: no magic numbers in
## gameplay code). Read values with dotted paths: Tuning.value("net.tick_hz").

const DEFAULT_PATH: String = "res://data/tuning.json"

static var _data: Dictionary = {}


static func load_data(path: String = DEFAULT_PATH) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		Log.error("tuning", "failed to read tuning file", {"path": path})
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
	else:
		Log.error("tuning", "tuning file is not a JSON object", {"path": path})


static func value(dotted_path: String) -> Variant:
	if _data.is_empty():
		load_data()
	var node: Variant = _data
	for key: String in dotted_path.split("."):
		if node is Dictionary and (node as Dictionary).has(key):
			node = (node as Dictionary)[key]
		else:
			Log.error("tuning", "unknown tuning path", {"path": dotted_path})
			return null
	return node


static func value_f(dotted_path: String) -> float:
	return float(value(dotted_path))


static func value_i(dotted_path: String) -> int:
	return int(value(dotted_path))
