class_name StarSystem
extends RefCounted
## One star system: id, map position, and everything generated inside it.
## Data only; rooms (server) and system views (client) are built from this.

var id: int = 0
var name: String = ""
## Map-space position in the galaxy disc.
var position: Vector2 = Vector2.ZERO
## One of SystemGen.STAR_TYPES.
var star_type: String = ""
## 0 at home, growing with jump distance plus noise. Reward and danger scale
## with it (ports get rarer, M3 aliens get meaner).
var danger_tier: int = 0
## safe | lawless (wiki/Glossary.md: safe space is depth-limited around home).
var security: String = ""
var bodies: Array[SystemBody] = []
var stations: Array[SystemStation] = []
var gates: Array[WarpGate] = []


func gate_to(system_id: int) -> WarpGate:
	for gate: WarpGate in gates:
		if gate.to_system_id == system_id:
			return gate
	return null


func has_station(kind: String) -> bool:
	for station: SystemStation in stations:
		if station.kind == kind:
			return true
	return false
