# AI art workflow

How we generate game art with local open-weight models, repeatably, with
no paid API anywhere. Companion to `README.md` (which owns file layout and
import rules); this file owns the *process*. Policy and the reasons behind
it are ADR-004; the data model and per-kind loops are
`wiki/systems/asset-pipeline.md`.

Since 2026-09-21: **Claude generates on the local GPU, the human curates.**
Claude runs `tools/gen/comfy_generate.py` (ComfyUI on the RTX 3080, house
model + style LoRA), drops candidates in `assets/dump/gen/<manifest_id>/`,
you pick one (or none), Claude runs intake, wiring, and in-game
verification. Local models honor seeds, so the manifest row's
model + workflow + prompt + seed regenerates the kept file exactly.

Manual channel for hero pieces (ship concept sheets, portraits, marketing):
you paste the style block + asset prompt into the Gemini app (included in
Google AI Pro; pick Nano Banana Pro from the model picker when offered),
download the PNGs into the same `dump/gen/<manifest_id>/` folder, and say
which model made which file. Turn off Gemini Apps Activity first. Those
files are game assets only, not LoRA training data, until Google's consumer
terms on that are confirmed.

## The loop at a glance

```
1. Want        a `wanted` row in data/assets/manifest.json (id, kind, milestone)
2. Generate    Claude: python tools/gen/comfy_generate.py --id <row> --seeds 3  -> dump/gen/<id>/   (or you, in the Gemini app)
3. Approve     you: name the winner, or say "none, retry with <change>"
4. Intake      Claude: tools/import_*.py -> assets/<kind>/<id>/
5. Wire        Claude: data/<kind>/<id>.json + manifest row -> status: wired, source (model, workflow, seed), license
6. Verify      Claude: validate_data, Godot --import, in-game screenshot or test-scene playback
```

Batches: Claude generates every candidate for a batch first, then asks
for one approval pass, then intakes. You review once per batch. A batch
longer than about an hour of GPU time is announced before it starts.

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

Goes at the front of EVERY image prompt, then the asset prompt. With the
style LoRA loaded, `gkstyle` is the trigger word and the block still goes
in (it is also the caption prefix the LoRA was trained with).

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

Local models generate at 1024 px (SDXL, Z-Image) and upscale to 2048 in
the workflow; "2048x2048 or larger" in the block is for the Gemini app.

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

House model: decided by the sprint step 2 bake-off (SDXL 1.0 vs
Z-Image-Turbo, same prompt, three seeds each, Gemini-app renders of the
same prompt as the quality reference). The winner and its workflow are
recorded in `wiki/systems/asset-pipeline.md` and `tools/gen/models.json`.
Negative prompt for local models: `text, watermark, frame, border,
stars, nebula, lens flare, blurry, cropped, multiple objects`.

## 3. Per-asset prompts

Append after the style block. View angle is the one rule that differs
by type — get it wrong and the sprite cannot sit in the world.

| Asset type | View angle (critical) | Prompt seed | Notes |
|---|---|---|---|
| Planet | **Straight-on view of the full disc** (looks like a photo of a globe) | "A single <biome> planet, full disc, <palette/features>" | Straight-on spheres are the only sprites the UV-spin animation works on. One sprite can cover several biomes via tint (`tint_mix`), so prioritize distinct looks: lava, ringed gas giant, ice, jungle. |
| Sun | Straight-on full disc with corona | "A single star, full disc with flame corona licking outward, <color>" | The corona shader widens the fire ring (`corona_spread`) and tints per star type — one good sun covers many. |
| Station | **3/4 view from ~30° above** (matches the iso camera pitch) | "A <description> space station, three-quarter view from slightly above" | Static in game (no spin). One per station kind; faction variants later. |
| Asteroid field / derelict | 3/4 view from ~30° above | "A loose cluster of asteroids" / "a wrecked derelict freighter hull" | Done 2026-09-09 (Recraft). |
| Planet texture (rotation-sheet experiment) | Equirectangular, no lighting | "Seamless equirectangular surface map of a <biome> planet, flat even lighting, no shadows, 2:1" | `tools/render_turntable.py` wraps it on a sphere in Blender and renders N angles under the scene light. Keep only if it beats the UV-spin shader at gameplay zoom. |
| Ship concept | **Three views on one canvas**: front, side, top-down 3/4 | "Concept sheet of a single <class> spaceship: front view, side view, three-quarter top view, same ship, same lighting, evenly spaced on black" | Local with the style LoRA, or the Gemini app for hero hulls. Feeds Hunyuan3D (local, multi-view). Silhouette first: a trader is boxy, a fighter is a wedge, a freighter is long. No baked weapons (the loadout system fights them). |
| VFX | — | — | Not generated. Godot GPU particles + shaders (M3). A sprite sheet only where a shader cannot do it, from a local video model or a Blender sim, via `tools/frames_from_clip.py`. |
| Icon | Flat, frontal | "Flat-lit icon of <thing>, centered, 20% padding, single object" | Generate the whole set in one seed series so members match; 128px master after intake. |
| Portrait | Bust, frontal, neutral | "Portrait of a <role>, bust, neutral expression, soft key light" | Gemini app for hero NPCs, local otherwise. Recurring characters: img2img from the approved portrait. |
| SFX | — (Envato) | Envato search terms recorded in the manifest row ("sci-fi laser short", "ui click hologram") | Never generated. `tools/import_audio.py` trims, normalizes to -16 LUFS, mono OGG. |
| Music | — (Envato) | Envato search terms recorded in the manifest row | Never generated. |

Wanted list lives in the manifest (`status: wanted`), not here. Seed it
with, in rough value order: lava planet, ringed gas giant, ice planet, red
dwarf sun, blue giant sun, three M2 hulls (trader, light fighter,
freighter), the eight commodity icons, port master portrait, three music
slots (safe space, lawless, docked).

## 4. Generate, intake, train

```
python tools/gen/comfy_generate.py --id planet_lava --seeds 3 [--model sdxl|zimage] [--lora gk_style_v1]   # planned
python tools/import_body_sprite.py <source.png> --kind planet|sun|station --id <id>   # exists
python tools/render_turntable.py <equirect.png> --id <id> --frames 32                 # planned, Blender 5.2 headless
python tools/normalize_hull.py <mesh.glb|obj> --id <hull_id> --class trader           # planned, Blender 5.2 headless
python tools/import_icon.py <png> --set commodities --id <id> [--portrait]            # planned
python tools/import_audio.py <wav|mp3> --id <id> [--music]                            # planned
python tools/gen/build_dataset.py --lora gk_style_v1                                  # planned: wired rows -> captioned set
python tools/gen/train_lora.py --lora gk_style_v1                                     # planned: ~1 h on the 3080 at 768 px
```

`import_body_sprite.py` crops to a content-centered square, rewrites
transparent pixels to black (mipmap hygiene), caps at 2048, writes
`assets/bodies/<kind>s/<id>/sheet.png` + `sheet.json`, and prints the
`data/bodies/<id>.json` stub to fill in (coverage, tint, spin). The
planned tools follow the same shape: one input, one id, files land in
their `assets/` folder, a stub or manifest patch is printed.

ComfyUI lives outside the repo (`COMFY_DIR` in `.env`); workflows are
JSON under `tools/gen/workflows/` and are committed; checkpoints, LoRAs,
and datasets live under `assets/source/` (gitignored, never exported) and
are listed with license and sha256 in `tools/gen/models.json`.

## 5. Provenance and licensing

Every asset is a row in `data/assets/manifest.json` (schema-validated, CI
fails on an `assets/` file without a row). The row records provider,
model + LoRA, workflow, full prompt, seed, date, and license status.

License facts as of 2026-09-21 (re-check before the first public build):
- SDXL 1.0: CreativeML OpenRAIL++-M — outputs unrestricted, commercial OK.
- Z-Image-Turbo, FLUX.2 klein 4B: Apache 2.0 — outputs and weights free.
  (FLUX.2 klein 9B and FLUX.1/2 [dev] are non-commercial: do not use.)
- Our own LoRAs: trained only on assets we made or own; Gemini-app outputs
  excluded from training sets until Google's consumer terms are confirmed.
- Gemini app (Google AI Pro): confirm ownership/commercial terms once and
  record them in each row; keep Gemini Apps Activity off.
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
- VFX: plays in the test scene; loops cleanly if `loop`.
- Audio: plays from the test scene without clipping; SFX under music.
- Reproducibility: once per house-model change, regenerate one wired row
  from its manifest seed and confirm the file matches.
