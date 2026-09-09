# Networking

## Purpose
Keep every client's view consistent with the authoritative server at playable latency.

## Player-facing rules
- Your own ship feels instant. Others may skip slightly under bad connections.
- If the server rejects an action (trade at a stale price, firing with no energy), the UI shows why.

## Data model
- Intent message: `{tick, thrust, turn, fire_primary, fire_secondary, enter_mode, action?}` sent every client tick. Implemented subset: `thrust, turn, enter` as an unreliable-ordered RPC (`submit_intent`); the fire fields arrive with combat (M3). `enter` is the Glossary's enter/boarding mode: the server resolves obstacle collision per tick (`Motion.resolve_obstacles`, predicted identically on the client) — everything solid normally; planets, stations, and derelicts permeable in enter mode (contact will mean dock/land/board); the sun a wall in every mode. Gates jump on contact in enter mode (client-requested, server-validated like J).
- Snapshot delta: per-entity position, velocity, facing, shields, energy, plus event list (spawn, despawn, hit, death). Currently full state every tick (`receive_snapshot`: tick + a Dictionary keyed by **entity id** of `ShipState.pack()` arrays); deltas and the event list are open. The packed layout lives only in `ShipState.pack()/unpack()` (`PACK_STRIDE` floats) — never hand-decode it.
- Entity ids are server-assigned and distinct from ENet peer ids (`receive_welcome` tells a fresh peer which entity is its ship). Peer ids die with the connection; entity ids are the namespace NPCs, sleepers, and structures will share.
- Reliable RPCs (implemented): `receive_welcome` (entity id, galaxy seed, starting system, fuel contract — the client regenerates the whole galaxy locally from the seed, so no map data crosses the wire), `request_jump(to_system_id)` -> `receive_jump(system_id, fuel)` or `receive_jump_denied(reason, fuel)`. The server re-derives gate, distance, and fuel itself (`Galaxy.jump_denial`); the client's own answer is only a UI hint. Coming later: trade, dock, quest accept, chat.
- Wiring: every RPC is declared once in `net/rpc_surface.gd`, a pure-transport node both entry scenes instance at the same path (`/root/Main/Rpc`). Its methods only re-emit payloads as signals; the hosting side connects the handlers. Godot matches RPCs by node path + method + config, so a single shared declaration makes drift impossible. Spawn/despawn is implied by entities appearing in or dropping out of the snapshot.
- Both ends run the fixed `net.tick_hz` sim tick (client pins `Engine.physics_ticks_per_second` too); ship views blend the 20 Hz state up to display rate at `net.view_blend_rate`.
- Dead-man's switch: an intent older than `net.intent_timeout_ms` is treated as idle, so a frozen or lossy client's ship coasts to a stop instead of burning forever.

## Algorithms
- Client prediction for the local ship using the same `sim/` movement code. Server sends acknowledged tick; client rewinds and replays unacknowledged intents on mismatch beyond a threshold. M0 ships a simpler version: predict with `sim/motion`, blend toward each authoritative snapshot at `net.reconcile_blend`, hard-snap beyond `net.snap_correction_dist`. Rewind-and-replay is open.
- Remote entities blend exponentially toward the newest snapshot (`net.view_blend_rate`). A proper interpolation buffer that renders a fixed delay behind the newest snapshot is open; add its knob back when it exists.
- Lag compensation for hits: server rewinds hitboxes to the shooter's view time, capped at 200 ms.
- Interest management: clients receive only entities in their system and within a radius.

## Tuning knobs
`net.tick_hz`, `net.intent_timeout_ms`, `net.snap_correction_dist`, `net.reconcile_blend`, `net.view_blend_rate`; M3 adds `net.lag_comp_max_ms`, `net.interest_radius`.

## Interactions
- All of `sim/` must be pure enough to run on both ends.

## Open questions
- ENet vs. WebSocket if web export becomes a goal.
- Snapshot compression strategy.

## Test plan
- Synthetic latency and packet loss harness in `tools/`.
- Prediction divergence stays under threshold at 150 ms RTT with 5 percent loss.
