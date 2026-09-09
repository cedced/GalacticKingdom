# ADR-003: Isometric presentation of a 3D world

Status: Accepted

## Context
We want the readability and nostalgia of a top-down 2D space game with the production advantages of 3D assets (rotation, lighting, damage states, no sprite sheets per angle).

## Decision
Full 3D scene, orthographic camera at fixed pitch and yaw. Gameplay is 2D on the XZ plane. Depth buffer handles sorting.

## Consequences
- Art pipeline is 3D models plus materials, not sprites. Pixel-art look, if chosen, comes from render scale and a post shader, not from hand-drawn frames.
- UI must convert between world XZ and screen space for targeting, map pins, and click-to-move. One helper, `client/rendering/iso.gd`, owns this math.
- Camera never rotates in gameplay. This keeps controls and readability consistent and lets us bake certain lighting assumptions.
