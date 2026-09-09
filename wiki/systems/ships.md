# Ships and Equipment

## Purpose
The progression ladder. Ships define what you can carry, how you fight, and how far you can go.

## Player-facing rules
- Starter hull: cheap, small cargo, one primary hardpoint, weak thrust.
- Buy hulls only at starbases. Trading in your current hull gives partial value.
- Hulls have hardpoints by type. Weapons and modules must match a hardpoint type.
- Shields are bought in units and capped by the hull.
- Warp fuel cost per jump scales with hull mass.
- Some hulls have a built-in special (cloak, repulsor bomb, surface missiles, deep scanner). Specials are hull traits, not purchasable modules, so hull choice stays meaningful.
- Scanners are modules: basic (ship info), neutrino (colony contents from orbit), and long-range (system contents from a gate).
- Artifacts found on planets can be equipped as unique modules.
- Corporation leaders can fly a corp flagship: strong, slow, and a visible target.

## Data model
See `data/ships/*.json` (hull definitions, one per file, filename = id; `data/hulls/` was renamed to match the CLAUDE.md Section 3 layout and `assets/README.md` at M0), `data/weapons/*.json`, `data/modules/*.json`. Schema in `data/schemas/`.

As of M0 a hull carries identity (`id`, `display_name`, `model`) and motion stats (`mass`, `accel`, `max_speed`, `turn_rate_deg`, `drag`) — see `data/schemas/ship.schema.json`. Cargo, hardpoints, shields, and energy join the schema at M2/M3. The only hull is `merchant_mk1` (the starter; all M0 stat values are placeholders pending playtest).

Hull archetypes for M2 (placeholder names): Courier, Freighter, Corvette, Frigate, Cruiser, Colony Ship.

## Algorithms
- Ship stats are computed once from hull plus fitted equipment and cached on the entity. Recomputed on refit.
- Motion (M0): `sim/motion/motion.gd` integrates thrust/turn intents on the XZ plane — turn at `turn_rate_deg`, accelerate along facing, exponential `drag` damping, clamp to `max_speed`. Pure and dt-parameterized so the server tick and client prediction run the identical code.
- Go-to autopilot (M0): left click sets a target on the XZ plane; `Motion.autopilot_intent` emits ordinary thrust/turn intents each tick, so the server never learns about targets and stays authoritative. Steering is velocity-aware (steer toward a desired velocity, not at the target): excess or tangential speed turns the steering vector against the motion, so the ship flips and burns to brake rather than orbiting. The ship flies at the hull's `max_speed` (per-ship data in `data/ships/*.json`, like `cargo_slots`) for as long as possible: desired speed is only reduced inside the braking envelope `Motion.braking_limited_speed` — the fastest speed from which a 180° flip at `turn_rate_deg` plus a full burn at `accel` can still stop within the remaining distance, padded by `brake_margin` (>= 1). Thrust feed-forwards the drag-holding component so cruise actually sits at `max_speed` instead of drooping below it. To keep the cruise smooth, the nose aims at the target while the velocity error is small and only rotates toward the raw correction as the error grows (chasing tiny lateral errors nose-first causes weaving); the rudder has a small deadzone (`heading_deadzone_deg`) and thrust is proportional to the forward speed deficit (`thrust_softness`) rather than bang-bang. Manual input (W/A/D) cancels it; arrival inside `arrive_radius` goes idle and drag bleeds off the rest. Tunables under `autopilot` in `data/tuning.json`; params object is `sim/motion/autopilot_params.gd`.

## Tuning knobs
All per-item values live in data, not tuning.json.

## Interactions
- Combat, economy (prices, restock), planets (colony ships).

## Open questions
- Module slots beyond weapons (cargo expanders, fuel scoops, scanners).
- Ship skins as the only monetization, if any. No premium hulls, fuel, or consumables for money.
- Light character attributes (e.g. one that trims fuel per jump) as a small horizontal progression.

## Test plan
- Every hull in data validates and can be spawned headless.
- Stat computation is pure and deterministic.
