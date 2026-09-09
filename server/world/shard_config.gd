class_name ShardConfig
extends RefCounted
## Loader for data/shard.json (wiki/Architecture.md "Shard configuration").
## Gameplay code reads the values and never branches on the mode name
## (CLAUDE.md Section 5). Returns null on any problem so entry points abort
## instead of running on zeroed config.

const DEFAULT_PATH: String = "res://data/shard.json"

const _REQUIRED_FIELDS: Array[String] = [
	"mode", "seed", "fuel_start", "fuel_cap", "fuel_per_minute",
	"jump_cost", "npc_density", "paradise_count", "medal_ranks",
]

var mode: String = ""
var seed: int = 0
var fuel_start: float = 0.0
var fuel_cap: float = 0.0
var fuel_per_minute: float = 0.0
var jump_cost: float = 0.0
var npc_density: float = 0.0
var paradise_count: int = 0
var medal_ranks: int = 0


static func load_file(path: String = DEFAULT_PATH) -> ShardConfig:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		Log.error("world", "shard file missing or empty", {"path": path})
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		Log.error("world", "shard file is not a JSON object", {"path": path})
		return null
	var raw: Dictionary = parsed
	for field: String in _REQUIRED_FIELDS:
		if not raw.has(field):
			Log.error("world", "shard config is missing a required field", {"field": field})
			return null
	var config: ShardConfig = ShardConfig.new()
	config.mode = str(raw["mode"])
	config.seed = int(raw["seed"])
	config.fuel_start = float(raw["fuel_start"])
	config.fuel_cap = float(raw["fuel_cap"])
	config.fuel_per_minute = float(raw["fuel_per_minute"])
	config.jump_cost = float(raw["jump_cost"])
	config.npc_density = float(raw["npc_density"])
	config.paradise_count = int(raw["paradise_count"])
	config.medal_ranks = int(raw["medal_ranks"])
	if config.fuel_cap <= 0.0 or config.fuel_start > config.fuel_cap:
		Log.error("world", "shard fuel config is degenerate", {})
		return null
	return config
