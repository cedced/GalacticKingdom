# AI art workflow

How we generate game art with Google's Gemini models, repeatably. Companion
to `README.md` (which owns file layout and import rules); this file owns
the *process*. Policy and the reasons behind it are ADR-004; the data
model and per-kind loops are `wiki/systems/asset-pipeline.md`.

Since 2026-09-20: **Claude generates, the human curates.** Claude runs
`tools/gen/gemini_image.py` / `tools/gen/veo_clip.py` against the Gemini
API (`GEMINI_API_KEY` in `.env`, never committed), drops candidates in
`assets/dump/gen/<manifest_id>/`, you pick one (or none), Claude runs
intake, wiring, and in-game verification. Claude asks before every API
batch with a list-price estimate.

Manual mode (sprint step 2, and any time the API is off): you paste the
style block + asset prompt into the Gemini app (Nano Banana is included in
Google AI Pro; pick Nano Banana Pro from the model picker when it is
offered), download the PNGs into `assets/dump/gen/<manifest_id>/`, and
say which model made which file. Steps 3-6 are identical. Turn off Gemini
Apps Activity first so prompts are not used for training. `dump/gen/` is
gitignored: the manifest row is the record, not the candidates.

## The loop at a glance

```
1. Want        a `wanted` row in data/assets/manifest.json (id, kind, milestone)
2. Generate    Claude: style block + per-asset prompt -> tools/gen/ (Gemini API) -> dump/gen/<id>/   (2-3 candidates)
3. Approve     you: name the winner, or say "none, retry with <change>"
4. Intake      Claude: tools/import_*.py -> assets/<kind>/<id>/
5. Wire        Claude: data/<kind>/<id>.json + manifest row -> status: wired, source, license
6. Verify      Claude: validate_data, Godot --import, in-game screenshot or test-scene playback
```

Batches: Claude generates every candidate for a batch first, then asks
for one approval pass, then intakes. You review once per batch.

Envato Elements items (music, SFX, fonts, textures, VFX footage) skip step 2:
Claude shortlists in your Chrome, you download into
`assets/dump/envato/<item_slug>/` with the license certificate, registered
to the Envato project "GalacticKingdom"; steps 4-6 are the same.

## 1. Style round — identifying the style

**Settled 2026-09-09: pre-rendered painterly realism** (recorded in
`wiki/systems/rendering.md`; also resolves pixel-vs-painterly — native
resolution, linear filtering). The incumbent renders already match;
nothing needs regenerating.

Re-run a style round only if the direction is ever reopened: same test
subject in 2–4 candidate styles, `tools/style_board.gd` for an in-game
side-by-side, record the new decision in the rendering wiki, update the
Style block below.

## 2. The style block

Goes at the front of EVERY image and video prompt, then the asset prompt.

```
STYLE: photorealistic pre-rendered sci-fi art, detailed surfaces,
subtle color grading, physically plausible materials, no outlines.
Single centered object on a plain pure black background, nothing else
in frame (true transparency also fine if the tool supports it).
Square canvas, 2048x2048 or larger.
Lit from the upper left, neutral white key light, deep shadows.
No text, no watermark, no frame, no border, no drop shadow,
no lens flare, no background stars or nebulae.
Muted deep-space palette; accent colors allowed on the object itself.
```

A pure black background is fine: intake keys it out, and `rembg` (local,
open source) produces real alpha on the approved pick when keying leaves
fringes.

Hard technical constraints baked into that block (do not relax them):
- **Transparent background** — the intake tool crops by alpha; a baked
  background ruins that and the in-game compositing.
- **Upper-left lighting** — matches the scene's sun light and the
  backdrop stars' highlight direction; a mismatched sprite looks pasted.
- **No frames/borders** — border pixels smear across the sprite through
  mipmapping (we have been bitten twice).

House model per kind: unknown until the first batch. Claude runs the
first row of each kind through Nano Banana 2 (`gemini-3.1-flash-image`,
cheap) and Nano Banana Pro (`gemini-3-pro-image`, 2K/4K, stronger
detail), you pick, the winner is recorded in
`wiki/systems/asset-pipeline.md` and reused for that kind.

## 3. Per-asset prompts

Append after the style block. View angle is the one rule that differs
by type — get it wrong and the sprite cannot sit in the world.

| Asset type | View angle (critical) | Prompt seed | Notes |
|---|---|---|---|
| Planet | **Straight-on view of the full disc** (looks like a photo of a globe) | "A single <biome> planet, full disc, <palette/features>" | Straight-on spheres are the only sprites the UV-spin animation works on. One sprite can cover several biomes via tint (`tint_mix`), so prioritize distinct looks: lava, ringed gas giant, ice, jungle. |
| Sun | Straight-on full disc with corona | "A single star, full disc with flame corona licking outward, <color>" | The corona shader widens the fire ring (`corona_spread`) and tints per star type — one good sun covers many. |
| Station | **3/4 view from ~30° above** (matches the iso camera pitch) | "A <description> space station, three-quarter view from slightly above" | Static in game (no spin). One per station kind; faction variants later. |
| Asteroid field / derelict | 3/4 view from ~30° above | "A loose cluster of asteroids" / "a wrecked derelict freighter hull" | Done 2026-09-09 (Recraft). |
| Rotation sheet (experiment) | Veo image-to-video from the approved still | "Slow orbit around the object, one full turn, camera level, object centered, black background" | `tools/frames_from_clip.py --frames 32` -> sheet. Keep only if the terminator stays put and frames do not jitter; otherwise the UV-spin shader stays. |
| Ship concept | **Three views on one canvas**: front, side, top-down 3/4 | "Concept sheet of a single <class> spaceship: front view, side view, three-quarter top view, same ship, same lighting, evenly spaced on black" | Feeds Hunyuan3D (local, multi-view). Silhouette first: a trader is boxy, a fighter is a wedge, a freighter is long. No baked weapons (the loadout system fights them). |
| VFX clip | Static camera, effect only | "A single <effect> on pure black, static camera, 3 seconds, starts and ends dark" (or "seamless loop" for shields/engines) | Veo (Lite first) on black, then `tools/frames_from_clip.py --fps 24`. Additive blend in-game, so black is free transparency. |
| Icon | Flat, frontal | "Flat-lit icon of <thing>, centered, 20% padding, single object" | Generate a whole set in one sitting so members match; 128px master after intake. |
| Portrait | Bust, frontal, neutral | "Portrait of a <role>, bust, neutral expression, soft key light" | Nano Banana Pro. Recurring characters: pass the approved portrait as a reference image on later edits. |
| SFX | — (Envato) | Envato search terms recorded in the manifest row ("sci-fi laser short", "ui click hologram") | Never generated. `tools/import_audio.py` trims, normalizes to -16 LUFS, mono OGG. |
| Music | — (Envato) | Envato search terms recorded in the manifest row | Never generated. |

Wanted list lives in the manifest (`status: wanted`), not here. Seed it
with, in rough value order: lava planet, ringed gas giant, ice planet, red
dwarf sun, blue giant sun, three M2 hulls (trader, light fighter,
freighter), the eight commodity icons, port master portrait, three music
slots (safe space, lawless, docked).

## 4. Intake

```
python tools/import_body_sprite.py <source.png> --kind planet|sun|station --id <id>   # exists
python tools/frames_from_clip.py <clip.mp4> --id <id> --frames 32 | --fps 24          # planned
python tools/normalize_hull.py <mesh.glb|obj> --id <hull_id> --class trader           # planned, Blender 5.2 headless
python tools/import_icon.py <png> --set commodities --id <id> [--portrait]            # planned
python tools/import_audio.py <wav|mp3> --id <id> [--music]                            # planned
```

`import_body_sprite.py` crops to a content-centered square, rewrites
transparent pixels to black (mipmap hygiene), caps at 2048, writes
`assets/bodies/<kind>s/<id>/sheet.png` + `sheet.json`, and prints the
`data/bodies/<id>.json` stub to fill in (coverage, tint, spin). The
planned tools follow the same shape: one input, one id, files land in
their `assets/` folder, a stub or manifest patch is printed.

## 5. Provenance and licensing

Every asset is a row in `data/assets/manifest.json` (schema-validated, CI
fails on an `assets/` file without a row). The row records provider,
model, full prompt, date, cost, and license status (no seed: Gemini image
models do not expose one).
The old per-folder `SOURCES.md` tables are migrated into it and deleted.

License facts as of 2026-09-20 (re-check before the first public build):
- Gemini API, paid tier: outputs are the user's, commercial use allowed,
  Google does not train on prompts or outputs, every output carries an
  invisible SynthID watermark. The free tier and the consumer Gemini app
  may use content for training unless activity settings say otherwise.
- Envato Elements: per-project registration ("GalacticKingdom"), license
  survives subscription end for completed projects, items must not be
  extractable as standalone assets from the end product (release exports
  use an encrypted PCK).
- Unknown-license placeholders (ship pack, three user renders) are
  replaced case by case when a licensed asset beats them, not on a
  deadline (ADR-004).

## 6. Verification checklist (Claude runs this)

- `python tools/validate_data.py` green (schemas + manifest coverage);
  Godot `--import` clean.
- Sprites: in-game screenshot reads at min and max zoom, sits on the
  backdrop without fringes, tint response sane, doesn't clash with
  neighbors. Nothing renders above ship hover height (rendering wiki rule).
- Hulls: renders beside `merchant_mk1` under the iso camera at the same
  scale convention; forward is -Z; silhouette distinct at default zoom.
- VFX: plays in the test scene with additive blend; loops cleanly if
  `loop`.
- Audio: plays from the test scene without clipping; SFX under music.
