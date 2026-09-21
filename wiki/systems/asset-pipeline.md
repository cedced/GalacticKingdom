# Asset Pipeline (generation, sourcing, intake)

Not a gameplay pillar. This page owns how art and audio get made, licensed,
and wired, so every pillar's milestone can list asset rows instead of
re-deciding the process. Policy is ADR-004; the hands-on how-to (style
block, prompts, tool commands) is `assets/ART_WORKFLOW.md`; file layout
and import rules are `assets/README.md`.

## Purpose

Turn "we need a lava planet / a second hull / a laser bolt / a click sound"
into a repeatable loop: a manifest row says what is wanted, Claude
generates candidates, the user approves, tooling normalizes and wires the
asset, CI proves it is licensed and referenced. The look stays uniform
because every diegetic asset passes through the same style block.

### Decisions from the 2026-09-20 planning round

| Question | Decision |
|---|---|
| Ship hulls | Hybrid: Gemini concept art → Hunyuan3D (local) → Blender normalization → GLB. ADR-003 (ships are 3D) holds. |
| Scope | Bodies, VFX, UI (icons/portraits/screens), audio (SFX + music). Ships via the row above. |
| License gate | Case by case: replace an unknown-license asset when the new one is licensed *and* better. No deadline. |
| Gemini produces | Nano Banana: still sprites, icons, portraits, ship concepts, marketing. Veo: orbit clips for rotation sheets, VFX clips → frames. |
| Who generates | Claude generates everything from `tools/gen/` against the Gemini API; the user curates. (Access question open, see below.) |
| Tooling | `data/assets/manifest.json` + schema + CI gate. |
| Cadence | One asset sprint before M2, then per-milestone asset rows. |
| Style mixing | Envato for non-diegetic only (music, VFX footage, textures, fonts, UI kits). |
| Gemini access | AI Studio API key + billing (`GEMINI_API_KEY` in `.env`). The user's Google AI Pro subscription covers the app only. No treg. Higgsfield dropped (it resells the same Google models). |
| Image-to-3D | Hunyuan3D locally on the RTX 3080; background removal with `rembg` locally. No cloud 3D. |
| Budget | Gemini API pay-per-image (≈ $0.05–0.15 Nano Banana 2, ≈ $0.13–0.24 Pro, Veo from ≈ $0.15/s). Sprint cap: open question. |
| Envato flow | Claude shortlists in the user's Chrome; user downloads to `assets/dump/envato/<slug>/`; Claude intakes. |
| Audio | SFX and music both from Envato Elements libraries. No generated audio. |

## Player-facing rules

- One visual style, everywhere the camera looks: pre-rendered painterly
  realism, upper-left key light, no outlines. A player should not be able
  to tell which asset came from which source.
- Ships read as distinct silhouettes at the default zoom; a hull's class
  (trader / fighter / freighter / alien) is recognizable before its name is.
- No asset carries text, watermarks, or borders; UI text is always live
  text, never baked into art.
- Every sound is short, dry, and mixed under the music; one engine loop
  per hull class, not per hull.

## Data model

### `data/assets/manifest.json` (schema: `data/schemas/asset_manifest.schema.json`)

One document, one `assets` array, one row per asset. A row covers a file
or a directory (a sprite-sheet folder, a hull folder, a whole UI pack).

| Field | Type | Meaning |
|---|---|---|
| `id` | string, snake_case | Matches the `data/` id where one exists (`planet_lava`, `merchant_mk1`, `sfx_laser_small`). |
| `kind` | enum | `ship`, `planet`, `sun`, `station`, `asteroid`, `derelict`, `vfx`, `icon`, `portrait`, `ui_pack`, `sfx`, `music`, `texture`, `font`, `background` |
| `path` | string | `res://assets/...` file or directory. Every file under `assets/` (except `dump/`, `*.import`, `*.md`, `.gitkeep`) must be covered by exactly one row's `path`, by prefix for directories. |
| `status` | enum | `wanted` → `generated` (candidates in `dump/gen/`) → `approved` (user picked one) → `wired` (in `assets/` and referenced from `data/` or a scene) → `replaced` (kept for history; `path` may be empty). |
| `milestone` | string | `M2`…`M6`, or `sprint`. |
| `source.provider` | enum | `gemini`, `hunyuan3d`, `envato`, `recraft`, `user`, `pack`, `derived` |
| `source.model` | string | Gemini model id (`gemini-3.1-flash-image`, `gemini-3-pro-image`, `veo-3.1-lite`, ...) or tool version (`hunyuan3d-2.1`). |
| `source.prompt` | string | Full prompt including the style block, or the Envato search that found it. |
| `source.seed`, `source.job_id`, `source.date` | | Reproduction handles. Gemini image models expose no seed, so `date` + `model` + `prompt` + the kept file are the record; `job_id` is for providers that have one (Veo operations). |
| `source.parent_id` | string | For `derived` rows: the manifest id this was cut/extracted from (a hull from a concept, a sheet from a clip). |
| `source.original_filename`, `source.item_url` | | Envato/pack traceability, replacing `SOURCES.md`. |
| `license.status` | enum | `verified`, `unknown`, `pending` |
| `license.terms` | string | One line: "Gemini API paid tier: outputs owned, no training, SynthID", "Envato Elements, registered to GalacticKingdom on <date>", "CC0", "unknown pack". |
| `license.registered_project` | string | Envato only. |
| `cost_usd` | number | What the row's generations cost, from the model's list price (candidates included). |
| `notes` | string | Why this one won, what was rejected. |

Rules:
- Schema first, then rows, then the validator (CLAUDE.md §7.4).
- The manifest replaced `assets/*/SOURCES.md` on 2026-09-20 (11 rows: 1
  hull, 8 bodies, 1 UI pack, 1 galaxy master; rejected candidates are
  named in the winner's `notes`, not given rows). The Wenrexa per-file
  rename log survives as `assets/ui/wenrexa_holo/RENAMES.md`.
- `wanted` rows are the shopping list. Adding a milestone's asset needs
  means adding `wanted` rows, nothing else.

### Folder additions to `assets/README.md`

```
assets/
  dump/
    gen/<manifest_id>/         Gemini candidates awaiting approval (never referenced)
    envato/<item_slug>/        user downloads + license certificate, awaiting intake
  ships/<hull_id>/
    <hull_id>.glb
    concept/                   approved concept views (front/side/top), source for image-to-3D
  vfx/<vfx_id>/
    sheet.png + sheet.json     same sheet.json shape as bodies (frames, frame_w/h, fps), plus "loop": bool
  ui/
    icons/<set>/<id>.png       commodity, ship-class, building, status icons; 128px master
    portraits/<id>.png         512px, transparent, bust only
  audio/
    sfx/<id>.ogg               mono, 44.1 kHz, at most 2 s unless a loop
    music/<id>.ogg             stereo, Envato, one row each
```

## Algorithms

Each asset kind is a loop of the same five steps; only the generator
call and the intake tool differ. Claude runs every step except *approve*.

```
want -> generate (tools/gen/ -> Gemini API) -> approve (user) -> intake (tools/) -> wire + verify (Claude)
```

| Kind | Generate | Intake | Verify |
|---|---|---|---|
| Planet / sun / station / asteroid / derelict | `tools/gen/gemini_image.py`: style block + per-asset prompt from `ART_WORKFLOW.md`; `rembg` on the pick for real alpha. 2 candidates per row; Nano Banana 2 vs Pro on the first row of each kind to pick the house model. | `tools/import_body_sprite.py` (exists) | in-game screenshot at min/max zoom; tint response; no fringe |
| Rotation sheet (experiment) | `tools/gen/veo_clip.py`: image-to-video from the approved still, "slow orbit, one full turn", black background. | `tools/frames_from_clip.py` (new): N evenly spaced frames → strip + `sheet.json` | terminator stays fixed; frame-to-frame jitter below one pixel at gameplay zoom; otherwise keep the UV-spin shader |
| VFX | `tools/gen/veo_clip.py`: 2–5 s clip on pure black, one effect, static camera (Veo Lite first; Standard only if Lite smears). | `tools/frames_from_clip.py`: fixed fps, crop to content, additive-ready (black = transparent) | plays in a test scene with additive blend; loops if `loop` |
| Ship hull | 1) concept sheet: front, side, top-down 3/4 views of one hull on black, same style block; 2) Hunyuan3D locally (multi-view input with the three views); 3) `tools/normalize_hull.py` via Blender 5.2 headless: Y-up, forward -Z, origin at center of mass, scale to class length, decimate to the polycount budget, bake to one material; export GLB. | `tools/normalize_hull.py` (new) | `tools/validate_data.py` model check; renders beside `merchant_mk1` under the iso camera; silhouette distinct at default zoom |
| Icon | Text-to-image, style block + "flat-lit icon of <thing>, centered, 20% padding"; generate the set in one pass so members match. | `tools/import_icon.py` (new): crop, resize to 128, alpha | contact-sheet screenshot of the whole set |
| Portrait | Nano Banana Pro, bust on black, neutral expression; for recurring characters reuse the approved portrait as a reference image (Nano Banana edits keep identity). | `tools/import_icon.py --portrait` | reads at 64px in the trade screen |
| SFX | Envato: Claude shortlists packs/clips per manifest row in the user's Chrome; user downloads with license. | `tools/import_audio.py` (new): trim silence, normalize to -16 LUFS, mono, OGG | plays from the test scene without clipping |
| Music | Envato: Claude shortlists 3–5 tracks per slot in the user's Chrome; user downloads with license, registers to "GalacticKingdom". | `tools/import_audio.py --music` | loops cleanly; sits under SFX |
| Envato non-audio (fonts, textures, footage) | Same shortlist/download flow. | manual, one row per item | — |

Ordering inside a batch: generate every candidate for the batch first, then
one approval pass, then intake. Never interleave, so the user reviews once.

## Tuning knobs

None in `data/tuning.json` yet. Audio bus levels arrive with M3 (`audio.*`).
Sheet playback speed lives in each `sheet.json` (`fps`).

## Interactions with other systems

- **Ships** (`wiki/systems/ships.md`): `data/ships/<id>.json` `model` points
  at the normalized GLB; the M2 debt row "server names hull at spawn, client
  renders `HullDef.model`" must land before a second hull is useful.
- **Rendering**: the style block encodes the scene's light direction; if
  the sun light ever moves, every sprite is wrong. Change both or neither.
- **Galaxy generator**: biome and star-type ids in `data/bodies/*.json`
  select sprites; new planets extend `biomes` coverage, not sim code.
- **UI** (`wiki/systems/ui.md`): icons and portraits use the holo theme's
  palette for accents; the Wenrexa pack stays the widget source.
- **Combat** (M3): VFX ids referenced from `data/weapons/*.json` once that
  schema exists; the manifest row exists first.
- **CI**: one new step runs the assets check; `dump/` is excluded from
  exports and from the check.

## Open questions

- Should release exports *fail* on `license.status: unknown`, or only print
  the report? Case by case for now (ADR-004 §6); revisit before the first
  public build.
- **Generation access (blocks step 2):** the user has Google AI Pro (app
  only). Either enable Gemini API billing (AI Studio key; sprint ≈ $10–20;
  Claude generates) or generate by hand in the Gemini app and drop PNGs in
  `dump/gen/` (free; the user generates). Decision pending.
- Sprint spend cap for the Gemini API once billing exists.
- Which Gemini image model becomes the house model per kind (Nano Banana 2
  vs Pro)? Answered by the first batch's A/B; recorded here.
- Gemini app outputs (if the manual fallback is used): confirm Gemini Apps
  Activity is off so prompts are not used for training, and record the
  app rather than an API model id in `source.model`.
- Rotation sheets: keep or kill after the one-planet experiment. If kill,
  remove the 32-angle target from `assets/README.md`.
- Hull polycount budgets per class (player ~5k, NPC ~2k from `README.md`):
  confirm they hold under the 50-ship performance target.
- Portrait consistency for recurring NPCs (port masters, faction envoys)
  at M5: is reference-image editing enough, or do we need a fixed
  character sheet per NPC?
- Encrypted PCK key management for release exports (M2+, needs export
  presets first).

## Test plan

- `tools/validate_data.py`: manifest validates; every `assets/` file is
  covered by exactly one row; every `wired` row's `path` exists; every
  `data/` reference to an asset resolves to a `wired` row.
- The validator is exercised by a `tests/tools/` Python test with a fixture
  tree containing an orphan file and a dangling row (no sim code involved,
  so no GUT test).
- Sprint exit: one asset of every kind above has gone through the full
  loop and is visible in-game or audible in a test scene. Verification
  screenshots are not committed (add `tests/client/screenshots/` to
  `.gitignore`), only referenced in the PR.
