# GalacticRealm Wiki

Design documentation for GalacticRealm, a persistent multiplayer space game inspired by *Starport: Galactic Empires*.

Rules of the wiki:
- `CLAUDE.md` at the repo root governs how code is written. This wiki governs what the game is.
- Every system page uses the same headings. Empty sections are open work, not omissions.
- ADRs are append-only. To reverse a decision, write a new ADR that supersedes the old one.

## Current milestone

M0 Skeleton (see Roadmap.md)

## Pages

- [Inspiration (keep / adapt / drop)](Inspiration.md)
- [Glossary](Glossary.md)
- [Architecture](Architecture.md)
- [Roadmap](Roadmap.md)

### Systems
- [Galaxy and System Generator](systems/galaxy-generator.md)
- [Combat (PvPvE)](systems/combat.md)
- [Planets and Capture](systems/planets.md)
- [Economy and Shops](systems/economy.md)
- [Quests and Events](systems/quests-events.md)
- [Factions](systems/factions.md)
- [Rendering (3D to Isometric)](systems/rendering.md)
- [Networking](systems/networking.md)
- [Ships and Equipment](systems/ships.md)

### Decisions
- [ADR-001 Engine and stack](adr/001-engine-and-stack.md)
- [ADR-002 Server-authoritative simulation](adr/002-server-authoritative.md)
- [ADR-003 Isometric presentation of a 3D world](adr/003-isometric-3d.md)
