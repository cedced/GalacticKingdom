class_name BodySpriteDef
extends RefCounted
## One loaded body sprite: data/bodies/<id>.json merged with its sprite
## folder's sheet.json and texture. Presentation only — the server never
## sees these (assets/README.md).

var id: String = ""
var kind: String = ""
var texture: Texture2D = null
var frames: int = 1
var fps: float = 0.0
var spin_speed: float = 0.0
var tint_mix: float = 0.0
var corona: bool = false
var corona_spread: float = 1.0
var pulse: float = 0.0
var biomes: Array[String] = []
var star_types: Array[String] = []
var station_kinds: Array[String] = []
