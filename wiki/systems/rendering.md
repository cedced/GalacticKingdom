# Rendering (3D to Isometric)

## Purpose
Present the 3D world as a fixed-angle isometric scene that reads clearly, runs on weak hardware, and supports a consistent art direction.

## Player-facing rules
- Camera never rotates. Zoom in and out only.
- Up on screen is "north" on the XZ plane after the 45 degree yaw. The galaxy map uses the same convention.

## Data model
- `IsoCamera` (`client/rendering/iso_camera.gd`, M0): `Camera3D`, projection orthographic, pitch/yaw/zoom levels from `data/tuning.json` (`render.*`), `size` driven by zoom level (mouse wheel), follows the player ship by position only.
- `client/rendering/iso.gd` (M0): `world_to_screen`, `screen_to_world_plane`, `camera_basis`. Implemented as pure static functions taking the camera transform/size/viewport as arguments so they test headless; `IsoCamera` supplies the live values.
- `client/rendering/grid.gdshader` (M0, demoted at M1): transparent line-only overlay above the backdrop, kept as a subtle motion/scale reference.
- `client/rendering/system_view.gd` (M1): builds the current system from `StarSystem` data — a backdrop plane (see `backdrop.gdshader`), billboard suns and planets from `data/bodies/*.json` via `body_catalog.gd`, and primitive station boxes / gate tori with `Label3D` names until the art pass.
- `client/rendering/backdrop.gdshader` (M1): fully procedural per-system space backdrop — near-black base, three star layers hashed from world position (resolution-independent, so sharp at any zoom, and static in space so they double as motion reference), and a faint fbm nebula haze tinted toward the system's star color. Seeded by the system's map position: unique sky per system, same sky every visit. A photo-crop approach was tried first and dropped twice: no crop of a fixed-resolution master survives gameplay zoom without pixelation. `assets/backgrounds/galaxy_full.jpg` is retained for the galaxy map screen.
- `client/rendering/body_billboard.gdshader` (M1): sprite quad that plays rotation sheets (`frames` > 1 at `fps`) or animates single stills by UV rotation; suns add counter-rotating screen-blended layers and a scale pulse; biome/star tints recolor luminance by `tint_mix`. See `assets/README.md` Bodies pipeline.
- **Nothing hides a ship** (M1 rule): suns, planets, and stations render as *ground decals*, not upright billboards — quads lying on the play plane, stretched by `1/sin(pitch)` along the camera axis so they project exactly like billboards, but carrying the ground's depth. A ship hovering at 0.5 therefore always wins the depth test, no matter where it flies. Gates are flat pad rings and primitive fallbacks stay under hover height for the same reason. Decals overlap each other by transparent-pass distance sorting, which in a fixed iso view is exactly "southern object in front".

## Algorithms
- Pixel look option: render to a `SubViewport` at internal resolution, `TextureFilter.NEAREST` upscale, optional palette post shader.
- Painterly option: native resolution, soft shadows, bloom on engines and weapons.
- Depth sorting is free via the depth buffer. Transparent effects use render priority.
- Visual height (hover bob, station towers) is presentation only and never affects `sim/`.

## Tuning knobs
`render.pitch_deg`, `render.internal_scale`, `render.zoom_levels`, `render.pixel_mode`.

## Interactions
- UI depends on `iso.gd` for targeting reticles, map pins, and damage numbers.

## Open questions
- Pixel vs. painterly. Decide by M1 with a side-by-side test scene.
- Whether ships tilt on turns (cosmetic roll) given the fixed camera.

## Test plan
- `world_to_screen` and `screen_to_world_plane` are inverses on the XZ plane.
- Performance scene: 50 ships, 200 projectiles, 60 fps on the reference integrated GPU.
