# Factions

## Purpose
Give the galaxy political texture: NPC powers with territory, opinions of you, and relationships with each other that shift over time.

## Player-facing rules
- Standing per faction from -100 to 100. Gained by quests, trade, and killing their enemies. Lost by attacking them, smuggling, or taking their planets.
- Standing gates prices, quest access, docking rights, and whether their police shoot you on sight.
- Factions hold territory (sets of systems). Territory shifts slowly based on conflict and player actions.
- Factions have relations with each other: allied, neutral, hostile. Wars create raid quests and blockade events.
- The Concord (safe-space police) is a special faction that never loses territory and never goes to war.
- Alongside per-faction standing there is one global lawful/outlaw score. Attacking non-hostile players lowers it; bounty hunting, escorts, and housing colonists raise it. Outlaws are shot on sight by the Concord and get bounties; lawful players get police help. This is the original's good/evil axis made explicit.

## Data model
- `Faction { id, name, home_system, territory: [system_id], relations: {faction_id: -100..100}, traits: [expansionist|mercantile|militant|isolationist] }`
- `Standing { player_id, faction_id, value, last_changed_at }`
- `Alignment { player_id, value: -100..100 }` (global lawful/outlaw)

## Algorithms
- Drift tick every 300 s: relations move by trait pressure plus recent incidents. Crossing thresholds flips ally/hostile state and emits an event.
- Territory contest: a border system shifts when one faction's influence (NPC presence, owned colonies, player-completed quests) exceeds the other's for a sustained period.
- Standing decays toward zero very slowly so old grudges fade.

## Tuning knobs
`factions.drift_interval_s`, `factions.standing_decay_per_day`, `factions.war_threshold`, `factions.territory_flip_hours`.

## Interactions
- Economy: tariffs and haggle odds.
- Combat: police response, NPC hostility.
- Quests: issuers and targets.
- Planets: tax and provocation.

## Open questions
- Number of factions at launch (leaning 5 plus the Concord).
- Whether player corporations can become factions with territory.

## Test plan
- Standing math bounded and symmetric where expected.
- Territory flip only on sustained pressure, not on a single spike.
