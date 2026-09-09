# ADR-002: Server-authoritative simulation

Status: Accepted

## Context
PvP with real stakes (losing ships and planets) makes cheating attractive.

## Decision
The server owns all state. Clients send intent only. Clients predict their own ship and interpolate everyone else. Server reconciles on mismatch.

## Consequences
- Every gameplay rule must live in `sim/` so the server can enforce it.
- Latency handling (prediction, reconciliation, lag compensation for hits) is a first-class subsystem, not an afterthought. See systems/networking.md.
- No client-side economy math is trusted. Trade offers are validated server-side against live prices.
