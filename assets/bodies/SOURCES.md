# Body sprite sources

Third-party provenance for everything under `assets/bodies/`, per the
naming rules in `assets/README.md`.

| Asset | Original filename (from `dump/`) | Pack / author | License |
|---|---|---|---|
| `planets/planet_terran/sheet.png` | `Planet.H03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `planets/planet_barren/sheet.png` | `Mercury Planet.H03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `suns/sun_giant/sheet.png` | `Sun 05 Yellow Star Giant.E03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `stations/station_port/sheet.png` | `Futuristic Sci Fi Space Station.G03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |
| `stations/station_starbase/sheet.png` | `White Space Station.G03.2k.png` | unknown pack, user-provided | unknown — confirm before any exported build ships it |

All are single-angle renders stored as 1-frame sheets. The Bodies
pipeline's N-angle rotation sheets still need the original 3D sources
(see `assets/README.md` Open questions); until then the client animates
the pole-on sphere stills (planets, sun) with shader UV rotation. The
station renders are 3/4-angle views, so they stay static — UV rotation
would spin the picture, not the station. Station sheets were cropped to
content-centered squares from the originals so the sprite center matches
the collision circle; all sheets had fully-transparent pixels rewritten
to black to stop white mipmap bleed.
