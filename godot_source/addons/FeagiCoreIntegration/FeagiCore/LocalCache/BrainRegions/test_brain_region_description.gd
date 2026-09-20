extends SceneTree
## Unit tests for brain-region plain-text description JSON parsing.
## Run: godot --headless --path godot_source -s res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/BrainRegions/test_brain_region_description.gd
##
## This script does not instantiate [BrainRegion] (that class references the
## FeagiCore autoload and cannot compile in a standalone SceneTree). Cache
## apply/emit coverage lives in FEAGI_change_description / FEAGI_edited_region
## and is exercised by the rust genome + connectome tests.


func _initialize() -> void:
	var failures: int = 0
	failures += _test_description_from_json_string()
	failures += _test_description_from_json_null_is_empty()
	failures += _test_description_from_json_missing_is_empty()
	failures += _test_tooltip_text_strips_and_hides_empty()
	failures += _test_axis_aligned_rect_from_points()
	failures += _test_fixed_size_billboard_corners_scale_with_depth()
	failures += _test_screen_rect_from_projected_corners_contains_and_pads()
	failures += _test_scale_rect_into_container()
	failures += _test_region_description_tooltip_layout_is_larger_than_top_bar_defaults()
	failures += _test_region_title_description_pixel_offset()
	failures += _test_should_synthesize_brain_monitor_hover()
	if failures == 0:
		print("BrainRegion description tests: PASS")
		quit(0)
	else:
		push_error("BrainRegion description tests: FAIL (%d)" % failures)
		quit(1)


func _test_description_from_json_string() -> int:
	var parsed: StringName = FEAGIUtils.brain_region_description_from_json({
		"description": "Visual scanning circuit"
	})
	if parsed != &"Visual scanning circuit":
		push_error("brain_region_description_from_json should keep the genome string")
		return 1
	return 0


func _test_description_from_json_null_is_empty() -> int:
	var parsed: StringName = FEAGIUtils.brain_region_description_from_json({
		"description": null
	})
	if parsed != &"":
		push_error("null description should become empty text")
		return 1
	return 0


func _test_description_from_json_missing_is_empty() -> int:
	var parsed: StringName = FEAGIUtils.brain_region_description_from_json({
		"title": "scanning"
	})
	if parsed != &"":
		push_error("missing description should become empty text")
		return 1
	return 0


func _test_tooltip_text_strips_and_hides_empty() -> int:
	if FEAGIUtils.brain_region_description_tooltip_text(&"  hello  ") != "hello":
		push_error("tooltip text should strip edges")
		return 1
	if FEAGIUtils.brain_region_description_tooltip_text(&"   ") != "":
		push_error("whitespace-only description should hide tooltip")
		return 1
	return 0


func _test_axis_aligned_rect_from_points() -> int:
	if FEAGIUtils.axis_aligned_rect_from_points(PackedVector2Array()) != Rect2():
		push_error("empty points should yield empty rect")
		return 1
	var rect: Rect2 = FEAGIUtils.axis_aligned_rect_from_points(PackedVector2Array([
		Vector2(10, 20),
		Vector2(40, 5),
		Vector2(15, 35),
	]))
	if rect.position != Vector2(10, 5) or rect.size != Vector2(30, 30):
		push_error("axis-aligned rect should span min/max points, got %s" % rect)
		return 1
	return 0


func _test_fixed_size_billboard_corners_scale_with_depth() -> int:
	var origin := Vector3(0, 0, 0)
	var right := Vector3(1, 0, 0)
	var up := Vector3(0, 1, 0)
	var near_corners: PackedVector3Array = FEAGIUtils.fixed_size_billboard_world_corners(
		origin, Vector2(2, 1), 1.0, right, up
	)
	var far_corners: PackedVector3Array = FEAGIUtils.fixed_size_billboard_world_corners(
		origin, Vector2(2, 1), 2.0, right, up
	)
	if near_corners.size() != 4 or far_corners.size() != 4:
		push_error("billboard should emit four corners")
		return 1
	if not near_corners[0].is_equal_approx(Vector3(-1, -0.5, 0)):
		push_error("depth 1 corner should be half mesh size, got %s" % near_corners[0])
		return 1
	if not far_corners[0].is_equal_approx(Vector3(-2, -1, 0)):
		push_error("depth 2 corner should scale with depth, got %s" % far_corners[0])
		return 1
	return 0


func _test_screen_rect_from_projected_corners_contains_and_pads() -> int:
	if FEAGIUtils.screen_rect_from_projected_corners(PackedVector2Array(), 8.0) != Rect2():
		push_error("empty projected corners should yield empty rect")
		return 1
	var rect: Rect2 = FEAGIUtils.screen_rect_from_projected_corners(PackedVector2Array([
		Vector2(100, 200),
		Vector2(180, 200),
		Vector2(180, 240),
		Vector2(100, 240),
	]), 8.0)
	if not rect.has_point(Vector2(140, 220)):
		push_error("padded title rect should contain the visual center")
		return 1
	if not rect.has_point(Vector2(96, 196)):
		push_error("padded title rect should include the pad")
		return 1
	if rect.has_point(Vector2(20, 20)):
		push_error("padded title rect should not be unbounded")
		return 1
	return 0


func _test_scale_rect_into_container() -> int:
	if FEAGIUtils.scale_rect_into_container(Rect2(10, 20, 40, 30), Vector2.ZERO, Rect2(0, 0, 200, 100)) != Rect2():
		push_error("zero source size should yield empty window rect")
		return 1
	var mapped: Rect2 = FEAGIUtils.scale_rect_into_container(
		Rect2(10, 20, 40, 30),
		Vector2(100, 100),
		Rect2(200, 50, 200, 100)
	)
	if mapped.position != Vector2(220, 70) or mapped.size != Vector2(80, 30):
		push_error("3D viewport rect should map into the container window rect, got %s" % mapped)
		return 1
	return 0


func _test_region_description_tooltip_layout_is_larger_than_top_bar_defaults() -> int:
	if FEAGIUtils.region_description_tooltip_max_lines() <= 2:
		push_error("region description tooltip must allow more than the 2-line top-bar default")
		return 1
	if FEAGIUtils.region_description_tooltip_wrap_width_px() <= 280.0:
		push_error("region description tooltip wrap width must exceed the 280px top-bar default")
		return 1
	return 0


func _test_region_title_description_pixel_offset() -> int:
	if not is_equal_approx(FEAGIUtils.REGION_DESCRIPTION_GAP_FONT_HEIGHTS, 1.0):
		push_error("description gap must be one font height")
		return 1
	var same_scale: Vector2 = FEAGIUtils.region_title_description_pixel_offset(Vector2(100.0, 20.0), 10.0, 1.0, 1.0)
	if not same_scale.is_equal_approx(Vector2(-50.0, -20.0)):
		push_error("description should sit one font height under the title, got %s" % same_scale)
		return 1
	var scaled: Vector2 = FEAGIUtils.region_title_description_pixel_offset(Vector2(100.0, 20.0), 10.0, 2.0, 1.0)
	if not scaled.is_equal_approx(Vector2(-100.0, -40.0)):
		push_error("pixel offset must convert title font units into description pixels, got %s" % scaled)
		return 1
	return 0


func _test_should_synthesize_brain_monitor_hover() -> int:
	if not FEAGIUtils.should_synthesize_brain_monitor_hover(true, false, false, true):
		push_error("root BM must synthesize hover when no tab has the cursor")
		return 1
	if FEAGIUtils.should_synthesize_brain_monitor_hover(true, true, false, true):
		push_error("root BM must yield hover only while a tab viewport has the cursor")
		return 1
	if not FEAGIUtils.should_synthesize_brain_monitor_hover(false, false, false, true):
		push_error("tab BM must synthesize hover when the cursor is in that viewport")
		return 1
	if FEAGIUtils.should_synthesize_brain_monitor_hover(true, false, true, false):
		push_error("no BM should synthesize hover when the cursor is outside its SubViewport")
		return 1
	return 0
