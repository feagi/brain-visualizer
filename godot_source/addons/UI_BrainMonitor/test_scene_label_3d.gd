extends SceneTree
## Unit and integration tests for the shared BV 3D Label3D setup.


const SceneLabel3D = preload("res://addons/UI_BrainMonitor/UI_BrainMonitor_SceneLabel3D.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_shared_msdf_and_outline()
	failures += _test_role_visual_scale_matches_legacy_product()
	failures += _test_fixed_size_only_on_region_titles()
	failures += _test_apply_is_idempotent()
	failures += _test_create_names_and_priorities()
	failures += _test_outline_sorts_behind_fill()
	if failures == 0:
		print("SceneLabel3D tests: PASS")
		quit(0)
	else:
		push_error("SceneLabel3D tests: FAIL (%d)" % failures)
		quit(1)


func _test_shared_msdf_and_outline() -> int:
	var area: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.AREA_NAME, &"AreaNameLabel")
	var region: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.REGION_TITLE, &"RegionNameLabel")
	var plate: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.PLATE_TAG, &"PlateTag")
	for label in [area, region, plate]:
		if label.font_size != SceneLabel3D.FONT_SIZE:
			push_error("shared font_size should be %d, got %d" % [SceneLabel3D.FONT_SIZE, label.font_size])
			return 1
		if label.outline_size != SceneLabel3D.OUTLINE_SIZE:
			push_error("shared outline_size should be %d, got %d" % [SceneLabel3D.OUTLINE_SIZE, label.outline_size])
			return 1
		if label.outline_modulate != SceneLabel3D.OUTLINE_MODULATE:
			push_error("shared outline_modulate mismatch")
			return 1
		if label.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
			push_error("scene labels must billboard")
			return 1
		if label.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			push_error("scene labels must use mipmap filtering")
			return 1
		if label.font != SceneLabel3D.scene_font():
			push_error("scene labels must share the cached MSDF font")
			return 1
	var font: Font = SceneLabel3D.scene_font()
	if not (font is FontFile):
		push_error("scene font must be a FontFile")
		return 1
	if not (font as FontFile).multichannel_signed_distance_field:
		push_error("scene font must enable MSDF")
		return 1
	area.free()
	region.free()
	plate.free()
	return 0


func _test_role_visual_scale_matches_legacy_product() -> int:
	if not is_equal_approx(SceneLabel3D.FONT_SIZE * SceneLabel3D.AREA_NAME_PIXEL_SIZE, SceneLabel3D.AREA_NAME_VISUAL_SCALE):
		push_error("area name visual scale drifted from legacy 512 * 0.005")
		return 1
	if not is_equal_approx(SceneLabel3D.FONT_SIZE * SceneLabel3D.REGION_TITLE_PIXEL_SIZE, SceneLabel3D.REGION_TITLE_VISUAL_SCALE):
		push_error("region title visual scale drifted from legacy 32 * 0.001")
		return 1
	if not is_equal_approx(SceneLabel3D.FONT_SIZE * SceneLabel3D.PLATE_TAG_PIXEL_SIZE, SceneLabel3D.PLATE_TAG_VISUAL_SCALE):
		push_error("plate tag visual scale drifted from legacy 18 * 0.002")
		return 1
	return 0


func _test_fixed_size_only_on_region_titles() -> int:
	if SceneLabel3D.uses_fixed_size(SceneLabel3D.ROLE.AREA_NAME):
		push_error("area names must not use fixed_size")
		return 1
	if not SceneLabel3D.uses_fixed_size(SceneLabel3D.ROLE.REGION_TITLE):
		push_error("region titles must use fixed_size")
		return 1
	if SceneLabel3D.uses_fixed_size(SceneLabel3D.ROLE.PLATE_TAG):
		push_error("plate tags must not use fixed_size")
		return 1
	var area: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.AREA_NAME, &"Area")
	var region: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.REGION_TITLE, &"Region")
	var plate: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.PLATE_TAG, &"Plate")
	if area.fixed_size or plate.fixed_size or not region.fixed_size:
		push_error("fixed_size flags do not match role policy")
		area.free()
		region.free()
		plate.free()
		return 1
	if not region.no_depth_test:
		push_error("region titles must disable depth test")
		area.free()
		region.free()
		plate.free()
		return 1
	if area.no_depth_test or plate.no_depth_test:
		push_error("area names and plate tags keep depth test; plate hover policy is applied later")
		area.free()
		region.free()
		plate.free()
		return 1
	area.free()
	region.free()
	plate.free()
	return 0


func _test_apply_is_idempotent() -> int:
	var label: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.AREA_NAME, &"Area")
	label.text = "visual"
	SceneLabel3D.apply(label, SceneLabel3D.ROLE.AREA_NAME)
	if label.text != "visual":
		push_error("apply must not clear text")
		label.free()
		return 1
	if label.font_size != SceneLabel3D.FONT_SIZE or not is_equal_approx(label.pixel_size, SceneLabel3D.AREA_NAME_PIXEL_SIZE):
		push_error("second apply must keep area-name sizing (font_size=%d pixel_size=%s expected %d / %s)" % [
			label.font_size,
			label.pixel_size,
			SceneLabel3D.FONT_SIZE,
			SceneLabel3D.AREA_NAME_PIXEL_SIZE,
		])
		label.free()
		return 1
	SceneLabel3D.apply(label, SceneLabel3D.ROLE.REGION_TITLE)
	if not label.fixed_size or not is_equal_approx(label.pixel_size, SceneLabel3D.REGION_TITLE_PIXEL_SIZE):
		push_error("apply must be able to restyle an existing label to another role")
		label.free()
		return 1
	label.free()
	return 0


func _test_create_names_and_priorities() -> int:
	var area: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.AREA_NAME, &"AreaNameLabel")
	var region: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.REGION_TITLE, &"RegionNameLabel")
	var plate: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.PLATE_TAG, &"PlateTag")
	if area.name != "AreaNameLabel" or region.name != "RegionNameLabel" or plate.name != "PlateTag":
		push_error("create must assign the requested node name")
		area.free()
		region.free()
		plate.free()
		return 1
	if area.render_priority != SceneLabel3D.AREA_NAME_RENDER_PRIORITY:
		push_error("area name render_priority mismatch")
		area.free()
		region.free()
		plate.free()
		return 1
	if region.render_priority != SceneLabel3D.REGION_TITLE_RENDER_PRIORITY:
		push_error("region title render_priority mismatch")
		area.free()
		region.free()
		plate.free()
		return 1
	if plate.render_priority != SceneLabel3D.PLATE_TAG_RENDER_PRIORITY:
		push_error("plate tag render_priority mismatch")
		area.free()
		region.free()
		plate.free()
		return 1
	if plate.modulate != SceneLabel3D.PLATE_TAG_MODULATE:
		push_error("plate tag modulate mismatch")
		area.free()
		region.free()
		plate.free()
		return 1
	area.free()
	region.free()
	plate.free()
	return 0


func _test_outline_sorts_behind_fill() -> int:
	var area: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.AREA_NAME, &"Area")
	var region: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.REGION_TITLE, &"Region")
	var plate: Label3D = SceneLabel3D.create(SceneLabel3D.ROLE.PLATE_TAG, &"Plate")
	for label in [area, region, plate]:
		if label.outline_render_priority >= label.render_priority:
			push_error("outline_render_priority (%d) must stay below fill (%d) or the label can read as black" % [
				label.outline_render_priority,
				label.render_priority,
			])
			area.free()
			region.free()
			plate.free()
			return 1
	SceneLabel3D.apply_render_priority(area, 2)
	if area.render_priority != 2 or area.outline_render_priority != 1:
		push_error("apply_render_priority must keep outline one step behind the fill")
		area.free()
		region.free()
		plate.free()
		return 1
	area.free()
	region.free()
	plate.free()
	return 0
