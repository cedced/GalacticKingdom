extends GutTest
## data/tuning.json is queryable through sim/tuning.gd (no hidden state,
## CLAUDE.md Section 5).


func before_each() -> void:
	Tuning.load_data()


func test_fixed_tick_is_twenty_hz() -> void:
	assert_eq(Tuning.value_i("net.tick_hz"), 20)


func test_render_pitch_matches_claude_md_section_4() -> void:
	assert_eq(Tuning.value_f("render.pitch_deg"), 30.0)


func test_unknown_path_returns_null() -> void:
	assert_null(Tuning.value("no.such.value"))


func test_zoom_levels_are_a_nonempty_array() -> void:
	var levels: Variant = Tuning.value("render.zoom_levels")
	assert_true(levels is Array)
	assert_gt((levels as Array).size(), 0)
