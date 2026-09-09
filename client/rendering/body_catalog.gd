class_name BodyCatalog
extends RefCounted
## Loads every data/bodies/*.json into BodySpriteDefs and answers "which
## sprite draws this biome / star type". Adding new body art is a data
## change, never a code change (CLAUDE.md Section 5). A biome or star type
## with no sprite falls back to SystemView's primitive shapes, so partial
## art never breaks the client.

const BODIES_DIR: String = "res://data/bodies/"

static var _defs: Array[BodySpriteDef] = []
static var _loaded: bool = false


static func for_biome(biome: String) -> BodySpriteDef:
	_load_all()
	for def: BodySpriteDef in _defs:
		if def.kind == "planet" and def.biomes.has(biome):
			return def
	return null


static func for_star_type(star_type: String) -> BodySpriteDef:
	_load_all()
	for def: BodySpriteDef in _defs:
		if def.kind == "sun" and def.star_types.has(star_type):
			return def
	return null


static func _load_all() -> void:
	if _loaded:
		return
	_loaded = true
	for file: String in DirAccess.get_files_at(BODIES_DIR):
		if file.ends_with(".json"):
			var def: BodySpriteDef = _load_def(BODIES_DIR + file)
			if def != null:
				_defs.append(def)
	Log.info("client", "body sprites loaded", {"count": _defs.size()})


static func _load_def(path: String) -> BodySpriteDef:
	var raw: Variant = _parse_json_file(path)
	if not (raw is Dictionary):
		return null
	var sprite_dir: String = str(raw.get("sprite_dir", ""))
	var sheet: Variant = _parse_json_file(sprite_dir + "/sheet.json")
	if not (sheet is Dictionary):
		return null
	var texture: Texture2D = load(sprite_dir + "/sheet.png") as Texture2D
	if texture == null:
		Log.error("client", "body sheet.png failed to load", {"dir": sprite_dir})
		return null
	var def: BodySpriteDef = BodySpriteDef.new()
	def.id = str(raw.get("id", ""))
	def.kind = str(raw.get("kind", ""))
	def.texture = texture
	def.frames = maxi(int(sheet.get("frames", 1)), 1)
	def.fps = float(sheet.get("fps", 0.0))
	def.spin_speed = float(raw.get("spin_speed", 0.0))
	def.tint_mix = float(raw.get("tint_mix", 0.0))
	def.corona = bool(raw.get("corona", false))
	def.corona_spread = maxf(float(raw.get("corona_spread", 1.0)), 1.0)
	def.pulse = float(raw.get("pulse", 0.0))
	def.biomes.assign(raw.get("biomes", []))
	def.star_types.assign(raw.get("star_types", []))
	return def


static func _parse_json_file(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		Log.error("client", "body sprite file missing or empty", {"path": path})
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		Log.error("client", "body sprite file is not a JSON object", {"path": path})
		return null
	return parsed
