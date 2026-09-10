#!/usr/bin/env python3
"""Intake one rendered sprite into the assets/bodies pipeline.

Usage:
  python tools/import_body_sprite.py <source.png> --kind planet|sun|station --id <snake_case_id>

Does everything the pipeline requires (assets/ART_WORKFLOW.md step 4):
- crops to a content-centered square (sprite center = collision center),
- rewrites fully-transparent pixels to black (white margins bleed gray
  fringes through mipmapping),
- caps the canvas at --max-size (default 2048),
- writes assets/bodies/<kind>s/<id>/sheet.png + a 1-frame sheet.json,
- prints the data/bodies/<id>.json stub and the SOURCES.md reminder.

Needs Pillow and numpy (dev tool only; CI never runs it).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover
    print("error: this tool needs Pillow and numpy (pip install Pillow numpy)")
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
KIND_DIRS = {"planet": "planets", "sun": "suns", "station": "stations"}
KIND_COVERAGE_FIELD = {
    "planet": ("biomes", ["earthlike"]),
    "sun": ("star_types", ["yellow"]),
    "station": ("station_kinds", ["port"]),
}


def content_square(image: Image.Image, pad: float) -> np.ndarray:
    """Square crop centered on the visible content's bounding box."""
    pixels = np.array(image.convert("RGBA"))
    ys, xs = np.nonzero(pixels[:, :, 3] > 8)
    if len(xs) == 0:
        sys.exit("error: image is fully transparent")
    cx = (int(xs.min()) + int(xs.max())) // 2
    cy = (int(ys.min()) + int(ys.max())) // 2
    side = int(max(xs.max() - xs.min(), ys.max() - ys.min()) * pad)
    half = side // 2
    canvas = np.zeros((side, side, 4), np.uint8)
    sx0, sy0 = max(cx - half, 0), max(cy - half, 0)
    sx1 = min(cx + half, pixels.shape[1])
    sy1 = min(cy + half, pixels.shape[0])
    canvas[sy0 - (cy - half):sy1 - (cy - half), sx0 - (cx - half):sx1 - (cx - half)] = (
        pixels[sy0:sy1, sx0:sx1]
    )
    canvas[canvas[:, :, 3] == 0] = 0
    return canvas


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--kind", required=True, choices=sorted(KIND_DIRS))
    parser.add_argument("--id", required=True, dest="sprite_id")
    parser.add_argument("--pad", type=float, default=1.06,
                        help="margin around the content bbox (default 1.06)")
    parser.add_argument("--max-size", type=int, default=2048)
    args = parser.parse_args()

    if not args.sprite_id.replace("_", "").isalnum() or args.sprite_id != args.sprite_id.lower():
        sys.exit(f"error: id {args.sprite_id!r} must be snake_case ascii")
    canvas = content_square(Image.open(args.source), args.pad)
    image = Image.fromarray(canvas)
    if image.width > args.max_size:
        image = image.resize((args.max_size, args.max_size), Image.LANCZOS)

    target_dir = REPO_ROOT / "assets" / "bodies" / KIND_DIRS[args.kind] / args.sprite_id
    target_dir.mkdir(parents=True, exist_ok=True)
    image.save(target_dir / "sheet.png")
    sheet = {
        "frames": 1, "frame_w": image.width, "frame_h": image.height,
        "deg_per_frame": 0.0, "fps": 0.0,
    }
    (target_dir / "sheet.json").write_text(json.dumps(sheet) + "\n", encoding="utf-8")

    field, example = KIND_COVERAGE_FIELD[args.kind]
    stub = {
        "id": args.sprite_id,
        "kind": args.kind,
        "sprite_dir": f"res://assets/bodies/{KIND_DIRS[args.kind]}/{args.sprite_id}",
        "spin_speed": 0.02 if args.kind != "station" else 0.0,
        "tint_mix": 0.3,
        field: example,
    }
    rel = target_dir.relative_to(REPO_ROOT)
    print(f"wrote {rel}/sheet.png ({image.width}px) + sheet.json")
    print(f"\nnext steps:")
    print(f"1. create data/bodies/{args.sprite_id}.json (adjust coverage/tint/spin):")
    print(json.dumps(stub, indent=2))
    print(f"2. add a provenance row to assets/bodies/SOURCES.md "
          f"(original: {args.source.name})")
    print("3. python tools/validate_data.py, then re-import in Godot and screenshot")
    return 0


if __name__ == "__main__":
    sys.exit(main())
