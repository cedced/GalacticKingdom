# UI

Client-side UI: HUD, screens, and the shared Godot theme. Not a pillar on its own — every pillar's screens (galaxy map, port trade, colony management) build on what is defined here.

## Purpose

One shared look and one shared mechanism for all player-facing chrome. Controls come from Godot's `Control` nodes styled by a single `Theme` resource, so new screens inherit the style without per-scene styling.

## Player-facing rules

- The in-flight HUD (top-left) shows hull name, connection status, position, and speed.
- GRID checkbox toggles the reference grid (client cosmetic only).
- HALT button cancels the go-to autopilot; it is disabled when no autopilot is running.
- The HUD displays only server-derived or locally predicted state; it never computes gameplay values (CLAUDE.md Section 5, no hidden state).

## Data model

- `client/ui/holo_theme.tres` — the single shared `Theme`. Maps `Button` (normal/hover/pressed/disabled), `CheckBox`, `ProgressBar`, `Panel`/`PanelContainer`, and `Label` onto the Wenrexa holo textures (`assets/ui/wenrexa_holo/`, CC0, see `assets/ui/SOURCES.md`) as 9-patch `StyleBoxTexture`s.
- `client/ui/hud.tscn` + `hud.gd` (`Hud`, a `CanvasLayer`) — the in-flight HUD. Presentation only; `ClientMain` pushes values in (`set_status`, `set_kinematics`, `set_autopilot_active`) and listens to `halt_pressed` / `grid_toggled`.

## Algorithms

None. 9-patch stretching is Godot's `StyleBoxTexture`.

## Tuning knobs

None yet. Layout margins live in the theme/scene (presentation, not gameplay; `data/tuning.json` is for gameplay values only).

## Interactions with other systems

- `client/main.gd` owns the HUD instance and is the only writer.
- Future screens (galaxy map M1, port/trade M2) should apply `holo_theme.tres` at their root control and extend the theme rather than overriding per node.

## Open questions

- Font: currently Godot's default. Pick a sci-fi font (license-checked) before M1's galaxy map, or commit to the default.
- The pack has no HSlider art in horizontal orientation (`sliderbar_1/` is vertical); rotate the art or build sliders from the progress bar pieces when a slider is first needed.
- Icon language: the pack's 35 flat icons (`wenrexa_holo/icons/`) are unmapped; assign meanings (cargo, fuel, shields...) when M1/M2 screens need them.
- UI scale on high-DPI displays: untested.

## Test plan

- Scripts lint via `--check-only`; scene load is exercised by running the client.
- Visual check: movie-maker capture (`--write-movie <dir>/frame.png --fixed-fps 20 --quit-after 60`) against a running headless server, verified at M0+ (2026-09-09).
- No GUT tests: `Hud` is presentation-only with no logic worth pinning. Add tests if the HUD ever gains formatting logic beyond string interpolation.
