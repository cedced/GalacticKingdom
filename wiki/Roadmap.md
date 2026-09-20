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

## Asset sprint (between M1 and M2)

Decided 2026-09-20 (ADR-004, `wiki/systems/asset-pipeline.md`). One
focused pass so M2 onward can list asset rows instead of inventing a
process. Not a milestone: no playable-means row, no new gameplay. Order
matters; each step is its own small PR.

| # | Step | Done when |
|---|---|---|
| 1 | Manifest: `data/schemas/asset_manifest.schema.json`, `data/assets/manifest.json` seeded with the 11 existing rows + the wanted list, assets check in `tools/validate_data.py`, CI step, `tests/tools/` fixture test, `SOURCES.md` files deleted, `assets/README.md` layout updated | CI green with the gate on; an orphan file under `assets/` fails CI. **Done 2026-09-20.** |
| 2 | Higgsfield MCP connected (user signs in), first sprite through the full loop: lava planet, two image models A/B'd, house model recorded | `planet_lava` wired, screenshot verified |
| 3 | Ship pipeline proof: one concept sheet (trader hull) → bake-off Hunyuan3D local vs Higgsfield `image_to_3d`/`tripo_3d` → `tools/normalize_hull.py` (Blender 5.2 headless) → GLB beside `merchant_mk1` | Tool chosen and written into ADR-004, ADR flipped to Accepted; second hull renders in-game |
| 4 | M2 debt row: server names hull at spawn, client renders `HullDef.model` | Two different hulls visible in one system |
| 5 | M2 batch: two more hulls (light fighter, freighter), eight commodity icons, port master portrait, gas giant + ice planet, red dwarf + blue giant suns | All rows `wired`, contact sheet of icons reviewed |
| 6 | Rotation-sheet experiment on one planet via orbit video + `tools/frames_from_clip.py`; keep or kill | Decision recorded in the pipeline page; `assets/README.md` 32-angle target kept or removed |
| 7 | Envato: project "GalacticKingdom" registered, flow proven once (three music slots: safe space, lawless, docked; one UI font), `tools/import_audio.py` | Tracks play from a test scene, rows `wired` with registration date |
| 8 | Manifest `wanted` rows seeded for M3–M6 (table below) | Rows exist; nothing generated |

Deferred to their milestones: SFX generation (M3, needs `tools/import_audio.py` from step 7 and a test scene), VFX (M3), encrypted PCK on release exports (needs export presets, M2+).

### Per-milestone asset rows

Each milestone plan pulls these into `wanted` rows before its features start.

| Milestone | Assets |
|---|---|
| M2 Trade | 3 hulls (trader, light fighter, freighter), 8 commodity icons, ship-class icons, port master + starbase quartermaster portraits, port/starbase screen backdrops, 3 music slots, UI click/confirm/error SFX |
| M3 Combat | VFX sheets: laser bolt, cannon shell, small/large explosion, shield hit, warp in/out, engine flame; SFX: 2 weapons, 2 explosions, shield hit, warp, engine loop per class; 2–3 alien NPC hulls, 1 turret model, death/respawn screen art |
| M4 Planets | Planet surface view per biome (8 at most, tint-shared), building icons, colony screen art, invasion VFX, colony ambience loop |
| M5 Living world | Faction emblems, faction station variants (re-tint first), envoy portraits (Soul ID if recurring), quest board icons, event banners |
| M6 Social | Corp emblem template, rank medals (Rebang), leaderboard frame, chat channel icons |

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
| Snapshot wire layout hand-decoded at five sites — add `ShipState.pack()/unpack()` | M1, first netcode task | fixed |
| RPC surface duplicated across both mains, sync'd only by comment; CI never connects a client | M1, with the new jump/dock RPCs | fixed (shared `net/rpc_surface.gd` node + CI client-connect step) |
| Net-feel tunables split-brained (`net.interp_delay_ms` unread; `BLEND_RATE`, `RECONCILE_BLEND` hardcoded) | M1, with the netcode work | fixed (`net.view_blend_rate`, `net.reconcile_blend`; dead knob removed) |
| `peer_id` doubles as entity id — blocks NPCs, sleepers, multi-room interest | M1, with the snapshot codec | fixed |
| Server names each ship's hull at spawn; client renders `HullDef.model` instead of a baked scene | M2, when a second ship exists | open |
| CI caching/dedup, action version bumps, `ship.gd`/`ShipView` naming | opportunistic | open |
