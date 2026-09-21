# UI

Client-side UI: HUD, screens, and the shared Godot theme. Not a pillar on its own — every pillar's screens (galaxy map, port trade, colony management) build on what is defined here.

## Purpose

One shared look and one shared mechanism for all player-facing chrome. Controls come from Godot's `Control` nodes styled by a single `Theme` resource, so new screens inherit the style without per-scene styling.

## Player-facing rules

- The in-flight HUD (top-left) shows the current system (name, security, danger tier) and warp fuel as a bar plus exact numbers, in a holo-styled panel.
- Transient lines (boarding mode, gate hints, server denial messages) float below the panel as outlined text so the panel never resizes mid-flight.
- The HUD displays only server-derived or locally predicted state; it never computes gameplay values (CLAUDE.md Section 5, no hidden state).

## Data model

- `client/ui/holo_theme.tres` — the single shared `Theme`. Maps `Button` (normal/hover/pressed/disabled), `CheckBox`, `ProgressBar`, `Panel`/`PanelContainer`, and `Label` onto the Wenrexa holo textures (`assets/ui/wenrexa_holo/`, CC0, manifest row `wenrexa_holo`) as 9-patch `StyleBoxTexture`s.
- `client/ui/hud.gd` (`Hud`, a `Control` under `Main/UI`) — the M1 in-flight HUD, built in code. Presentation only; `ClientMain` pushes values in (`set_system`, `set_fuel`, `set_hint`, `set_boarding`, `show_message`).

## Algorithms

None. 9-patch stretching is Godot's `StyleBoxTexture`.

## Tuning knobs

None yet. Layout margins live in the theme/scene (presentation, not gameplay; `data/tuning.json` is for gameplay values only).

## Interactions with other systems

- `client/main.gd` owns the HUD instance and is the only writer.
- The galaxy map (`client/ui/galaxy_map.gd`) is still custom-drawn and unthemed; restyle it with `holo_theme.tres` in a follow-up.
- Future screens (port/trade M2) should apply `holo_theme.tres` at their root control and extend the theme rather than overriding per node.

## Open questions

- Font: currently Godot's default. Pick a sci-fi font (license-checked) before M1's galaxy map, or commit to the default.
- The pack has no HSlider art in horizontal orientation (`sliderbar_1/` is vertical); rotate the art or build sliders from the progress bar pieces when a slider is first needed.
- Icon language: the pack's 35 flat icons (`wenrexa_holo/icons/`) are unmapped; assign meanings (cargo, fuel, shields...) when M1/M2 screens need them.
- UI scale on high-DPI displays: untested.

## Test plan

- Scripts lint via `--check-only`; scene load is exercised by running the client.
- Visual check: run the client with `-- --screenshot=<path>` against a running headless server (saves a frame after the first snapshot and quits), verified 2026-09-10.
- No GUT tests: `Hud` is presentation-only with no logic worth pinning. Add tests if the HUD ever gains formatting logic beyond string interpolation.
