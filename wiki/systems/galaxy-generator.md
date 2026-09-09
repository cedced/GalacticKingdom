# Galaxy and System Generator

## Purpose
Turn one 64-bit seed into a complete, deterministic galaxy: a graph of systems, the contents of each system, and the starting layout of factions, ports, and safe space.

## Player-facing rules
- The galaxy is fixed for the life of a shard. Everyone shares the same map.
- Systems are reachable only via warp lanes. The map shows lanes you have discovered plus any you have bought or been given charts for.
- A home system (Sol equivalent) sits in the middle of a cluster of safe systems. Danger and reward scale roughly with graph distance from home.
- Some systems are dead ends, some are chokepoints. Chokepoints matter for territory.

## Data model
- `Galaxy { seed, systems: [System], lanes: [(a, b, length)] }`
- `System { id, name, position, star_type, danger_tier, security: safe|lawless, faction_owner?, bodies: [Body], gates: [Gate], stations: [Station] }`
- `Body { id, kind: planet|moon|asteroids|derelict, biome, size, resources: {commodity: richness}, colonizable }`
- `Station { id, kind: port|starbase, faction, commodity_profile }`

## Algorithms
1. Place N system positions with Poisson disk sampling in a disc, N from tuning (default 400).
2. Build a relative neighborhood graph, then add a few random long edges for loops. Ensure connectivity.
3. Pick home at the centroid. Assign `danger_tier` by BFS depth from home, with noise.
4. Mark safe space as all systems within depth D of home (default 3).
5. Seed factions at spread-out anchor systems and flood-fill territory with decay.
5b. Place a fixed number of paradise worlds (default 3) in mid-to-high danger systems, never adjacent to each other, never in safe space. Scatter artifacts with weight toward gas giants, tiny worlds, and dead-end systems.
6. Per system, derive a child RNG from `hash(seed, system.id)` and generate bodies, stations, and gates. Stations placed only where population and resources justify it.
7. Name systems with a syllable grammar seeded per system.

Golden-seed tests: hash the serialized galaxy for seeds 1, 42, 12345 and assert stability. Any intentional change to generation bumps a version number and regenerates the goldens.

## Tuning knobs
`galaxy.system_count`, `galaxy.safe_depth`, `galaxy.long_edge_ratio`, `galaxy.starbase_count`, `system.max_bodies`, `system.port_probability_by_tier`.

## Interactions
- Economy reads `Body.resources` and `Station.commodity_profile` for initial supply.
- Factions read anchor systems and territory.
- Quests read danger tiers and chokepoints for placement.

## Open questions
- Do we generate the full galaxy at shard creation or lazily per system on first visit? Full at creation is simpler and the galaxy is small.
- Should players be able to discover hidden lanes (wormholes) that are not in the base graph?

## Test plan
- Golden seeds.
- Connectivity: every system reachable from home.
- Distribution: danger tier histogram within expected bounds.
- No two systems share a name.
