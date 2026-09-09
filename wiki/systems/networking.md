# Networking

## Purpose
Keep every client's view consistent with the authoritative server at playable latency.

## Player-facing rules
- Your own ship feels instant. Others may skip slightly under bad connections.
- If the server rejects an action (trade at a stale price, firing with no energy), the UI shows why.

## Data model
- Intent message: `{tick, thrust, turn, fire_primary, fire_secondary, enter_mode, action?}` sent every client tick. M0 implements the `thrust, turn` subset as an unreliable-ordered RPC (`submit_intent`); the rest arrives with combat (M3).
- Snapshot delta: per-entity position, velocity, facing, shields, energy, plus event list (spawn, despawn, hit, death). M0 sends full state every tick (`receive_snapshot`: tick + per-peer `PackedFloat32Array [pos_x, pos_z, heading, vel_x, vel_z]`); deltas and the event list are M1+.
- Reliable RPCs for trade, dock, quest accept, chat.
- M0 wiring: RPC endpoints live on the root `Main` node of both `client/main.gd` and `server/main.gd`; the two declarations must stay config-identical. Spawn/despawn is implied by peers appearing in or dropping out of the snapshot.

## Algorithms
- Client prediction for the local ship using the same `sim/` movement code. Server sends acknowledged tick; client rewinds and replays unacknowledged intents on mismatch beyond a threshold. M0 ships a simpler version: predict with `sim/motion`, blend gently toward each authoritative snapshot, hard-snap beyond `net.snap_correction_dist`. Rewind-and-replay is open.
- Remote entities interpolated 100 ms behind the latest snapshot.
- Lag compensation for hits: server rewinds hitboxes to the shooter's view time, capped at 200 ms.
- Interest management: clients receive only entities in their system and within a radius.

## Tuning knobs
`net.tick_hz`, `net.interp_delay_ms`, `net.lag_comp_max_ms`, `net.interest_radius`.

## Interactions
- All of `sim/` must be pure enough to run on both ends.

## Open questions
- ENet vs. WebSocket if web export becomes a goal.
- Snapshot compression strategy.

## Test plan
- Synthetic latency and packet loss harness in `tools/`.
- Prediction divergence stays under threshold at 150 ms RTT with 5 percent loss.
