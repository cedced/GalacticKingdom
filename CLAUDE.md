# CLAUDE.md

This file is the source of truth for how Claude works inside this repository. Read it fully before touching code. When it conflicts with a wiki page, this file wins; update the wiki, not this file, unless the project rules themselves change.

Project name: **GalacticKingdom**.

## 1. What we are building

A persistent-world, multiplayer space game inspired by *Starport: Galactic Empires* (Playtechtonics, 2004). Not a clone. We keep the feel and the loop, and modernize everything else.

What we keep from the inspiration:

- Start as a captain of a basic merchant ship near a safe home system. Haul cargo, run passengers, earn credits, buy a better ship.
- Every trip carries risk. Shields do not regenerate on their own; you buy them at ports. Energy regenerates and powers weapons.
- Warp fuel is the pacing resource. It accrues in real time whether or not you are online, and every jump, planet landing, or dock consumes some.
- Safe zone (police-controlled systems, no PvP) vs. lawless space (full PvP, alien NPCs, resource-rich planets).
- Owning and defending colonized planets is the primary path to rank and wealth. Pirates can invade and take them.
- Player groups (corporations) as the social and territorial unit.
- Top-down arcade flight with thrust and turn, primary and secondary weapons, "enter mode" to dock or land.
- IRC-style text chat with slash commands.
- Planets have biomes, each with its own growth tendency, resource profile, pollution rate, and one unique building. Colonies have governments, morale, taxes, and defenses.
- A small fixed commodity set (eight at launch) that both ports and colonies trade in.
- Persistent real time: ships left outside safe space or a port stay in the world and can be attacked ("sleepers").
- Two shard modes: Rebang (resets on a schedule, top ranks get medals) and Permaverse (never resets).
- Experience and standing are separate ladders. Experience ranks you; standing decides who shoots you.

What we drop: pay-for-power (premium ships, purchasable fuel, credits, or consumables). Monetization, if any, is cosmetic.

Full keep/adapt/drop table: `wiki/Inspiration.md`.

What we change:

- 3D scene rendered with an orthographic isometric camera (see Section 4). Assets are true 3D so lighting, rotation, and damage states are cheap.
- Procedurally generated galaxy and star systems from a seed. No hand-placed universe.
- A living economy with supply, demand, and price drift driven by simulated NPC traffic and real player trade.
- Dynamic quests and galaxy-wide events generated from world state rather than a static quest list.
- Named factions with reputation, territory, and diplomacy that shift over time.

Feature pillars, in priority order:

1. **System generator** (galaxy graph + per-system content, deterministic from seed)
2. **PvPvE combat** (ships vs. ships, NPCs, turrets, planetary defenses)
3. **Planet capture** (colonize, build, defend, invade)
4. **Dynamic economy and shops** (ports, starbases, price simulation)
5. **Dynamic questing and events** (world-state-driven generation)
6. **Factions** (reputation, territory, diplomacy)

If a task cannot be traced to one of these six pillars or to the core loop above, stop and ask before building it.

## 2. Tech stack

Recorded as ADR-001 in `wiki/adr/`. Change the stack only via a new ADR.

| Layer | Choice | Notes |
|---|---|---|
| Engine | Godot 4.x (latest stable) | Open source, headless server mode, orthographic camera built in |
| Language | GDScript for gameplay, C# only for hot paths with a measured need | Do not mix languages inside one system |
| Server | Dedicated headless Godot server, authoritative | Clients never own truth. Server runs the same `sim/` code. |
| Networking | Godot high-level multiplayer (ENet) with custom snapshot/interp layer | Rooms = star systems. One server process can host many systems. |
| Persistence | SQLite for dev, PostgreSQL for staging/prod | Access only through `server/persistence/`. No raw SQL in gameplay code. |
| Data | JSON for static definitions (ships, weapons, commodities, factions) under `data/` | Validated against JSON Schema in CI |
| Tests | GUT (Godot Unit Test) for GDScript, xUnit if C# is introduced | Sim code must be testable without a rendered scene |
| Build/CI | GitHub Actions: lint, schema validation, tests, headless export | Failing CI blocks merge |

## 3. Repository layout

```
/
  CLAUDE.md                 you are here
  wiki/                     design docs, ADRs, glossary (see Section 9)
  addons/                   third-party Godot addons (gut/ for tests); never edit in place
  assets/                   art the client loads; rules in assets/README.md
  data/                     static game definitions (JSON) + schemas/
  sim/                      pure simulation, no rendering, no networking, no engine nodes
    galaxy/                 seed -> galaxy graph -> systems -> bodies
    economy/                commodities, ports, price model, NPC traffic
    combat/                 damage, shields, energy, weapon resolution
    planets/                colony state, buildings, capture rules
    quests/                 quest templates, generators, event scheduler
    factions/               reputation, territory, diplomacy
    entities/               ships, players, NPCs, structures (data-only)
    motion/                 ship motion integration, shared by server tick and client prediction
  net/                      wire protocol shared by both peers: the RpcSurface node (declarations + signals, no logic)
  server/                   authoritative game server (uses sim/)
    net/                    replication, snapshots, RPC handlers
    persistence/            DB access layer, migrations
    world/                  system instances, tick loop, NPC AI drivers
  client/                   Godot project for the player-facing game
    scenes/
    rendering/              iso camera, pixel snapping, sorting, shaders
    ui/                     HUD, map, port screens, chat
    input/
    net/                    client prediction, interpolation
  tools/                    seed viewer, economy tuner, galaxy visualizer
  tests/
    sim/
    server/
    client/
```

Hard rule: `sim/` has zero dependencies on `client/`, `server/`, or Godot scene nodes. It may use Godot math types (`Vector2`, `RandomNumberGenerator`) only. Everything in `sim/` must be runnable headless in a test.

## 4. Rendering: 3D world, isometric presentation

- The world is a 3D scene. Gameplay happens on the XZ plane (Y is up). Height is used for visual layering only (ships hover, stations tower, planets are spheres).
- Camera is `Camera3D` in orthographic mode, pitched 30 degrees (true isometric would be 35.264; 30 gives a 2:1 pixel ratio that reads as classic iso), yawed 45 degrees. Camera does not rotate in gameplay. Zoom changes `size`, not position.
- Render at a fixed internal resolution and upscale with nearest-neighbor if we go for a pixel look, or render native if we go painterly. This is an open art decision (see `wiki/systems/rendering.md`). Do not bake this choice into gameplay code.
- Shadows, lighting, and post-processing are allowed but must be cheap: target 60 fps on integrated graphics with 50 ships and 200 projectiles on screen.
- All movement, hit detection, and positioning is 2D (XZ). Never let render height affect collision.
- Sorting and occlusion are handled by the 3D depth buffer. Do not write manual Y-sort logic.

## 5. Simulation rules that must hold everywhere

- **Determinism where cheap.** Galaxy generation, system generation, loot tables, and quest generation take a seed and produce identical output. Combat and economy ticks are not required to be deterministic but must be reproducible from logs.
- **Server is truth.** Client sends intent (thrust, turn, fire, enter, trade offer). Server resolves. Client predicts locally and reconciles.
- **Fixed tick.** Sim runs at 20 Hz on the server. Render interpolates. Never tie game logic to frame rate.
- **Everything is data.** Ship hulls, weapons, commodities, buildings, factions, quest templates live in `data/*.json`. Adding a new ship must not require code.
- **No hidden state.** Any value a player can be affected by (prices, faction standing, planet defenses) is queryable through a documented API so the UI, tools, and tests can read it.
- **Offline accrual.** Warp fuel, colony production, and faction drift continue while a player is offline. Compute lazily on login from timestamps; do not tick offline players.
- **Shard config, not code.** Rebang vs. Permaverse, fuel rates, NPC density, and reset schedule are `data/shard.json` values. Never branch on shard type in gameplay code; branch on the config value it implies.

## 6. Coding conventions

- GDScript: `snake_case` for functions and variables, `PascalCase` for classes and scene names, `SCREAMING_SNAKE` for constants. Type every function signature. Enable strict typing warnings as errors.
- One class per file. File name matches class name.
- Public API of a `sim/` module is a single facade script (`galaxy.gd`, `economy.gd`, etc.). Other modules call only the facade.
- No magic numbers in gameplay code. Tunables go in `data/tuning.json` and are loaded through `sim/tuning.gd`.
- Randomness always comes from an injected `RandomNumberGenerator` seeded by the caller. Never call `randi()` bare in `sim/`.
- Logging: `Log.info/warn/error(system, message, context_dict)`. No `print()` outside of `tools/`.
- Comments explain why, not what. If the what is unclear, rename the thing.
- Keep functions under roughly 40 lines. Split before you nest four deep.

## 7. How Claude should work in this repo

1. **Read before writing.** For any task, open the relevant `wiki/systems/*.md` page and the module facade first. If the page does not exist, create a stub with an "Open questions" section and proceed.
2. **Plan in the ticket, not in the code.** For anything touching more than one module, write a short plan (files to change, data to add, tests to add) and confirm before implementing.
3. **Tests first for sim.** Any change in `sim/` ships with a test in `tests/sim/`. Generators get golden-seed tests: fixed seed in, hash of output out.
4. **Schema before data.** New JSON fields get added to `data/schemas/` first, then to data files, then to loaders.
5. **Update the wiki in the same change.** If behavior changes, the matching wiki page changes. A PR that changes rules without changing docs is incomplete.
6. **Prefer small PRs.** One pillar, one concern. Do not refactor unrelated code in a feature PR.
7. **Never fabricate engine APIs.** If unsure whether a Godot method exists in the pinned version, check the docs or say so.
8. **Ask when the design is silent.** Do not invent gameplay rules. Propose options in the wiki page's "Open questions" and pick one only when told to.
9. **Do not commit secrets, save files, or exported builds.** `.gitignore` covers `*.db`, `exports/`, `.env`.

## 8. Definition of done

A task is done when all of these hold:

- Code compiles with zero warnings under strict typing.
- Tests pass locally and in CI, including golden-seed tests for generators.
- New data validates against schema.
- Wiki page for the affected system reflects the change.
- Behavior was checked in a headless server + one client, and in the seed viewer tool if generation was touched.
- Commit message follows `type(scope): summary` (types: feat, fix, refactor, docs, test, chore, data).

## 9. The wiki

`wiki/` is a plain Markdown folder so it renders on GitHub and in any editor. Structure:

```
wiki/
  Home.md               index, current milestone, links
  Inspiration.md        what the original game does and our keep/adapt/drop verdicts
  Glossary.md           shared vocabulary (use these terms in code identifiers)
  Architecture.md       client/server/sim boundaries, tick loop, data flow
  Roadmap.md            milestones and what "playable" means at each
  adr/                  Architecture Decision Records, numbered, never edited after acceptance
  systems/              one page per pillar plus rendering and networking
```

Every `systems/` page uses the same headings: Purpose, Player-facing rules, Data model, Algorithms, Tuning knobs, Interactions with other systems, Open questions, Test plan. Keep the headings even when a section is empty; empty sections are a to-do list.

## 10. Milestones

- **M0 Skeleton**: repo layout, CI, headless server boots, client connects, one ship flies in one empty system with iso camera.
- **M1 Galaxy**: seed -> galaxy graph -> systems with stars, planets, ports, warp gates. Galaxy map UI. Warp fuel and jumping.
- **M2 Trade**: ports buy and sell commodities, static prices, cargo holds, credits, buy ships and shields at a starbase.
- **M3 Combat**: weapons, shields, energy, NPC aliens, turrets, death and respawn, safe vs. lawless systems.
- **M4 Planets**: land, colonize, build, produce, defend, invade, capture.
- **M5 Living world**: price simulation, NPC traders, factions with reputation and territory, generated quests and events.
- **M6 Social**: corporations, chat channels, rankings, persistence hardening.

Do not start M(n+1) features while M(n) has open blocking bugs.

## 11. Quick commands

```
# run headless server (dev, SQLite)
godot --headless --path . --main-scene res://server/main.tscn

# run client
godot --path . --main-scene res://client/main.tscn

# run all tests
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# validate data against schemas
python tools/validate_data.py

# render a galaxy for a seed to PNG (uses the real sim/galaxy code, params from data/tuning.json)
godot --headless --path . -s tools/galaxy_viewer.gd -- --seed=12345 --out=galaxy.png

# intake a rendered sprite into assets/bodies (crop, clean, sheet + data stub; see assets/ART_WORKFLOW.md)
python tools/import_body_sprite.py art.png --kind planet --id planet_lava
```

Update this section whenever a script or path changes.
