# ADR-001: Engine and stack

Status: Proposed (confirm before M0)

## Context
We need a 3D-capable engine with cheap orthographic rendering, a headless server mode for an authoritative simulation, and a small enough surface that one developer plus Claude can own it.

## Options considered
1. Godot 4 (GDScript, optional C#). Open source, headless export, built-in ENet multiplayer, ortho camera trivial.
2. Unity + Netcode for GameObjects. Larger ecosystem, licensing risk, heavier headless server.
3. Three.js client + Node authoritative server. Web-playable, but two codebases for sim logic unless we share TS, and 3D iso in the browser costs performance headroom.
4. Bevy (Rust). Excellent for deterministic sim, immature editor and UI tooling.

## Decision
Godot 4.x, GDScript first, C# only for measured hot paths. Same project exports both client and headless server.

## Consequences
- Sim code must be written to run without scene nodes so the server can run it headless and tests can run it fast.
- GDScript performance ceiling means economy and AI tick cadences must stay coarse (seconds, not frames).
- If web play becomes a goal, Godot's web export is viable but multiplayer would need WebRTC or WebSocket transport instead of ENet.
