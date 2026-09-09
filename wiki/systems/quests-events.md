# Quests and Events

## Purpose
Generate objectives and world conditions from what is actually happening in the galaxy, so the world feels reactive without hand-authored content.

## Player-facing rules
- Quest boards at ports and starbases show a handful of offers relevant to the local area and your standing.
- Quests have a deadline, a reward (credits, standing, items, charts), and sometimes a penalty.
- Events are announced galaxy-wide or per system and change rules for a while: blockade (police absent), plague (population drop, medicine demand), gold rush (resource boom), incursion (alien waves).
- Corporations can accept shared quests.

## Data model
- `QuestTemplate { id, kind: haul|taxi|escort|hunt|bounty|scout|defend|raid|artifact, requirements: [Condition], slots: [Param], reward_formula, deadline_formula }`
- Taxi (carry a passenger between ports) and escort are the M2 starter quests, matching the original's on-ramp.
- `Quest { template_id, params, issuer_faction, offered_to, state: offered|active|done|failed|expired, expires_at }`
- `Event { kind, scope: galaxy|system|faction, params, starts_at, ends_at, effects: [Effect] }`

## Algorithms
- Generator runs every 120 s. It scans world state (prices, threats, faction conflicts, undefended colonies, unexplored systems) and produces candidate quests by filling templates with real entities. Candidates are scored by relevance and variety and the top few per station are offered.
- Events are scheduled by a director that watches global metrics (average prices, PvP kill rate, faction tension) and triggers events that push toward a target rhythm.
- All generation is seeded by `hash(shard_seed, tick)` so incidents are reproducible from logs.

## Tuning knobs
`quests.generate_interval_s`, `quests.offers_per_station`, `events.min_gap_s`, `events.director_targets`.

## Interactions
- Reads from every other system. Writes rewards into economy, standings into factions, and multipliers into economy and combat.

## Open questions
- Quest chains vs. one-offs for M5.
- Player-created bounties.

## Test plan
- Template fill never references a dead or missing entity.
- Director does not fire two galaxy events inside `min_gap_s`.
- Reward formulas bounded.
