# Asset Pipeline (generation, sourcing, intake)

Not a gameplay pillar. This page owns how art and audio get made, licensed,
and wired, so every pillar's milestone can list asset rows instead of
re-deciding the process. Policy is ADR-004; the hands-on how-to (style
block, prompts, tool commands) is `assets/ART_WORKFLOW.md`; file layout
and import rules are `assets/README.md`.

## Purpose

Turn "we need a lava planet / a second hull / a laser bolt / a click sound"
into a repeatable loop: a manifest row says what is wanted, Claude
generates candidates on the local GPU, the user approves, tooling
normalizes and wires the asset, CI proves it is licensed and referenced.
The look stays uniform because every diegetic asset passes through the
same style block and, once trained, the same style LoRA.

### Decisions from the 2026-09-20/21 planning round

| Question | Decision |
|---|---|
| Ship hulls | Hybrid: concept sheet (local model or Gemini app) → Hunyuan3D (local) → Blender normalization → GLB. ADR-003 (ships are 3D) holds. |
| Scope | Bodies, VFX, UI (icons/portraits/screens), audio (SFX + music). Ships via the row above. |
| License gate | Case by case: replace an unknown-license asset when the new one is licensed *and* better. No deadline. |
| Generators | **No pay-per-use APIs.** Local open-weight diffusion (SDXL / Z-Image-Turbo / FLUX.2 klein 4B, house model by bake-off) driven by Claude through ComfyUI; the Gemini app (Google AI Pro, already paid) as the user's manual channel for hero pieces. Higgsfield and the Gemini API were considered and dropped. |
| Fine-tuning | A style LoRA trained on our own approved sprites (manifest rows = dataset, prompts = captions), retrained as the library grows. |
| Who generates | Claude generates on the local GPU; the user curates. Hero pieces: the user generates in the Gemini app, Claude intakes. |
| Tooling | `data/assets/manifest.json` + schema + CI gate; ComfyUI workflows as JSON in `tools/gen/workflows/`; `tools/gen/models.json` for checkpoints and LoRAs. |
| Cadence | One asset sprint before M2, then per-milestone asset rows. |
| Style mixing | Envato for non-diegetic only (music, SFX, VFX footage, textures, fonts, UI kits). |
| Image-to-3D | Hunyuan3D locally on the RTX 3080; `rembg` locally for alpha. No cloud 3D. |
| Video | None generated. VFX = Godot particles/shaders first; rotation sheets = Blender turntable of a generated texture (experiment). |
| Budget | $0 in APIs. GPU time only; Claude states expected wall-clock before batches over ~1 h. |
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
| `path` | string | `res://assets/...` file or directory. Every file under `assets/` (except `dump/`, `source/`, `*.import`, `*.md`, `.gitkeep`) must be covered by exactly one row's `path`, by prefix for directories. |
| `status` | enum | `wanted` → `generated` (candidates in `dump/gen/`) → `approved` (user picked one) → `wired` (in `assets/` and referenced from `data/` or a scene) → `replaced` (kept for history; `path` may be empty). |
| `milestone` | string | `M2`…`M6`, or `sprint`. |
| `source.provider` | enum | `local` (ComfyUI on the reference machine), `gemini_app` (user, Google AI Pro), `hunyuan3d`, `envato`, `recraft`, `user`, `pack`, `derived` |
| `source.model` | string | Checkpoint plus LoRA as named in `tools/gen/models.json` (`sdxl-base-1.0 + gk_style_v1`), the Gemini app model name, or a tool version (`hunyuan3d-2.1`). |
| `source.workflow` | string | `local` rows: the ComfyUI workflow JSON under `tools/gen/workflows/` that produced it. |
| `source.prompt` | string | Full prompt including the style block, or the search that found an Envato item. Doubles as the LoRA caption. |
| `source.seed`, `source.date` | | Reproduction handles. Local models honor the seed; the Gemini app has none, so `date` + `model` + the kept file are its record. |
| `source.parent_id` | string | For `derived` rows: the manifest id this was cut/extracted from (a hull from a concept, a sheet from a texture). |
| `source.original_filename`, `source.item_url` | | Envato/pack traceability, replacing `SOURCES.md`. |
| `license.status` | enum | `verified`, `unknown`, `pending` |
| `license.terms` | string | One line: "SDXL OpenRAIL++-M, outputs unrestricted", "Z-Image-Turbo Apache 2.0", "Envato Elements, registered to GalacticKingdom on <date>", "CC0", "unknown pack". |
| `license.registered_project` | string | Envato only. |
| `notes` | string | Why this one won, what was rejected. |

Rules:
- Schema first, then rows, then the validator (CLAUDE.md §7.4).
- The manifest replaced `assets/*/SOURCES.md` on 2026-09-20 (11 rows: 1
  hull, 8 bodies, 1 UI pack, 1 galaxy master; rejected candidates are
  named in the winner's `notes`, not given rows). The Wenrexa per-file
  rename log survives as `assets/ui/wenrexa_holo/RENAMES.md`.
- `wanted` rows are the shopping list. Adding a milestone's asset needs
  means adding `wanted` rows, nothing else.

### `tools/gen/models.json`

Every local checkpoint and LoRA: name, family (`sdxl`, `z-image`,
`flux2-klein`), source URL, license, sha256, local path under
`assets/source/`, and for LoRAs the training config and the manifest ids
it was trained on. Nothing under `assets/source/` is committed or exported;
this file is what lets a fresh machine rebuild it.

### Folder additions to `assets/README.md`

```
assets/
  dump/
    gen/<manifest_id>/         candidates awaiting approval (local or Gemini app; gitignored)
    envato/<item_slug>/        user downloads + license certificate, awaiting intake (gitignored)
  source/                      gitignored, never exported, skipped by the coverage check
    models/                    checkpoints (sha256 in tools/gen/models.json)
    loras/                     trained style LoRAs
    datasets/<lora_name>/      captioned training sets built from the manifest
  ships/<hull_id>/
    <hull_id>.glb
    concept/                   approved concept views (front/side/top), source for Hunyuan3D
  vfx/<vfx_id>/
    sheet.png + sheet.json     only for effects a shader cannot do; same sheet.json shape as bodies plus "loop": bool
  ui/
    icons/<set>/<id>.png       commodity, ship-class, building, status icons; 128px master
    portraits/<id>.png         512px, transparent, bust only
  audio/
    sfx/<id>.ogg               mono, 44.1 kHz, at most 2 s unless a loop
    music/<id>.ogg             stereo, Envato, one row each
```

## Algorithms

Each asset kind is a loop of the same five steps; only the generator and
the intake tool differ. Claude runs every step except *approve* (and
*generate* when the channel is the Gemini app).

```
want -> generate (tools/gen/comfy_generate.py, or the user in the Gemini app) -> approve (user) -> intake (tools/) -> wire + verify (Claude)
```

| Kind | Generate | Intake | Verify |
|---|---|---|---|
| Planet / sun / station / asteroid / derelict | `comfy_generate.py --id <row>`: style block + per-asset prompt from `ART_WORKFLOW.md`, house model + style LoRA, 3 seeds; `rembg` on the pick for real alpha. | `tools/import_body_sprite.py` (exists) | in-game screenshot at min/max zoom; tint response; no fringe |
| Rotation sheet (experiment) | Generate an equirectangular planet texture (local, "seamless equirectangular map of a <biome> planet"); `tools/render_turntable.py` in Blender headless: UV sphere, fixed upper-left light, N angles. | `render_turntable.py` writes `sheet.png` + `sheet.json` directly | terminator fixed by construction; compare against the UV-spin shader at gameplay zoom; keep or kill |
| VFX | Godot `GPUParticles3D` + shaders in `client/rendering/vfx/` (M3). Sprite sheet only if a shader cannot do it: local video model (Wan 2.2 5B / LTX) or a Blender sim, then `tools/frames_from_clip.py`. | `tools/frames_from_clip.py` (only if needed) | plays in a test scene with additive blend; loops if `loop` |
| Ship hull | 1) concept sheet: front, side, top-down 3/4 views of one hull on black — local with the style LoRA, or the Gemini app for hero hulls; 2) Hunyuan3D locally (multi-view); 3) `tools/normalize_hull.py` via Blender 5.2 headless: Y-up, forward -Z, origin at center of mass, scale to class length, decimate to the polycount budget, bake to one material; export GLB. | `tools/normalize_hull.py` (new) | `tools/validate_data.py` model check; renders beside `merchant_mk1` under the iso camera; silhouette distinct at default zoom |
| Icon | Local, style block + "flat-lit icon of <thing>, centered, 20% padding"; one seed series for the whole set so members match. | `tools/import_icon.py` (new): crop, resize to 128, alpha | contact-sheet screenshot of the whole set |
| Portrait | Gemini app (hero) or local; bust on black, neutral expression; recurring characters reuse the approved portrait as an img2img/reference input. | `tools/import_icon.py --portrait` | reads at 64px in the trade screen |
| SFX | Envato: Claude shortlists packs/clips per manifest row in the user's Chrome; user downloads with license. | `tools/import_audio.py` (new): trim silence, normalize to -16 LUFS, mono, OGG | plays from the test scene without clipping |
| Music | Envato: Claude shortlists 3–5 tracks per slot; user downloads with license, registers to "GalacticKingdom". | `tools/import_audio.py --music` | loops cleanly; sits under SFX |
| Envato non-audio (fonts, textures, footage) | Same shortlist/download flow. | manual, one row per item | — |

Ordering inside a batch: generate every candidate for the batch first, then
one approval pass, then intake. Never interleave, so the user reviews once.

### Style LoRA routine

1. `tools/gen/build_dataset.py --lora gk_style_vN`: every `wired` row of a
   diegetic kind whose provider is `local`, `recraft`, or `user` becomes one
   image + caption (the row's prompt minus the style block, plus the
   trigger word `gkstyle`). Gemini-app rows are excluded until the terms
   question below is settled.
2. `tools/gen/train_lora.py --lora gk_style_vN`: kohya-ss (SDXL) or
   ai-toolkit (Z-Image / FLUX.2 klein) with the config recorded in
   `models.json`; 768 px on the 10 GB card, ~1 h.
3. A/B on two held-out prompts with and without the LoRA; the user picks;
   the winner's name goes into the default workflow.
4. Retrain when a milestone adds roughly 20 approved sprites.

## Tuning knobs

None in `data/tuning.json`. Generation parameters (steps, CFG, resolution,
LoRA weight) live in the workflow JSON files; sheet playback speed lives in
each `sheet.json` (`fps`).

## Interactions with other systems

- **Ships** (`wiki/systems/ships.md`): `data/ships/<id>.json` `model` points
  at the normalized GLB; the M2 debt row "server names hull at spawn, client
  renders `HullDef.model`" must land before a second hull is useful.
- **Rendering**: the style block encodes the scene's light direction; if
  the sun light ever moves, every sprite is wrong. Change both or neither.
  VFX shaders live in `client/rendering/`.
- **Galaxy generator**: biome and star-type ids in `data/bodies/*.json`
  select sprites; new planets extend `biomes` coverage, not sim code.
- **UI** (`wiki/systems/ui.md`): icons and portraits use the holo theme's
  palette for accents; the Wenrexa pack stays the widget source.
- **Combat** (M3): particle/shader VFX referenced from `data/weapons/*.json`
  once that schema exists.
- **CI**: the validate-data job runs the assets check; `dump/` and
  `source/` are excluded from exports and from the check.

## Open questions

- Should release exports *fail* on `license.status: unknown`, or only print
  the report? Case by case for now (ADR-004 §9); revisit before the first
  public build.
- House model: SDXL (safe, fast, well-trodden LoRA path on 10 GB) vs
  Z-Image-Turbo (stronger prompt adherence, distilled, LoRA training
  borderline on 10 GB) vs FLUX.2 klein 4B. Answered by the step 2 bake-off;
  recorded here with the seeds used.
- Gemini-app outputs as LoRA training data: allowed under Google's consumer
  terms? Until confirmed they are assets only, not training data.
- Gemini-app outputs as game assets: confirm the consumer terms (ownership,
  commercial use) once and record them in the rows' `license.terms`.
- Rotation sheets: keep or kill after the turntable experiment. If kill,
  remove the 32-angle target from `assets/README.md`.
- Hull polycount budgets per class (player ~5k, NPC ~2k from `README.md`):
  confirm they hold under the 50-ship performance target.
- Disk: checkpoints + LoRAs + datasets under `assets/source/` will reach
  tens of GB; confirm the drive and whether they live on another one via
  the `.env` path.
- Encrypted PCK key management for release exports (M2+, needs export
  presets first).

## Test plan

- `tools/validate_data.py`: manifest validates; every `assets/` file is
  covered by exactly one row; every `wired` row's `path` exists; every
  `data/` reference to an asset resolves to a `wired` row; `dump/` and
  `source/` are skipped.
- The validator is exercised by a `tests/tools/` Python test with a fixture
  tree containing an orphan file and a dangling row (no sim code involved,
  so no GUT test).
- `comfy_generate.py` is deterministic: same workflow + prompt + seed on the
  same machine reproduces the kept candidate byte-for-byte (checked once per
  house-model change, not in CI).
- Sprint exit: one asset of every kind above has gone through the full
  loop and is visible in-game or audible in a test scene. Verification
  screenshots are not committed (add `tests/client/screenshots/` to
  `.gitignore`), only referenced in the PR.
