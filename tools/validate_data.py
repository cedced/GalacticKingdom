#!/usr/bin/env python3
"""Validate every file under data/ against its JSON Schema.

Usage: python tools/validate_data.py
Exit code 0 when everything validates, 1 otherwise. Run by CI on every push
(CLAUDE.md Section 2) and locally before committing data changes.

Conventions:
- data/tuning.json          -> data/schemas/tuning.schema.json
- data/shard.json           -> data/schemas/shard.schema.json
- data/ships/<id>.json      -> data/schemas/ship.schema.json (id must match filename)
- data/bodies/<id>.json     -> data/schemas/body_sprite.schema.json (id must match filename,
                               sprite_dir must hold sheet.png + sheet.json)
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:  # pragma: no cover
    print("error: jsonschema is not installed (pip install jsonschema)")
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"
SCHEMAS_DIR = DATA_DIR / "schemas"


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def validate(instance_path: Path, schema_path: Path, errors: list[str]) -> None:
    try:
        instance = load_json(instance_path)
    except json.JSONDecodeError as exc:
        errors.append(f"{instance_path.relative_to(REPO_ROOT)}: invalid JSON: {exc}")
        return
    schema = load_json(schema_path)
    validator = jsonschema.Draft202012Validator(schema)
    for error in sorted(validator.iter_errors(instance), key=str):
        location = "/".join(str(part) for part in error.absolute_path) or "<root>"
        errors.append(
            f"{instance_path.relative_to(REPO_ROOT)}: {location}: {error.message}"
        )


def validate_ships(errors: list[str]) -> int:
    schema_path = SCHEMAS_DIR / "ship.schema.json"
    count = 0
    for ship_path in sorted((DATA_DIR / "ships").glob("*.json")):
        count += 1
        validate(ship_path, schema_path, errors)
        try:
            ship = load_json(ship_path)
        except json.JSONDecodeError:
            continue  # already reported by validate()
        if ship.get("id") != ship_path.stem:
            errors.append(
                f"{ship_path.relative_to(REPO_ROOT)}: id {ship.get('id')!r} "
                f"does not match filename {ship_path.stem!r}"
            )
        model = str(ship.get("model", ""))
        model_path = REPO_ROOT / model.removeprefix("res://")
        if model and not model_path.is_file():
            errors.append(
                f"{ship_path.relative_to(REPO_ROOT)}: model file missing: {model}"
            )
    return count


def validate_body_sprites(errors: list[str]) -> int:
    schema_path = SCHEMAS_DIR / "body_sprite.schema.json"
    count = 0
    for body_path in sorted((DATA_DIR / "bodies").glob("*.json")):
        count += 1
        validate(body_path, schema_path, errors)
        try:
            body = load_json(body_path)
        except json.JSONDecodeError:
            continue  # already reported by validate()
        if body.get("id") != body_path.stem:
            errors.append(
                f"{body_path.relative_to(REPO_ROOT)}: id {body.get('id')!r} "
                f"does not match filename {body_path.stem!r}"
            )
        sprite_dir = REPO_ROOT / str(body.get("sprite_dir", "")).removeprefix("res://")
        for required in ("sheet.png", "sheet.json"):
            if not (sprite_dir / required).is_file():
                errors.append(
                    f"{body_path.relative_to(REPO_ROOT)}: missing "
                    f"{body.get('sprite_dir')}/{required}"
                )
    return count


def validate_tuning_cross_fields(errors: list[str]) -> None:
    """Relations a JSON Schema cannot express."""
    try:
        tuning = load_json(DATA_DIR / "tuning.json")
    except json.JSONDecodeError:
        return  # already reported by validate()
    render = tuning.get("render", {})
    levels = render.get("zoom_levels", [])
    index = render.get("default_zoom_index", 0)
    if isinstance(index, int) and isinstance(levels, list) and index >= len(levels):
        errors.append(
            f"data/tuning.json: render/default_zoom_index {index} is out of "
            f"range for zoom_levels (length {len(levels)})"
        )
    starter = tuning.get("world", {}).get("starter_hull_id", "")
    if starter and not (DATA_DIR / "ships" / f"{starter}.json").is_file():
        errors.append(
            f"data/tuning.json: world/starter_hull_id {starter!r} has no "
            f"matching data/ships/{starter}.json"
        )


def main() -> int:
    errors: list[str] = []
    count = 1
    validate(DATA_DIR / "tuning.json", SCHEMAS_DIR / "tuning.schema.json", errors)
    validate_tuning_cross_fields(errors)
    count += 1
    validate(DATA_DIR / "shard.json", SCHEMAS_DIR / "shard.schema.json", errors)
    count += validate_ships(errors)
    count += validate_body_sprites(errors)
    if errors:
        for line in errors:
            print(f"FAIL {line}")
        print(f"validate_data: {len(errors)} error(s) in {count} file(s)")
        return 1
    print(f"validate_data: OK ({count} file(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
