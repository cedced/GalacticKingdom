# assets/

Source and import rules for every art asset in GalacticKingdom. Read this before adding, moving, or renaming anything under `assets/`. `CLAUDE.md` wins on any conflict.

Note for `CLAUDE.md`: `assets/` was added to the Section 3 repository layout at M0.

## Purpose

`assets/` holds the raw and cleaned art that `client/` loads. Nothing in `sim/` or `server/` may reference this directory; the server is headless and never needs art. Gameplay data (hull stats, weapon numbers) stays in `data/*.json`. Data files point at asset paths; asset files never carry gameplay values.

## Current state: `assets/dump/`

`dump/` is an unsorted staging area. Nothing in it is referenced by a scene yet. Contents as of this file:

| Item | Location | Notes |
|---|---|---|
| Spaceship pack | `dump/3D_spaceships_pack/` | Numbered `.glb` files plus `.gif` previews. `34.glb` was moved out at M0 as `ships/merchant_mk1/` (see `ships/SOURCES.md`); the rest awaits M2 triage. |

The planet, sun, and station PNGs moved out at M1 into `bodies/` as single-frame sheets (see `bodies/SOURCES.md`); the client animates the sphere stills with shader UV rotation until multi-angle sources exist, while the 3/4-angle station renders stay static. Station sprites cover both station kinds via `station_kinds` in `data/bodies/*.json`.

The galaxy image moved to `backgrounds/galaxy_full.jpg` at M0. It is a 23 MB JPEG (not PNG as this file originally said), under the ~50 MB threshold, so plain git is fine — no LFS.

Rule: `dump/` is read-only in spirit. Move things out, never build on them in place. Delete `dump/` once it is empty.

## Target layout

```
assets/
  README.md                 you are here
  dump/                     staging, delete when empty
  ships/
    <hull_id>/
      <hull_id>.glb         one hull per folder, name matches data/ships/<hull_id>.json
      <hull_id>.import      committed, Godot import settings
      textures/             only if the glb uses external textures
  bodies/
    planets/
      <planet_id>/
        sheet.png           rotation sprite sheet (see Bodies pipeline)
        sheet.json          frame count, size, degrees per frame
    suns/
      <sun_id>/
        sheet.png
        sheet.json
    stations/
      <station_id>/         ports and starbases; same sheet convention,
        sheet.png           but 3/4-angle renders stay static (no UV spin)
        sheet.json
  backgrounds/
    galaxy_full.jpg         master image, kept once, never edited
    systems/
      <region_id>.png       crops used as skybox/backdrop per region
  ui/                       icons, cursors, HUD atlas (empty until M1)
  vfx/                      projectile, explosion, warp textures (empty until M3)
  audio/                    empty until scoped
```

## Naming conventions

- Folders and files: `snake_case`, ASCII only, no spaces, no version suffixes like `_final2`.
- IDs match their `data/` counterpart exactly. If `data/ships/merchant_mk1.json` exists, the model is `assets/ships/merchant_mk1/merchant_mk1.glb`.
- Sprite sheets are always `sheet.png` + `sheet.json` inside an ID folder. Do not encode frame counts in filenames.
- Never keep the pack's original numbering (`34.glb`) once an asset is assigned. Numbers say nothing and will collide.
- Keep a `SOURCES.md` next to any third-party pack with the pack name, author, license, and original filename to ID mapping. This is how we trace `34.glb` back later.

## Ships pipeline

Format is GLB (Godot 4 native glTF import, see `CLAUDE.md` Section 2).

1. Pick a hull from `dump/3D_spaceships_pack/`. Record `original -> hull_id` in `assets/ships/SOURCES.md`.
2. Copy to `assets/ships/<hull_id>/<hull_id>.glb`. Do not rename inside `dump/`.
3. Open in Godot, check: Y-up, forward is -Z, origin at the hull's center of mass, scale so the starter ship is roughly 1 unit long. Fix in Blender and re-export if wrong; do not fix with transforms in the scene tree.
4. In the import dock: set to Scene, keep materials, no lightmap UVs. If the pack ships a texture set, keep it embedded.
5. Add `data/ships/<hull_id>.json` with `"model": "res://assets/ships/<hull_id>/<hull_id>.glb"`. Schema first (`CLAUDE.md` Section 7.4).
6. Confirm it renders under the iso camera in `client/` with the pixel-snap shader on and off.

Starter ship: done at M0. `34.glb` is now `assets/ships/merchant_mk1/merchant_mk1.glb` with `data/ships/merchant_mk1.json` (schema: `data/schemas/ship.schema.json`). Measured headless: ~1.0 unit long, Y-up, XZ-centered origin — meets step 3 except the origin sits at the hull base, not the vertical center of mass; acceptable until a Blender pass. Forward-axis (-Z) and material check in the editor is still pending. Only this hull is required for M0 and M1. Triage the rest of the pack at M2 when the starbase shop needs a lineup.

Triage checklist for the remaining hulls: poly count under ~5k tris for player ships, ~2k for NPC fodder, clean silhouette at iso zoom, and no baked-in weapons that the loadout system would fight with.

## Bodies pipeline (planets and suns)

Planets and suns are 2D billboards in the 3D scene, not meshes. Cheaper, and the iso camera never changes pitch so a rotating sprite sheet reads as a sphere.

1. From the source render, export N angles at fixed increments around the vertical axis. Target N = 32 for planets (11.25 degrees per frame), N = 16 for suns (they mostly need a slow shimmer, not a visible spin). Keep the light direction fixed while rotating the body so the terminator stays put.
2. Pack into a horizontal strip `sheet.png`, power-of-two width if possible. Frame size is the same for every frame in the sheet.
3. Write `sheet.json`:

```json
{ "frames": 32, "frame_w": 256, "frame_h": 256, "deg_per_frame": 11.25, "fps": 8 }
```

4. Import as Texture2D, nearest filter if we go pixel, linear if painterly (open art decision, do not commit to either here).
5. Add the body to `data/bodies/<planet_id>.json` pointing at the folder (schema: `data/schemas/body_sprite.schema.json`). Biome/star-type coverage, spin speed, and tint strength live there, not here.

Two planets and one sun cover M0 and M1. More biomes get added when `sim/planets/` needs them (M4). Do not hand-draw a sprite per biome; prefer tinting and overlays on a small base set.

Interim state (M1): the three sprites are stored as **1-frame sheets** and animated by `client/rendering/body_billboard.gdshader` — UV rotation for spin, a counter-rotating screen-blended second layer for the sun's corona, luminance recoloring for biome/star tints. The shader already plays multi-frame sheets at `fps`, so real rotation sheets drop in by replacing `sheet.png`/`sheet.json` only.

## Backgrounds pipeline (galaxy image)

`dump/<galaxy>.png` becomes `assets/backgrounds/galaxy_full.png`. It is the master and is never edited.

Use for:

- Galaxy map UI (M1): downscaled copy for the map screen.
- Per-system backdrop: crop a region, blur or darken, use as the skybox or a far parallax layer behind the play plane.

Rules:

- In-system backdrops went **fully procedural at M1** (`client/rendering/backdrop.gdshader`: black base + hashed star layers + faint noise haze, seeded per system). Photo crops of the master were tried twice and always pixelated at gameplay zoom — a fixed-resolution image cannot back a zoomable plane. The `tools/backdrop_crop.py` + `backdrop_mapping.json` plan is dead for this purpose.
- The master's remaining role is the **galaxy map screen** (a downscaled copy as the map background) — still open, see To do.
- If pre-cropped files ever return for some other use: generated by tool, never by hand, 2048x2048 max, deterministic from seed + system id.
- If the master is above ~50 MB, store it with Git LFS. (Checked at M0: 23 MB JPEG, plain git.)

## Import settings and git

- Commit `.import` files for anything under `assets/`. They are part of the asset.
- Never commit `.godot/imported/`. Already in `.gitignore`, verify.
- Do not put `.blend`, `.psd`, or other working files here. Put them in `assets/source/` and add that folder to the export exclude list, or keep them outside the repo.

## Open questions

- Pixel look vs. painterly look. Blocks filter settings on every import. Tracked in `wiki/systems/rendering.md`.
- License terms of `3D_spaceships_pack` AND the body sprites (`bodies/SOURCES.md`). Confirm redistribution is allowed before anything ships in a build.
- ~~Whether suns need rotation at all or a shader-driven shimmer is enough~~ — resolved M1: the two-layer counter-rotating shader shimmer reads well; real sheets remain optional polish.
- The body sprites are single-angle renders. True rotation sheets need N-angle exports; find the original 3D sources or a tool to re-render them. The shader-spin interim is acceptable until then.
- The 23 MB master currently has no runtime consumer (backdrops are procedural). Exclude it from exports, or replace it with a downscaled map-screen copy, when the export pipeline exists.
- `merchant_mk1.glb` origin is at the hull base, not the center of mass; fix in Blender if it ever matters for roll/pitch cosmetics.

## To do

- [x] Add `assets/` to `CLAUDE.md` Section 3 layout (M0)
- [x] Create `assets/ships/SOURCES.md` with `34.glb -> merchant_mk1` (M0; license still unknown, see Open questions)
- [x] Move `merchant_mk1.glb` per Ships pipeline (M0; editor visual check of forward axis and materials pending)
- [x] Bodies on screen for M1 (single-frame sheets + shader animation; true N-angle sheets still blocked on sources, see Open questions)
- [x] Move galaxy master, decide on LFS (M0: 23 MB JPEG, plain git, no LFS)
- [x] Per-system backdrops (M1: fully procedural shader; photo crops dropped, see Backgrounds pipeline)
- [ ] Downscaled copy of the master as the galaxy map screen's background (the master's only remaining consumer; until then it ships unused)
- [ ] Delete `dump/` when empty (only `3D_spaceships_pack/` remains, awaiting M2 triage)
