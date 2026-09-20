"""Fixture-tree tests for the asset-manifest check in tools/validate_data.py.

Run: python -m unittest discover -s tests/tools
Builds a throwaway repo layout (assets/ + data/) per test and asserts which
errors the check reports. The real schema is used so the test also catches
schema drift.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import validate_data  # noqa: E402

SCHEMA = REPO_ROOT / "data" / "schemas" / "asset_manifest.schema.json"


def row(row_id: str, path: str | None = "res://assets/bodies/planets/planet_x", **overrides) -> dict:
    base = {
        "id": row_id,
        "kind": "planet",
        "status": "wired",
        "milestone": "M1",
        "source": {"provider": "user"},
        "license": {"status": "unknown"},
    }
    if path is not None:
        base["path"] = path
    base.update(overrides)
    return base


class FixtureTree:
    """A minimal repo: assets/ files and a data/ folder with a manifest."""

    def __init__(self, root: Path) -> None:
        self.root = root
        (root / "data" / "assets").mkdir(parents=True)
        (root / "data" / "bodies").mkdir()
        (root / "data" / "ships").mkdir()
        (root / "assets").mkdir()

    def file(self, relative: str, content: bytes = b"x") -> Path:
        path = self.root / "assets" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def manifest(self, rows: list[dict]) -> None:
        (self.root / "data" / "assets" / "manifest.json").write_text(
            json.dumps({"assets": rows}), encoding="utf-8"
        )

    def body(self, body_id: str, sprite_dir: str) -> None:
        (self.root / "data" / "bodies" / f"{body_id}.json").write_text(
            json.dumps({"id": body_id, "kind": "planet", "sprite_dir": sprite_dir}),
            encoding="utf-8",
        )

    def check(self) -> list[str]:
        errors: list[str] = []
        validate_data.validate_assets(errors, self.root, SCHEMA)
        return errors


class ValidateAssetsTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tree = FixtureTree(Path(self._tmp.name))

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_clean_tree_reports_nothing(self) -> None:
        self.tree.file("bodies/planets/planet_x/sheet.png")
        self.tree.file("bodies/planets/planet_x/sheet.json")
        self.tree.file("bodies/planets/planet_x/sheet.png.import")  # excluded
        self.tree.file("bodies/README.md")  # excluded
        self.tree.file("vfx/.gitkeep")  # excluded
        self.tree.file("dump/gen/anything.png")  # excluded
        self.tree.body("planet_x", "res://assets/bodies/planets/planet_x")
        self.tree.manifest([row("planet_x"), row("planet_lava", status="wanted")])
        self.assertEqual(self.tree.check(), [])

    def test_orphan_file_is_reported(self) -> None:
        self.tree.file("bodies/planets/planet_x/sheet.png")
        self.tree.file("ui/stray.png")
        self.tree.manifest([row("planet_x")])
        errors = self.tree.check()
        self.assertEqual(len(errors), 1)
        self.assertIn("assets/ui/stray.png", errors[0])
        self.assertIn("no wired manifest row", errors[0])

    def test_wired_row_with_missing_path_is_reported(self) -> None:
        self.tree.manifest([row("planet_x")])
        errors = self.tree.check()
        self.assertEqual(len(errors), 1)
        self.assertIn("planet_x: wired path missing", errors[0])

    def test_wired_row_covering_no_file_is_reported(self) -> None:
        self.tree.file("bodies/planets/planet_x/.gitkeep")
        self.tree.manifest([row("planet_x")])
        errors = self.tree.check()
        self.assertEqual(len(errors), 1)
        self.assertIn("covers no asset file", errors[0])

    def test_duplicate_id_is_reported(self) -> None:
        self.tree.file("bodies/planets/planet_x/sheet.png")
        self.tree.manifest([row("planet_x"), row("planet_x", status="wanted")])
        errors = self.tree.check()
        self.assertTrue(any("duplicate id 'planet_x'" in e for e in errors), errors)

    def test_double_coverage_is_reported(self) -> None:
        self.tree.file("bodies/planets/planet_x/sheet.png")
        self.tree.manifest([
            row("planet_x"),
            row("planets_all", path="res://assets/bodies/planets"),
        ])
        errors = self.tree.check()
        self.assertEqual(len(errors), 1)
        self.assertIn("more than one manifest row: planet_x, planets_all", errors[0])

    def test_data_reference_without_wired_row_is_reported(self) -> None:
        self.tree.file("bodies/planets/planet_x/sheet.png")
        self.tree.body("planet_y", "res://assets/bodies/planets/planet_y")
        self.tree.manifest([row("planet_x")])
        errors = self.tree.check()
        self.assertEqual(len(errors), 1)
        self.assertIn("data/bodies/planet_y.json", errors[0])
        self.assertIn("has no wired manifest row", errors[0])

    def test_wanted_row_does_not_cover_files(self) -> None:
        self.tree.file("bodies/planets/planet_x/sheet.png")
        self.tree.manifest([row("planet_x", status="wanted")])
        errors = self.tree.check()
        self.assertEqual(len(errors), 1)
        self.assertIn("no wired manifest row", errors[0])

    def test_schema_rejects_wired_row_without_path(self) -> None:
        self.tree.manifest([row("planet_x", path=None)])
        errors = self.tree.check()
        self.assertTrue(any("'path' is a required property" in e for e in errors), errors)

    def test_schema_rejects_verified_license_without_terms(self) -> None:
        self.tree.file("bodies/planets/planet_x/sheet.png")
        self.tree.manifest([row("planet_x", license={"status": "verified"})])
        errors = self.tree.check()
        self.assertTrue(any("'terms' is a required property" in e for e in errors), errors)

    def test_summary_counts_statuses_and_licenses(self) -> None:
        self.tree.file("bodies/planets/planet_x/sheet.png")
        self.tree.manifest([row("planet_x"), row("planet_lava", status="wanted", license={"status": "pending"})])
        errors: list[str] = []
        summary = validate_data.validate_assets(errors, self.tree.root, SCHEMA)
        self.assertEqual(errors, [])
        self.assertEqual(
            validate_data.format_asset_summary(summary),
            "assets: 1 wired, 1 wanted; license: 1 pending, 1 unknown",
        )


if __name__ == "__main__":
    unittest.main()
