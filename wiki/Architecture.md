# Architecture

## Three layers

```
client/   presentation, input, prediction
server/   authority, persistence, replication
sim/      pure rules, no engine nodes, runs on both
```

`sim/` is the shared brain. The server runs it as truth. The client runs it for prediction and for offline tools. It must never import from `client/` or `server/`.

## Server tick loop

1. Drain input intents from all connected clients for this system.
2. Advance every ship, projectile, and NPC by one tick using `sim/`.
3. Resolve collisions, damage, deaths, dock/land/jump requests.
4. Run slow systems on their own cadence: economy every 60 s, faction drift every 300 s, quest generator every 120 s, colony production every 60 s.
5. Emit a snapshot delta to each client in the system.
6. Queue persistence writes (batched, async).

## Instancing

One server process hosts N systems. Each system is an independent room. Jumping moves the player entity between rooms. Cross-system data (economy, factions, quests) lives in a galaxy-level service that rooms read from.

## Data flow

```
data/*.json  ->  sim loaders  ->  immutable definitions (hulls, weapons, commodities)
seed         ->  sim/galaxy   ->  galaxy graph + system contents (deterministic)
DB           ->  server/persistence  ->  mutable state (players, colonies, prices, standings)
```

## M0 skeleton (implemented)

- `server/main.gd` boots headless, binds ENet on `net.port`, and ticks one `SystemRoom` (`server/world/system_room.gd`) at `net.tick_hz` (20) by setting `Engine.physics_ticks_per_second`.
- `sim/` gained `motion/` (shared integrator) alongside `entities/` (ShipState, ShipIntent, HullDef + loader facade), plus the cross-cutting `sim/tuning.gd` and `sim/log.gd`. All of it runs headless under GUT.
- The client (`client/main.gd`) sends intents, predicts its own ship with the same integrator, and renders every peer in the snapshot. One room, one hull, no persistence yet — the DB layer arrives when there is state worth saving (M1 fuel/position).

## Open questions

- Single process per shard vs. one process per N systems with a coordinator. Start single, split when profiling says so.
- Whether NPC AI runs in `sim/` (deterministic, testable) or `server/world/` (allowed to use server services). Leaning `sim/` for behavior, `server/` for scheduling.

## Shard configuration

`data/shard.json` defines a shard: `{ mode: rebang|permaverse, seed, reset_schedule?, fuel_start, fuel_cap, fuel_per_minute, npc_density, paradise_count, medal_ranks }`. Rebang resets wipe player state, regenerate from a new seed, and write medals to the account service (which persists across shards). Gameplay code reads config values, never the mode name.
