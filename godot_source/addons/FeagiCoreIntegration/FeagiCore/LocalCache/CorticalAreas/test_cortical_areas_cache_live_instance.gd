extends SceneTree
## Unit tests for CorticalAreasCache.has_live_instance.
## Brain Monitor rebuild must not recreate IPU/OPU instances that region
## containment still holds after remove_cortical_area.


func _initialize() -> void:
	var failures: int = 0
	failures += _test_live_instance_matches_cache_object()
	failures += _test_same_id_stale_instance_is_rejected()
	failures += _test_removed_area_is_no_longer_live()
	failures += _test_modulator_group_overrides_custom_cortical_type()
	if failures == 0:
		print("CorticalAreasCache.has_live_instance tests: PASS")
		quit(0)
	else:
		push_error("CorticalAreasCache.has_live_instance tests: FAIL (%d)" % failures)
		quit(1)


func _make_region() -> BrainRegion:
	return BrainRegion.new(&"region-test", &"test", Vector2i.ZERO, Vector3i.ZERO)


func _test_live_instance_matches_cache_object() -> int:
	var region: BrainRegion = _make_region()
	var cache := CorticalAreasCache.new()
	cache.FEAGI_add_custom_cortical_area(
		&"aXN2aQkAAAA=",
		&"vision_C",
		Vector3i.ZERO,
		Vector3i.ONE,
		false,
		Vector2i.ZERO,
		region,
		{},
		true
	)
	var live: AbstractCorticalArea = cache.available_cortical_areas[&"aXN2aQkAAAA="]
	if not cache.has_live_instance(live):
		push_error("has_live_instance should accept the cached object")
		return 1
	return 0


func _test_same_id_stale_instance_is_rejected() -> int:
	var region: BrainRegion = _make_region()
	var cache := CorticalAreasCache.new()
	cache.FEAGI_add_custom_cortical_area(
		&"aXN2aQkAAAA=",
		&"vision_C",
		Vector3i.ZERO,
		Vector3i.ONE,
		false,
		Vector2i.ZERO,
		region,
		{},
		true
	)
	var stale_region: BrainRegion = _make_region()
	var stale := CustomCorticalArea.new(&"aXN2aQkAAAA=", &"vision_C", Vector3i.ONE, stale_region, true)
	if cache.has_live_instance(stale):
		push_error("has_live_instance should reject a different instance with the same ID")
		return 1
	return 0


func _test_removed_area_is_no_longer_live() -> int:
	var region: BrainRegion = _make_region()
	var cache := CorticalAreasCache.new()
	cache.FEAGI_add_custom_cortical_area(
		&"aXN2aQkAAAA=",
		&"vision_C",
		Vector3i.ZERO,
		Vector3i.ONE,
		false,
		Vector2i.ZERO,
		region,
		{},
		true
	)
	var live: AbstractCorticalArea = cache.available_cortical_areas[&"aXN2aQkAAAA="]
	cache.remove_cortical_area(&"aXN2aQkAAAA=")
	if cache.has_live_instance(live):
		push_error("has_live_instance should be false after remove_cortical_area")
		return 1
	if cache.available_cortical_areas.has(&"aXN2aQkAAAA="):
		push_error("cache should not contain the ID after remove_cortical_area")
		return 1
	return 0


func _test_modulator_group_overrides_custom_cortical_type() -> int:
	var failures: int = 0
	var region: BrainRegion = _make_region()
	var cache := CorticalAreasCache.new()
	var base := {
		"cortical_type": "custom",
		"cortical_name": "mod_trigger",
		"cortical_dimensions": [1, 1, 1],
		"coordinate_3d": [0, 0, 0],
	}
	var cases := {
		&"Z19fXwAAAAA=": {"cortical_group": "MODULATOR"},
		&"Z19fXwAAAAB=": {"cortical_group": "CUSTOM", "area_type": "modulator"},
		&"Z19fXwAAAAC=": {"cortical_group": "CUSTOM"},
	}
	var expected := {
		&"Z19fXwAAAAA=": AbstractCorticalArea.CORTICAL_AREA_TYPE.MODULATOR,
		&"Z19fXwAAAAB=": AbstractCorticalArea.CORTICAL_AREA_TYPE.MODULATOR,
		&"Z19fXwAAAAC=": AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM,
	}
	for id: StringName in cases:
		var d: Dictionary = base.duplicate()
		d.merge(cases[id])
		d["cortical_id"] = id
		cache.FEAGI_add_cortical_area_from_dict(d, region)
		var area: AbstractCorticalArea = cache.available_cortical_areas.get(id)
		if area == null or area.cortical_type != expected[id]:
			push_error("modulator parse: %s expected type %s got %s" % [id, expected[id], "null" if area == null else str(area.cortical_type)])
			failures += 1
	print("modulator parse asserts ran: 3 cases, failures=%d" % failures)
	return failures
