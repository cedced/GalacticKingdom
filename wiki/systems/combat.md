# Combat (PvPvE)

## Purpose
Real-time arcade ship combat between players, NPC aliens, pirates, police, station turrets, and planetary defenses.

## Player-facing rules
- Shields are your health. They do not regenerate. Buy more at a port.
- Energy powers weapons and afterburner. It regenerates continuously.
- Primary weapon (fast, cheap) and secondary weapon (slow, strong or utility) on separate keys.
- Safe space: you cannot damage players. Attacking NPCs summons police.
- Lawless space: anything goes.
- Death drops a fraction of cargo as salvage, destroys the ship, and respawns you at your last starbase in a starter hull. Colonies are not lost on death.
- Logging out does not remove your ship. Docked at a port or inside safe space you are untouchable. Anywhere else you are a sleeper and can be attacked. A short disconnect grace timer covers crashes.
- Police stations in safe space post bounties on outlaws. Players can add to a bounty.

## Data model
- `Hull { id, mass, max_energy, energy_regen, max_shields_cap, cargo_slots, hardpoints: [{type}], thrust, turn_rate }`
- `Weapon { id, hardpoint_type, energy_cost, cooldown, projectile: Projectile | beam: Beam }`
- `Projectile { speed, lifetime, damage, damage_type, homing? }`
- `DamageType: kinetic | energy | explosive` with per-hull resistances.

## Algorithms
- Movement: Newtonian with drag on the XZ plane. Thrust adds velocity along facing, turn changes facing, drag scales velocity per tick.
- Hit detection: circle vs. circle on the server at tick rate, with lag compensation (rewind targets to the shooter's view time, capped at 200 ms).
- Damage: `dmg * (1 - resistance[type])`, subtract from shields. Zero shields = destroyed.
- NPC AI: behavior trees in `sim/combat/ai/`. Archetypes: drifter (ignores you), hunter (chases), guard (defends a point), police (responds to aggression in safe space).

## Tuning knobs
`combat.drag`, `combat.lag_comp_max_ms`, `combat.cargo_drop_fraction`, per-hull and per-weapon stats in `data/`.

## Interactions
- Planets: planetary defenses use the same turret code as stations.
- Factions: killing faction NPCs or players changes standing.
- Economy: salvage enters the economy as commodities.

## Open questions
- Friendly fire inside a corporation.
- Whether kills in lawless space should carry a bounty system.
- Cloaking or ECM as secondary weapons (the original has a cloaking hull; likely yes as a hull trait).
- Nukes or other high-impact consumables. Risk: they become the meta and a pay-to-win vector on other games.
- Disconnect grace duration.

## Test plan
- Deterministic replay: record intents, replay, assert identical outcomes.
- Lag compensation unit tests with synthetic latency.
- Balance harness: N vs N NPC battles, report win rates per hull.
