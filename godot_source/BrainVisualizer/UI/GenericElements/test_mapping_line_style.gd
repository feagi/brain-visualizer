extends SceneTree
## MappingLineStyle: sine wave keeps endpoints, is deterministic and peaks at the amplitude; dashes come out as segment pairs.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/GenericElements/test_mapping_line_style.gd


func _initialize() -> void:
	var failures: int = 0
	var line: PackedVector2Array = []
	for i in 40:
		line.append(Vector2(float(i) * 10.0, 0.0))
	var a: PackedVector2Array = MappingLineStyle.wave_points(line, 8.0, 40.0)
	var b: PackedVector2Array = MappingLineStyle.wave_points(line, 8.0, 40.0)
	if a.size() < 3 or a[0] != line[0] or a[a.size() - 1] != line[line.size() - 1]:
		push_error("wave must keep the endpoints exactly")
		failures += 1
	if a != b:
		push_error("wave must be deterministic")
		failures += 1
	var peak: float = 0.0
	for p in a:
		peak = maxf(peak, absf(p.y))
	if peak < 7.0 or peak > 8.001:
		push_error("peak offset expected about 8, got %s" % peak)
		failures += 1
	var wave_dashes: PackedVector2Array = MappingLineStyle.dash_segments(a, 12.0, 8.0)
	if wave_dashes.is_empty() or wave_dashes.size() % 2 != 0:
		push_error("dash output on a wave must be non-empty segment pairs")
		failures += 1
	var dashes: PackedVector2Array = MappingLineStyle.dash_segments(line, 20.0, 10.0)
	if dashes.is_empty() or dashes.size() % 2 != 0:
		push_error("dash output must be non-empty segment pairs, got %d" % dashes.size())
		failures += 1
	var total: float = 0.0
	for i in range(0, dashes.size() - 1, 2):
		total += dashes[i].distance_to(dashes[i + 1])
	# 390 long, period 30, dash 20: 13 periods, last dash is full (starts at 360, ends 380).
	if absf(total - 260.0) > 0.01:
		push_error("dash on-length expected 260, got %s" % total)
		failures += 1
	if dashes[0].x != 0.0:
		push_error("phase 0 must start the first dash at the line start")
		failures += 1
	var shifted: PackedVector2Array = MappingLineStyle.dash_segments(line, 20.0, 10.0, 0.25)
	if shifted.is_empty() or absf(shifted[0].x - 7.5) > 0.05:
		push_error("a quarter cycle must move the first dash toward the line end, got %s" % (shifted[0] if not shifted.is_empty() else Vector2.INF))
		failures += 1
	var wrapped: PackedVector2Array = MappingLineStyle.dash_segments(line, 20.0, 10.0, 1.0)
	if wrapped != dashes:
		push_error("a full cycle must land back on the phase-0 dashes")
		failures += 1
	var at_half: Vector2 = MappingLineStyle.dash_canvas_lengths(0.5)
	if absf(at_half.x - MappingLineStyle.DASH_LENGTH_PX * 2.0) > 0.01 or absf(at_half.y - MappingLineStyle.DASH_GAP_PX * 2.0) > 0.01:
		push_error("half zoom must double the canvas dash length, got %s" % at_half)
		failures += 1
	var phase_now: float = MappingLineStyle.dash_phase()
	if phase_now < 0.0 or phase_now >= 1.0:
		push_error("dash phase out of range: %s" % phase_now)
		failures += 1
	if failures == 0:
		print("mapping line style: PASS")
		quit(0)
	else:
		push_error("mapping line style: %d check(s) failed" % failures)
		quit(1)
