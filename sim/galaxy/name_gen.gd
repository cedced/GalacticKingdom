class_name NameGen
extends RefCounted
## Internal to sim/galaxy: syllable-grammar system names. Uniqueness is the
## caller's job (it owns the galaxy-wide set of taken names).

const _STARTS: Array[String] = [
	"Al", "Ar", "Be", "Cy", "Da", "Ere", "Hel", "Ka", "Lu", "Mi",
	"Ny", "Or", "Qua", "Ri", "Sol", "Ta", "Tor", "Ve", "Xa", "Za",
]
const _MIDS: Array[String] = [
	"du", "ke", "li", "lo", "ma", "ne", "ra", "ri", "sa", "tho", "ti", "va",
]
const _ENDS: Array[String] = [
	"ar", "dor", "el", "ia", "mir", "n", "on", "ra", "s", "th", "us", "x",
]


static func system_name(rng: RandomNumberGenerator) -> String:
	var name: String = _STARTS[rng.randi_range(0, _STARTS.size() - 1)]
	if rng.randf() < 0.55:
		name += _MIDS[rng.randi_range(0, _MIDS.size() - 1)]
	name += _ENDS[rng.randi_range(0, _ENDS.size() - 1)]
	return name
