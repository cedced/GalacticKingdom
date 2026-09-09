class_name SystemBody
extends RefCounted
## One thing orbiting a star: planet, asteroid field, or derelict. Data only.
## Moons are folded into "planet" until something needs the distinction.

var id: int = 0
## planet | asteroids | derelict (wiki/Glossary.md "Body").
var kind: String = ""
## One of SystemGen.BIOMES for planets; "" for non-planets.
var biome: String = ""
## Relative render scale; never collision (CLAUDE.md Section 4).
var size: float = 1.0
## commodity id -> richness 0..1. Economy (M2) reads this for initial supply.
var resources: Dictionary[String, float] = {}
var colonizable: bool = false
## Static orbit for M1: position derived from radius + angle, bodies do not
## move within a shard's life.
var orbit_radius: float = 0.0
var orbit_angle: float = 0.0


func position() -> Vector2:
	return Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
