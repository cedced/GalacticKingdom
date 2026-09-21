class_name PlayerSession
extends RefCounted
## One connected player's server-side state outside any single room. Fuel is
## stored as (value, timestamp) and recomputed lazily on read, never ticked
## (CLAUDE.md Section 5: offline accrual) — the same math will price the time
## a player spent logged out once sessions persist.

var peer_id: int = 0
var entity_id: int = 0
var system_id: int = 0
## Fuel as of fuel_updated_at; read through current_fuel().
var fuel: float = 0.0
## Unix seconds. "now" is always passed in so tests control the clock.
var fuel_updated_at: float = 0.0


func current_fuel(cap: float, per_minute: float, now: float) -> float:
	return Galaxy.accrued_fuel(fuel, cap, per_minute, now - fuel_updated_at)


func spend_fuel(amount: float, cap: float, per_minute: float, now: float) -> void:
	fuel = maxf(current_fuel(cap, per_minute, now) - amount, 0.0)
	fuel_updated_at = now
