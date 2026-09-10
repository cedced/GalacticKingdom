# Planets and Capture

## Purpose
Give players something to own, grow, defend, and lose. Colonies are the main driver of rank and long-term income.

## Player-facing rules
- Enter mode + collide with a planet = land (costs 1 warp fuel). (M1 state: planets are solid walls outside enter mode and permeable inside it — the contact hook exists, landing itself arrives with M4.)
- Uncolonized planets can be claimed by dropping a colony pod (bought at a starbase).
- Planets have a biome. Nine biomes are colonizable (arctic, volcanic, desert, mountainous, greenhouse, oceanic, rocky, earthlike, paradise). Gas giants and tiny worlds are not, but can hold artifacts and sleepers.
- Each biome sets: population growth tendency, which commodities it can produce and how fast, pollution rate, and one unique building only that biome can build.
- Paradise worlds: a fixed small number per shard (default 3), no pollution, produce everything, and grant a rank bonus to the owner. Expect them to be fought over.
- Colonies have population, morale, a government, a tax rate, pollution, buildings, stockpiles, research, and defenses.
- Government is a choice with trade-offs (e.g. one maximizes morale growth, another trades morale for production speed, another allows growth on hostile biomes). Changing government has a cooldown.
- Colonists are allocated between production and construction. Construction consumes stockpiled commodities.
- Pollution accumulates with production and must be paid down. High pollution reduces growth and morale.
- Colonies generate experience for the owner over time, scaled by colonists with positive morale.
- Buildings produce commodities from the planet's resources. Stockpiles must be hauled off in ships or sold to visiting NPC traders at a discount.
- Defenses: flak cannon (anti-missile), laser cannon (anti-ship), mines, solar cannon (heavy, slow), shield generator, garrison. Attackers must beat orbital defenses, then land and beat ground defenses.
- Scanners can reveal a colony's buildings and defenses from orbit. A counter-building (greenhouse unique) hides them.
- Invasion tools: surface missiles fired from orbit, and hulls with surface-capable weapons.
- Capture: after defenses reach zero, an attacker who lands takes ownership. Population and buildings carry over, partially damaged.
- Owner limits: each player has a colony cap that grows with rank. Corporations pool caps.

## Data model
- `Biome { id, growth_bias, produces: {commodity: rate}, pollution_rate, unique_building, colonizable }`
- `Government { id, morale_rate, production_mult, growth_mult, tax_cap }`
- `Colony { planet_id, owner: player|corp, population, morale, government, tax_rate, pollution, allocation: {production, construction}, buildings: [{type, level, hp}], stockpile: {commodity: qty}, research: {tech: progress}, defenses: {flak, laser, mines, solar, shield, garrison}, last_tick_at }`
- `Building { id, cost: {commodity: qty}, produces: {commodity: rate}, consumes, effect?, requires_biome? }`
- Starting commodity set (8): metal ore, anaerobes, medicine, organics, oil, uranium, equipment, spice. Names are placeholders; count is deliberate.

## Algorithms
- Production ticks every 60 s on the server, or lazily on visit using `last_tick_at`.
- Population grows toward a biome-based cap, modified by morale and food supply.
- Invasion is a real-time combat encounter in the planet's orbital layer, then a ground layer. Ground layer is abstracted for M4 (attacker strength vs. garrison), possibly a real scene later.

## Tuning knobs
`planet.production_interval_s`, `planet.pop_growth_rate`, `planet.capture_damage_fraction`, `planet.base_colony_cap`.

## Interactions
- Economy: colonies are supply sources.
- Factions: colonies inside faction territory pay tax or provoke the faction.
- Quests: defend/raid colony quests generated from ownership and threat state.

## Open questions
- Offline protection windows to prevent pure timezone griefing.
- Exact government list and numbers.
- Whether research is per colony (original) or per player with colony-driven speed.
- Whether NPC factions colonize on their own.

## Test plan
- Lazy production math equals ticked production math for the same elapsed time.
- Capture transfers ownership and applies damage correctly.
- Colony cap enforcement.
