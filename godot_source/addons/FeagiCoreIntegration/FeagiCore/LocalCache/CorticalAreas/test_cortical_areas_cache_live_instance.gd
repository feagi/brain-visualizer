extends SceneTree
## Unit tests for CorticalAreasCache.has_live_instance.
## Brain Monitor rebuild must not recreate IPU/OPU instances that region
## containment still holds after remove_cortical_area.


func _initialize() -> void:
	var failures: int = 0
	failures += _test_live_instance_matches_cache_object()
	failures += _test_same_id_stale_instance_is_rejected()
	failures += _test_removed_area_is_no_longer_live()
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
