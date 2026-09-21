#!/usr/bin/env python3
"""Validate every file under data/ against its JSON Schema, and every file
under assets/ against the asset manifest.

Usage: python tools/validate_data.py
Exit code 0 when everything validates, 1 otherwise. Run by CI on every push
(CLAUDE.md Section 2) and locally before committing data or asset changes.

Conventions:
- data/tuning.json          -> data/schemas/tuning.schema.json
- data/shard.json           -> data/schemas/shard.schema.json
- data/ships/<id>.json      -> data/schemas/ship.schema.json (id must match filename)
- data/bodies/<id>.json     -> data/schemas/body_sprite.schema.json (id must match filename,
                               sprite_dir must hold sheet.png + sheet.json)
- data/assets/manifest.json -> data/schemas/asset_manifest.schema.json; ids unique; every
                               wired row's path exists; every file under assets/ (except
                               dump/, source/, *.import, *.md, .gitkeep) is covered by
                               exactly one wired row; every asset path referenced from data/ is covered
                               by a wired row (ADR-004, wiki/systems/asset-pipeline.md)
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

try:
    import jsonschema
except ImportError:  # pragma: no cover
    print("error: jsonschema is not installed (pip install jsonschema)")
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data"
SCHEMAS_DIR = DATA_DIR / "schemas"

RES_PREFIX = "res://"
# Files under assets/ that carry no shipped art and need no manifest row:
# dump/ is staging, source/ holds working files, checkpoints, LoRAs, datasets.
COVERAGE_EXCLUDED_DIRS = {"dump", "source"}
COVERAGE_EXCLUDED_SUFFIXES = {".import", ".md"}
COVERAGE_EXCLUDED_NAMES = {".gitkeep"}


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def rel(path: Path, root: Path = REPO_ROOT) -> str:
    return path.relative_to(root).as_posix()


def res_to_path(res: str, root: Path = REPO_ROOT) -> Path:
    return root / res.removeprefix(RES_PREFIX)


def validate(
    instance_path: Path, schema_path: Path, errors: list[str], root: Path = REPO_ROOT
) -> None:
    try:
        instance = load_json(instance_path)
    except json.JSONDecodeError as exc:
        errors.append(f"{rel(instance_path, root)}: invalid JSON: {exc}")
        return
    schema = load_json(schema_path)
    validator = jsonschema.Draft202012Validator(schema)
    for error in sorted(validator.iter_errors(instance), key=str):
        location = "/".join(str(part) for part in error.absolute_path) or "<root>"
        errors.append(f"{rel(instance_path, root)}: {location}: {error.message}")


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
                f"{rel(ship_path)}: id {ship.get('id')!r} "
                f"does not match filename {ship_path.stem!r}"
            )
        model = str(ship.get("model", ""))
        if model and not res_to_path(model).is_file():
            errors.append(f"{rel(ship_path)}: model file missing: {model}")
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
                f"{rel(body_path)}: id {body.get('id')!r} "
                f"does not match filename {body_path.stem!r}"
            )
        sprite_dir = res_to_path(str(body.get("sprite_dir", "")))
        for required in ("sheet.png", "sheet.json"):
            if not (sprite_dir / required).is_file():
                errors.append(
                    f"{rel(body_path)}: missing {body.get('sprite_dir')}/{required}"
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
    sun = tuning.get("collision", {}).get("sun_radius", 0)
    ship = tuning.get("collision", {}).get("ship_radius", 0)
    min_orbit = tuning.get("galaxy", {}).get("min_orbit_radius", 0)
    spawn_ring = tuning.get("world", {}).get("spawn_ring_radius", 0)
    if min_orbit <= sun:
        errors.append(
            f"data/tuning.json: galaxy/min_orbit_radius {min_orbit} must exceed "
            f"collision/sun_radius {sun} or bodies generate inside the sun's exclusion zone"
        )
    if spawn_ring <= sun + ship:
        errors.append(
            f"data/tuning.json: world/spawn_ring_radius {spawn_ring} must exceed "
            f"collision/sun_radius + ship_radius {sun + ship} or ships spawn inside the sun"
        )


def asset_files(assets_dir: Path) -> list[Path]:
    """Every file under assets/ that must be owned by a manifest row."""
    files: list[Path] = []
    for path in sorted(assets_dir.rglob("*")):
        if not path.is_file():
            continue
        parts = path.relative_to(assets_dir).parts
        if parts[0] in COVERAGE_EXCLUDED_DIRS:
            continue
        if path.suffix in COVERAGE_EXCLUDED_SUFFIXES or path.name in COVERAGE_EXCLUDED_NAMES:
            continue
        files.append(path)
    return files


def covers(row_path: Path, target: Path) -> bool:
    """A row covers its own path and, when it is a directory, everything below it."""
    return target == row_path or row_path in target.parents


def data_asset_refs(root: Path) -> list[tuple[Path, str]]:
    """(data file, res:// asset path) for every asset a data file points at."""
    refs: list[tuple[Path, str]] = []
    for pattern, key in (("ships/*.json", "model"), ("bodies/*.json", "sprite_dir")):
        for data_path in sorted((root / "data").glob(pattern)):
            try:
                value = load_json(data_path).get(key, "")
            except json.JSONDecodeError:
                continue  # reported by the schema pass
            if isinstance(value, str) and value.startswith(RES_PREFIX + "assets/"):
                refs.append((data_path, value))
    return refs


def validate_assets(
    errors: list[str],
    root: Path = REPO_ROOT,
    schema_path: Path = SCHEMAS_DIR / "asset_manifest.schema.json",
) -> Counter:
    """Manifest schema, id uniqueness, coverage, and data cross-references.

    Returns status/license counts for the summary line (empty on a parse failure).
    """
    manifest_path = root / "data" / "assets" / "manifest.json"
    label = rel(manifest_path, root)
    validate(manifest_path, schema_path, errors, root)
    try:
        manifest = load_json(manifest_path)
    except json.JSONDecodeError:
        return Counter()
    rows = manifest.get("assets", []) if isinstance(manifest, dict) else []
    rows = [row for row in rows if isinstance(row, dict)]

    ids = Counter(str(row.get("id")) for row in rows)
    for row_id, seen in sorted(ids.items()):
        if seen > 1:
            errors.append(f"{label}: duplicate id {row_id!r} ({seen} rows)")

    wired = [
        (str(row.get("id")), row["path"], res_to_path(row["path"], root))
        for row in rows
        if row.get("status") == "wired" and isinstance(row.get("path"), str)
    ]
    files = asset_files(root / "assets")
    for row_id, res, path in wired:
        if not path.exists():
            errors.append(f"{label}: {row_id}: wired path missing: {res}")
        elif not any(covers(path, file) for file in files):
            errors.append(f"{label}: {row_id}: wired path {res} covers no asset file")
    for file in files:
        owners = [row_id for row_id, _, path in wired if covers(path, file)]
        if not owners:
            errors.append(f"{rel(file, root)}: no wired manifest row covers this file")
        elif len(owners) > 1:
            errors.append(
                f"{rel(file, root)}: covered by more than one manifest row: "
                f"{', '.join(owners)}"
            )
    for data_path, res in data_asset_refs(root):
        target = res_to_path(res, root)
        if not any(covers(path, target) for _, _, path in wired):
            errors.append(f"{rel(data_path, root)}: {res} has no wired manifest row")

    summary: Counter = Counter()
    for row in rows:
        summary[f"status:{row.get('status')}"] += 1
        license_status = row.get("license", {}).get("status") if isinstance(row.get("license"), dict) else None
        summary[f"license:{license_status}"] += 1
    return summary


def format_asset_summary(summary: Counter) -> str:
    statuses = ", ".join(
        f"{summary[f'status:{status}']} {status}"
        for status in ("wired", "wanted", "generated", "approved", "replaced")
        if summary[f"status:{status}"]
    )
    licenses = ", ".join(
        f"{summary[f'license:{status}']} {status}"
        for status in ("verified", "pending", "unknown")
        if summary[f"license:{status}"]
    )
    return f"assets: {statuses}; license: {licenses}"


def main() -> int:
    errors: list[str] = []
    count = 1
    validate(DATA_DIR / "tuning.json", SCHEMAS_DIR / "tuning.schema.json", errors)
    validate_tuning_cross_fields(errors)
    count += 1
    validate(DATA_DIR / "shard.json", SCHEMAS_DIR / "shard.schema.json", errors)
    count += validate_ships(errors)
    count += validate_body_sprites(errors)
    count += 1
    summary = validate_assets(errors)
    if errors:
        for line in errors:
            print(f"FAIL {line}")
        print(f"validate_data: {len(errors)} error(s) in {count} file(s)")
        return 1
    print(f"validate_data: OK ({count} file(s)); {format_asset_summary(summary)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
