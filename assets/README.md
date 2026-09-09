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
| Planet sprites | `dump/` | 2 PNGs, single angle each. Cannot become rotation sheets without multi-angle source renders (see Open questions). |
| Sun sprite | `dump/` | 1 PNG, single angle. Same limitation. |

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
5. Add the body to `data/bodies/<planet_id>.json` pointing at the folder. Biome data lives in `data/`, not here.

Two planets and one sun cover M0 and M1. More biomes get added when `sim/planets/` needs them (M4). Do not hand-draw a sprite per biome; prefer tinting and overlays on a small base set.

## Backgrounds pipeline (galaxy image)

`dump/<galaxy>.png` becomes `assets/backgrounds/galaxy_full.png`. It is the master and is never edited.

Use for:

- Galaxy map UI (M1): downscaled copy for the map screen.
- Per-system backdrop: crop a region, blur or darken, use as the skybox or a far parallax layer behind the play plane.

Rules:

- Crops are generated by `tools/backdrop_crop.py` (to write), not by hand. Input: seed, system ID, master image. Output: `assets/backgrounds/systems/<region_id>.png`. Same seed, same crop, so this stays deterministic like the rest of generation (`CLAUDE.md` Section 5).
- Map galaxy graph coordinates to pixel coordinates in the master image once, store the mapping in `data/galaxy/backdrop_mapping.json`. That way a system near the core gets a bright crop and a rim system gets a dark one.
- Ship crops at 2048x2048 max. The master stays out of exported builds (add to `export_presets` exclude).
- If the master is above ~50 MB, store it with Git LFS. Check before the first commit.

## Import settings and git

- Commit `.import` files for anything under `assets/`. They are part of the asset.
- Never commit `.godot/imported/`. Already in `.gitignore`, verify.
- Do not put `.blend`, `.psd`, or other working files here. Put them in `assets/source/` and add that folder to the export exclude list, or keep them outside the repo.

## Open questions

- Pixel look vs. painterly look. Blocks filter settings on every import. Tracked in `wiki/systems/rendering.md`.
- License terms of `3D_spaceships_pack`. Confirm redistribution is allowed before it ships in a build.
- Whether suns need rotation at all or a shader-driven shimmer is enough.
- The planet and sun sprites in `dump/` are single-angle renders. The Bodies pipeline needs N-angle exports; find the original 3D sources or a tool to re-render them, otherwise these sprites are unusable for sheets.
- `merchant_mk1.glb` origin is at the hull base, not the center of mass; fix in Blender if it ever matters for roll/pitch cosmetics.

## To do

- [x] Add `assets/` to `CLAUDE.md` Section 3 layout (M0)
- [x] Create `assets/ships/SOURCES.md` with `34.glb -> merchant_mk1` (M0; license still unknown, see Open questions)
- [x] Move `merchant_mk1.glb` per Ships pipeline (M0; editor visual check of forward axis and materials pending)
- [ ] Export planet and sun angle sets, build sheets and `sheet.json` (blocked: single-angle sources, see Open questions; needed by M1)
- [x] Move galaxy master, decide on LFS (M0: 23 MB JPEG, plain git, no LFS)
- [ ] Write `tools/backdrop_crop.py` and add it to `CLAUDE.md` Section 11 (M1)
- [ ] Delete `dump/` when empty
