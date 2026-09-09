# Body sprite sources

Third-party provenance for everything under `assets/bodies/`, per the
naming rules in `assets/README.md`.

| Asset | Original filename (from `dump/`) | Pack / author | License |
|---|---|---|---|
| `planets/planet_terran/sheet.png` | `Planet.H03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `planets/planet_barren/sheet.png` | `Mercury Planet.H03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `suns/sun_giant/sheet.png` | `Sun 05 Yellow Star Giant.E03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |

All three are single-angle 2048x2048 renders stored as 1-frame sheets.
The Bodies pipeline's N-angle rotation sheets still need the original 3D
sources (see `assets/README.md` Open questions); until then the client
animates these stills with shader UV rotation.
