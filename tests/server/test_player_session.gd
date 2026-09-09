extends GutTest
## Lazy fuel accrual on the session (CLAUDE.md Section 5: compute from
## timestamps, never tick offline players). The clock is always injected.

const CAP: float = 100.0
const PER_MINUTE: float = 2.0


func _session(fuel: float, updated_at: float) -> PlayerSession:
	var session: PlayerSession = PlayerSession.new()
	session.fuel = fuel
	session.fuel_updated_at = updated_at
	return session


func test_fuel_accrues_with_elapsed_time() -> void:
	var session: PlayerSession = _session(10.0, 1000.0)
	assert_almost_eq(session.current_fuel(CAP, PER_MINUTE, 1000.0), 10.0, 0.0001)
	assert_almost_eq(session.current_fuel(CAP, PER_MINUTE, 1060.0), 12.0, 0.0001)
	assert_eq(session.current_fuel(CAP, PER_MINUTE, 1000.0 + 86400.0), CAP)


func test_reading_fuel_does_not_advance_the_clock() -> void:
	var session: PlayerSession = _session(10.0, 1000.0)
	session.current_fuel(CAP, PER_MINUTE, 1060.0)
	assert_eq(session.fuel, 10.0)
	assert_eq(session.fuel_updated_at, 1000.0)


func test_spend_settles_accrual_then_deducts() -> void:
	var session: PlayerSession = _session(10.0, 1000.0)
	session.spend_fuel(5.0, CAP, PER_MINUTE, 1060.0)
	# 10 stored + 2 accrued - 5 spent.
	assert_almost_eq(session.fuel, 7.0, 0.0001)
	assert_eq(session.fuel_updated_at, 1060.0)
	assert_almost_eq(session.current_fuel(CAP, PER_MINUTE, 1060.0), 7.0, 0.0001)


func test_spend_never_goes_negative() -> void:
	var session: PlayerSession = _session(1.0, 1000.0)
	session.spend_fuel(50.0, CAP, PER_MINUTE, 1000.0)
	assert_eq(session.fuel, 0.0)
