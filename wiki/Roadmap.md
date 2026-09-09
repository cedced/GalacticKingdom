# Roadmap

Each milestone ends with a playable build and a written test session.

| Milestone | Playable means |
|---|---|
| M0 Skeleton | Two clients see each other fly in one system. Iso camera works. CI green. |
| M1 Galaxy | Open the map, plot a route, jump between generated systems, watch fuel drain and refill. |
| M2 Trade | Buy low at one port, sell high at another, afford a better ship at a starbase. |
| M3 Combat | Die to an alien, respawn, kill it, then get ganked by another player outside safe space. |
| M4 Planets | Land, colonize, build a factory, come back to find it producing, lose it to an invader. |
| M5 Living world | Prices move on their own, a faction expands, a quest board offers something relevant to where you are. |
| M6 Social | Join a corp, share a planet, climb a leaderboard. |

Cut scope before slipping a milestone. Cut polish before cutting a pillar.

## Carried debt (from the 2026-09 M0 code review)

Each known issue is assigned to the milestone that must absorb it. Do not start a milestone's features while its debt rows are open (CLAUDE.md Section 10).

| Issue | Phase | Status |
|---|---|---|
| Client predicted at 60 Hz against the 20 Hz server (intents discarded, dt-variant integration) | M0 hardening | fixed |
| Hull loading unvalidated (null hull deref / NaN physics from defaulted fields) | M0 hardening | fixed |
| Sticky intents: a silent client's last intent replayed forever | M0 hardening | fixed |
| Failed tuning load degraded to zeros ("listening" on port 0) | M0 hardening | fixed |
| Spawn ring repeated after 4 ships | M0 hardening | fixed |
| `default_zoom_index` out of range crashed client boot | M0 hardening | fixed |
| Client imported `server/` class for the starter hull id | M0 hardening | fixed (moved to `world.starter_hull_id` in `data/tuning.json`) |
| Snapshot wire layout hand-decoded at five sites — add `ShipState.pack()/unpack()` | M1, first netcode task | open |
| RPC surface duplicated across both mains, sync'd only by comment; CI never connects a client | M1, with the new jump/dock RPCs | open |
| Net-feel tunables split-brained (`net.interp_delay_ms` unread; `BLEND_RATE`, `RECONCILE_BLEND` hardcoded) | M1, with the netcode work | open |
| `peer_id` doubles as entity id — blocks NPCs, sleepers, multi-room interest | M1, with the snapshot codec | open |
| Server names each ship's hull at spawn; client renders `HullDef.model` instead of a baked scene | M2, when a second ship exists | open |
| CI caching/dedup, action version bumps, `ship.gd`/`ShipView` naming | opportunistic | open |
