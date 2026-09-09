# Galaxy and System Generator

## Purpose
Turn one 64-bit seed into a complete, deterministic galaxy: a graph of systems, the contents of each system, and the starting layout of factions, ports, and safe space.

## Player-facing rules
- The galaxy is fixed for the life of a shard. Everyone shares the same map.
- Systems are reachable only via warp lanes. The map shows lanes you have discovered plus any you have bought or been given charts for.
- A home system (Sol equivalent) sits in the middle of a cluster of safe systems. Danger and reward scale roughly with graph distance from home.
- Some systems are dead ends, some are chokepoints. Chokepoints matter for territory.

## Data model
Implemented in `sim/galaxy/` (M1); the facade is `galaxy.gd` (`Galaxy.generate(seed, params)`).
- `GalaxyData { seed, systems: [StarSystem], lanes: [WarpLane (a, b, length)], home_system_id }` — plus `shortest_path()` (fewest jumps), `neighbors()`, and `serialize()/content_hash()` for goldens.
- `StarSystem { id, name, position, star_type, danger_tier, security: safe|lawless, bodies, stations, gates }` — `faction_owner` arrives with M5.
- `SystemBody { id, kind: planet|asteroids|derelict, biome, size, resources: {commodity: richness}, colonizable, orbit_radius, orbit_angle }` — moons folded into `planet` for now; orbits are static.
- `SystemStation { id, kind: port|starbase, position }` — `commodity_profile` arrives with M2, `faction` with M5.
- `WarpGate { id, to_system_id, position }` — one per lane endpoint, on the `system_radius` ring, pointing map-space toward the neighbor.

Positions are map-space (galaxy disc); body/station/gate positions are gameplay-space within a system. Both are XZ-plane `Vector2`s.

## Algorithms
As implemented (each numbered step draws RNG in this exact order; reordering is a generation change and bumps `GalaxyData.GENERATION_VERSION`):
1. Place N positions by Poisson-like dart throwing in a disc; spacing relaxes if the disc cannot fit N (`GalaxyGraphGen.place_systems`).
2. Delaunay-triangulate, filter to the relative neighborhood graph (RNG ⊇ MST, so connectivity is structural), then add `long_edge_ratio` extra long lanes for loops (`build_lanes`).
3. Home = system nearest the centroid. `danger_tier` = BFS jump depth from home plus ±1 noise (min 1 outside home; home is 0).
4. `security = safe` for BFS depth ≤ `safe_depth`, else `lawless`.
5. Per system, derive a child RNG via SplitMix64(seed, system.id) and generate the name, star type, bodies, and (by tier probability) a port (`SystemGen.populate`). Distribution tables (star types, biomes, biome→commodity tendencies) are consts in `system_gen.gd` until a designer needs them in data.
6. Gates: one per lane endpoint, placed on the `system_radius` ring toward the neighbor.
7. Starbases: home always (plus a guaranteed port there); the rest drawn from safe space with ties toward calm systems.
8. Names come from a syllable grammar (`name_gen.gd`); the facade enforces galaxy-wide uniqueness.

Deferred: faction seeding + territory flood-fill (M5), paradise world placement and artifact scatter (M4), moons as distinct bodies.

Golden-seed tests: `tests/sim/test_galaxy.gd` hashes the serialized galaxy for seeds 1, 42, 12345 with fixed explicit params (never `from_tuning`, so retuning does not move goldens). Any intentional change to generation bumps `GENERATION_VERSION` and re-records the hashes (the failing assert prints the new hash). Serialization rounds floats to 3 decimals so last-ulp platform differences cannot move the hash.

Determinism is what lets the client regenerate the whole galaxy from the seed in the server's welcome message — only mutable state ever crosses the wire.

## Tuning knobs
`galaxy.system_count`, `galaxy.radius`, `galaxy.spacing_factor`, `galaxy.long_edge_ratio`, `galaxy.safe_depth`, `galaxy.starbase_count`, `galaxy.max_bodies`, `galaxy.port_probability_by_tier`, `galaxy.system_radius`.

## Interactions
- Economy reads `Body.resources` and `Station.commodity_profile` for initial supply.
- Factions read anchor systems and territory.
- Quests read danger tiers and chokepoints for placement.

## Open questions
- ~~Full galaxy at shard creation or lazy per system?~~ Resolved M1: full at creation — generation takes milliseconds and full data enables the map, routing, and client-side regeneration.
- Should players be able to discover hidden lanes (wormholes) that are not in the base graph?
- The map currently shows the whole galaxy; discovered-lanes-only ("charts you have bought or been given") needs per-player discovery state — persistence first.

## Test plan
Implemented in `tests/sim/test_galaxy.gd`:
- Golden seeds (1, 42, 12345).
- Connectivity: every system reachable from home; shortest paths only walk real lanes.
- No two systems share a name.
- Gates mirror lanes exactly; home has a starbase and a port; starbase count matches params and stays in safe space.
- Bodies well-formed (kinds, biomes, richness bounds, orbits inside the gate ring).
Open: danger tier histogram bounds.
