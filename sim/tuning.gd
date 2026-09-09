class_name Tuning
extends RefCounted
## Loader for data/tuning.json (CLAUDE.md Section 6: no magic numbers in
## gameplay code). Read values with dotted paths: Tuning.value("net.tick_hz").

const DEFAULT_PATH: String = "res://data/tuning.json"

static var _data: Dictionary = {}
static var _load_attempted: bool = false


## Returns false on failure. Entry points must check this and abort rather
## than run on: value_i/value_f coerce missing values to 0, which once made a
## server bind port 0 with 0 peers and still log "listening".
static func load_data(path: String = DEFAULT_PATH) -> bool:
	_load_attempted = true
	_data = {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		Log.error("tuning", "failed to read tuning file", {"path": path})
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		Log.error("tuning", "tuning file is not a JSON object", {"path": path})
		return false
	_data = parsed
	return true


static func is_loaded() -> bool:
	return not _data.is_empty()


static func value(dotted_path: String) -> Variant:
	# Lazy-load once for tools/tests; a failed load is not retried per call.
	if _data.is_empty() and not _load_attempted:
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
