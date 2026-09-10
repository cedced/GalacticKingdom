# Body sprite sources

Third-party provenance for everything under `assets/bodies/`, per the
naming rules in `assets/README.md`.

| Asset | Original filename (from `dump/`) | Pack / author | License |
|---|---|---|---|
| `planets/planet_terran/sheet.png` | `Planet.H03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `planets/planet_barren/sheet.png` | `Mercury Planet.H03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `suns/sun_giant/sheet.png` | `Sun 05 Yellow Star Giant.E03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `stations/station_port/sheet.png` | `space-station.png` (dump/gen) | AI-generated, Recraft, 2026-09-09; port prompt from `ART_WORKFLOW.md` batch | Recraft free tier — confirm commercial terms before an exported build ships it |
| `stations/station_starbase/sheet.png` | `star-station.png` (dump/gen) | AI-generated, Recraft, 2026-09-09; starbase prompt from `ART_WORKFLOW.md` batch | Recraft free tier — confirm commercial terms before an exported build ships it |
| `asteroids/asteroid_field/sheet.png` | `asteroid-2.png` (dump/gen; `asteroid-1` unused variant) | AI-generated, Recraft, 2026-09-09; asteroid prompt from `ART_WORKFLOW.md` batch | Recraft free tier — confirm commercial terms |
| `derelicts/derelict_wreck/sheet.png` | `derelict-1.png` (dump/gen; `derelict-2` unused variant) | AI-generated, Recraft, 2026-09-09; derelict prompt from `ART_WORKFLOW.md` batch | Recraft free tier — confirm commercial terms |
| `planets/planet_desert/sheet.png` | `desert-planet.png` (dump/gen) | AI-generated, Recraft, 2026-09-09; desert planet prompt from `ART_WORKFLOW.md` batch | Recraft free tier — confirm commercial terms |

Replaced at 2026-09-09: the original `station_port`/`station_starbase`
renders (`Futuristic Sci Fi Space Station.G03.2k.png`, `White Space
Station.G03.2k.png`, unknown pack, unknown license) were superseded by
the Recraft generations above — two unknown-license blockers cleared.

All are single-angle renders stored as 1-frame sheets. The Bodies
pipeline's N-angle rotation sheets still need the original 3D sources
(see `assets/README.md` Open questions); until then the client animates
the pole-on sphere stills (planets, sun) with shader UV rotation. The
station renders are 3/4-angle views, so they stay static — UV rotation
would spin the picture, not the station. Station sheets were cropped to
content-centered squares from the originals so the sprite center matches
the collision circle; all sheets had fully-transparent pixels rewritten
to black to stop white mipmap bleed.
