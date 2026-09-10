# AI art workflow

How we pick a visual style and generate game art with AI image tools,
repeatably. Companion to `README.md` (which owns file layout and import
rules); this file owns the *process*. The human runs the generator of
their choice; Claude runs the intake, wiring, and in-game verification.

## The loop at a glance

```
1. Style round      pick/lock the style block (once, revisit rarely)
2. Request          pick an asset from the shortlist below
3. Generate         paste style block + asset prompt into your AI tool
4. Intake           python tools/import_body_sprite.py <png> --kind ... --id ...
5. Wire             data/bodies/<id>.json + SOURCES.md row (Claude)
6. Verify           validate_data, Godot re-import, in-game screenshot (Claude)
```

Steps 4–6 are mechanical; drop a PNG anywhere (e.g. `assets/dump/`) and
ask Claude to take it from there.

## 1. Style round — identifying the style

Run once before generating in bulk (this also settles the open
pixel-vs-painterly decision in `wiki/systems/rendering.md`):

1. Pick ONE test subject we already have in game (suggestion: a desert
   planet) so candidates are comparable against real neighbors.
2. Generate the same subject in 2–4 candidate styles, e.g.:
   - **Pre-rendered painterly realism** — what the current user-provided
     renders already are; the de-facto incumbent.
   - **Stylized painterly** (hand-painted look, chunky shapes, rim light).
   - **Pixel art** (would also flip the renderer to nearest-neighbor
     upscale, see rendering wiki — a bigger commitment).
3. Claude intakes all candidates side by side into a throwaway system
   view and screenshots them next to ships, stations, and the backdrop.
4. Pick one. Record the decision in `wiki/systems/rendering.md`, and
   freeze the winning wording into the Style block below.
5. Regenerate existing assets only if they clash; the incumbent renders
   already pass as "pre-rendered painterly realism".

## 2. The style block

Paste this at the front of EVERY generation prompt, then append the
asset prompt. Fill the first line after the style round locks it.

```
STYLE: <locked at style round — until then: pre-rendered painterly sci-fi
realism, detailed surfaces, subtle color grading, no outlines>
Single centered object on a fully transparent background.
Square canvas, 2048x2048 or larger.
Lit from the upper left, neutral white key light, deep shadows.
No text, no watermark, no frame, no border, no drop shadow,
no lens flare, no background stars or nebulae.
Muted deep-space palette; accent colors allowed on the object itself.
```

Hard technical constraints baked into that block (do not relax them):
- **Transparent background** — the intake tool crops by alpha; a baked
  background ruins that and the in-game compositing.
- **Upper-left lighting** — matches the scene's sun light and the
  backdrop stars' highlight direction; a mismatched sprite looks pasted.
- **No frames/borders** — border pixels smear across the sprite through
  mipmapping (we have been bitten twice).

## 3. Per-asset prompts

Append after the style block. View angle is the one rule that differs
by type — get it wrong and the sprite cannot sit in the world.

| Asset type | View angle (critical) | Prompt seed | Notes |
|---|---|---|---|
| Planet | **Straight-on view of the full disc** (looks like a photo of a globe) | "A single <biome> planet, full disc, <palette/features>" | Straight-on spheres are the only sprites the UV-spin animation works on. One sprite can cover several biomes via tint (`tint_mix`), so prioritize distinct looks: lava, ringed gas giant, ice, jungle. |
| Sun | Straight-on full disc with corona | "A single star, full disc with flame corona licking outward, <color>" | The corona shader widens the fire ring (`corona_spread`) and tints per star type — one good sun covers many. |
| Station | **3/4 view from ~30° above** (matches the iso camera pitch) | "A <description> space station, three-quarter view from slightly above" | Static in game (no spin). One per station kind; faction variants later. |
| Asteroid field / derelict | 3/4 view from ~30° above | "A loose cluster of asteroids" / "a wrecked derelict freighter hull" | Currently primitive fallbacks — first place new art pays off. Needs a small `SystemBody`-kind sprite hookup (ask Claude). |
| Ship | — | — | Ships are 3D GLB models, not sprites (`README.md` Ships pipeline). AI image tools do not help here; triage the existing pack at M2. |

Wanted list (in rough value order): asteroids field, derelict, lava
planet, ringed gas giant, ice planet, red dwarf sun variant, blue giant
sun variant, faction station variants (M5).

## 4. Intake

```
python tools/import_body_sprite.py <source.png> --kind planet|sun|station --id <id>
```

The tool crops to a content-centered square, rewrites transparent
pixels to black (mipmap hygiene), caps at 2048, writes
`assets/bodies/<kind>s/<id>/sheet.png` + `sheet.json`, and prints the
`data/bodies/<id>.json` stub to fill in (coverage, tint, spin).

## 5. Provenance and licensing

Every generated asset gets a row in `assets/bodies/SOURCES.md`: the
generator (tool + model + date), the prompt used, and the tool's
license/commercial terms at generation time. AI generators differ on
commercial use and some raise questions about copyrightability — the
same "confirm before an exported build ships it" rule applies as for
the third-party packs.

## 6. Verification checklist (Claude runs this)

- `python tools/validate_data.py` green; Godot `--import` clean.
- In-game screenshot: reads at min and max zoom, sits on the backdrop
  without fringes, tint response sane, doesn't clash with neighbors.
- Nothing renders above ship hover height (rendering wiki rule).
