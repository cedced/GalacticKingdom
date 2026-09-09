# Rendering (3D to Isometric)

## Purpose
Present the 3D world as a fixed-angle isometric scene that reads clearly, runs on weak hardware, and supports a consistent art direction.

## Player-facing rules
- Camera never rotates. Zoom in and out only.
- Up on screen is "north" on the XZ plane after the 45 degree yaw. The galaxy map uses the same convention.

## Data model
- `IsoCamera` (`client/rendering/iso_camera.gd`, M0): `Camera3D`, projection orthographic, pitch/yaw/zoom levels from `data/tuning.json` (`render.*`), `size` driven by zoom level (mouse wheel), follows the player ship by position only.
- `client/rendering/iso.gd` (M0): `world_to_screen`, `screen_to_world_plane`, `camera_basis`. Implemented as pure static functions taking the camera transform/size/viewport as arguments so they test headless; `IsoCamera` supplies the live values.
- `client/rendering/grid.gdshader` (M0 only): faint XZ reference grid so motion is visible in an empty system; replaced by real backdrops once the art direction lands.
- `client/rendering/system_view.gd` (M1): builds the current system from `StarSystem` data — emissive sphere star, biome-tinted planet spheres, station boxes, gate tori with `Label3D` destination names. Deliberately procedural primitives: nothing here survives the art pass, so no generation logic leaks into scenes.

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
