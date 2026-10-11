extends SceneTree
## Genome search matches names and kinds, and each kind has the top-bar action.
## Run: godot --headless -s res://BrainVisualizer/UI/Windows/GlobalSearch/test_global_search.gd
##
## Scripts are loaded inside [_initialize] so autoload names exist before they compile.

const _CATALOG_PATH := "res://BrainVisualizer/UI/Windows/GlobalSearch/GlobalSearchCatalog.gd"
const _WINDOW_PATH := "res://BrainVisualizer/UI/Windows/GlobalSearch/WindowGlobalSearch.gd"

var _catalog: GDScript
var _window: GDScript


func _initialize() -> void:
	_catalog = load(_CATALOG_PATH) as GDScript
	_window = load(_WINDOW_PATH) as GDScript
	if _catalog == null or not _catalog.can_instantiate():
		push_error("Global search catalog did not compile")
		quit(1)
		return
	if _window == null or not _window.can_instantiate():
		push_error("Global search window did not compile")
		quit(1)
		return
	var failures := 0
	failures += _test_shortcut()
	failures += _test_kind_actions()
	failures += _test_catalog_matches()
	failures += _test_window_placement()
	if failures == 0:
		print("Global search tests: PASS")
		quit(0)
	else:
		push_error("Global search tests: FAIL (%d)" % failures)
		quit(1)


func _test_shortcut() -> int:
	if not _catalog.is_search_shortcut(KEY_S, true, false, false, true, false):
		push_error("Ctrl/Cmd+S should open search")
		return 1
	if _catalog.is_search_shortcut(KEY_S, true, true, false, true, false):
		push_error("Shift+Ctrl+S should not open search")
		return 1
	if _catalog.is_search_shortcut(KEY_S, false, false, false, true, false):
		push_error("S alone should not open search")
		return 1
	if _catalog.is_search_shortcut(KEY_S, true, false, true, true, false):
		push_error("Alt+Ctrl+S should not open search")
		return 1
	if _catalog.is_search_shortcut(KEY_S, true, false, false, true, true):
		push_error("a key repeat should not toggle search")
		return 1
	if _catalog.is_search_shortcut(KEY_F, true, false, false, true, false):
		push_error("Ctrl+F should not open search")
		return 1
	return 0


func _test_kind_actions() -> int:
	# Enum order of AbstractCorticalArea.CORTICAL_AREA_TYPE.
	const TYPE_IPU := 0
	const TYPE_CORE := 1
	const TYPE_CUSTOM := 3
	const TYPE_MODULATOR := 7
	if _catalog.kind_for_cortical_type(TYPE_CORE) != _catalog.KIND_CORE:
		push_error("core areas must be labeled core")
		return 1
	if _catalog.kind_for_cortical_type(TYPE_IPU) != _catalog.KIND_IPU:
		push_error("IPU areas must be labeled ipu")
		return 1
	if _catalog.kind_for_cortical_type(TYPE_CUSTOM) != _catalog.KIND_INTERCONNECT:
		push_error("custom areas are interconnects in the menu")
		return 1
	if _catalog.kind_for_cortical_type(TYPE_MODULATOR) != _catalog.KIND_MODULATOR:
		push_error("modulator areas must stay a search kind")
		return 1
	if _catalog.action_for_kind(_catalog.KIND_IPU) != _catalog.ACTION_FOCUS_AREA:
		push_error("an area click must move the camera")
		return 1
	if _catalog.action_for_kind(_catalog.KIND_MODULATOR) != _catalog.ACTION_FOCUS_AREA:
		push_error("a modulator area click must move the camera")
		return 1
	if _catalog.action_for_kind(_catalog.KIND_CIRCUIT) != _catalog.ACTION_FOCUS_REGION:
		push_error("a circuit click must move the camera")
		return 1
	if _catalog.action_for_kind(_catalog.KIND_RULE) != _catalog.ACTION_OPEN_RULE:
		push_error("a connectivity rule click must open the rule manager")
		return 1
	if _catalog.action_for_kind(_catalog.KIND_CLASSIFIER) != _catalog.ACTION_OPEN_CLASSIFIER:
		push_error("a classifier click must open the classifier editor")
		return 1
	return 0


func _test_catalog_matches() -> int:
	var region_script := load("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/BrainRegions/BrainRegion.gd") as GDScript
	var core_script := load("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/CorticalAreas/CoreCorticalArea.gd") as GDScript
	var memory_script := load("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/CorticalAreas/MemoryCorticalArea.gd") as GDScript
	var custom_script := load("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/CorticalAreas/CustomCorticalArea.gd") as GDScript
	var rule_script := load("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Morphologies/FunctionMorphology.gd") as GDScript
	var null_rule_script := load("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Morphologies/NullMorphology.gd") as GDScript
	var classifier_script := load("res://addons/FeagiCoreIntegration/FeagiCore/LocalCache/Classifiers/GenomeClassifier.gd") as GDScript
	if region_script == null or core_script == null or memory_script == null or custom_script == null or rule_script == null or null_rule_script == null or classifier_script == null:
		push_error("genome scripts did not load")
		return 1
	var region = region_script.new(&"region-vision", &"Vision circuit", Vector2i.ZERO, Vector3i.ZERO)
	var core = core_script.new(&"core-power", &"power", Vector3i.ONE, region)
	var memory = memory_script.new(&"mem-1", &"recent frames", Vector3i.ONE, region)
	var interconnect = custom_script.new(&"custom-1", &"bridge", Vector3i.ONE, region)
	var blank = core_script.new(&"core-blank", &"", Vector3i.ONE, region)
	# MORPHOLOGY_INTERNAL_CLASS.CUSTOM is 0.
	var rule = rule_script.new(&"projector_x", false, 0, {})
	var classifier = classifier_script.new(&"clf-1", &"digit reader", Vector2i.ZERO, Vector3i.ZERO)
	var areas: Array = [core, memory, interconnect, blank]
	var regions: Array = [region]
	var rules: Array = [rule, null_rule_script.new()]
	var classifiers: Array = [classifier]
	var entries: Array = _catalog.entries_from_parts(areas, regions, rules, classifiers)
	if entries.size() != 6:
		push_error("blank names and null rules must be left out, got %d" % entries.size())
		return 1
	if not _catalog.filter_entries(entries, "").is_empty():
		push_error("an empty query must not list the genome")
		return 1
	var power: Array = _catalog.filter_entries(entries, "POW")
	if power.size() != 1 or power[0][_catalog.KEY_ACTION] != _catalog.ACTION_FOCUS_AREA:
		push_error("a core name match must focus that area")
		return 1
	if _catalog.result_text("power", _catalog.KIND_CORE) != "power    Core":
		push_error("results should show the name and the kind")
		return 1
	var cores: Array = _catalog.filter_entries(entries, "core")
	if cores.size() != 1 or String(cores[0][_catalog.KEY_LABEL]) != "power":
		push_error("typing core should find core areas by kind")
		return 1
	var inputs: Array = _catalog.filter_entries(entries, "input")
	if not inputs.is_empty():
		push_error("input should not match unrelated names")
		return 1
	var circuits: Array = _catalog.filter_entries(entries, "circuit")
	if circuits.size() != 1 or circuits[0][_catalog.KEY_ACTION] != _catalog.ACTION_FOCUS_REGION:
		push_error("typing circuit should find circuits")
		return 1
	var rules_found: Array = _catalog.filter_entries(entries, "rule")
	if rules_found.size() != 1 or rules_found[0][_catalog.KEY_PAYLOAD] != rule:
		push_error("typing rule should find the connectivity rule")
		return 1
	var readers: Array = _catalog.filter_entries(entries, "digit")
	if readers.size() != 1 or readers[0][_catalog.KEY_ACTION] != _catalog.ACTION_OPEN_CLASSIFIER:
		push_error("a classifier name should open the classifier")
		return 1
	var ordered: Array = _catalog.filter_entries(entries, "i")
	var previous := ""
	for entry in ordered:
		var label := String(entry[_catalog.KEY_LABEL]).to_lower()
		if label < previous:
			push_error("matches should be sorted by name")
			return 1
		previous = label
	return 0


func _test_window_placement() -> int:
	var desktop := Vector2(1920, 1080)
	var opened: Vector2 = _window.opening_window_size(desktop)
	if opened != _window.OPENING_PREFERRED:
		push_error("search should open at its preferred size, got %s" % opened)
		return 1
	var small: Vector2 = _window.opening_window_size(Vector2(400, 320))
	if small.x > 400.0 or small.y > 320.0:
		push_error("search must stay inside a small viewport, got %s" % small)
		return 1
	var top_left: Vector2 = _window.centered_top_left(desktop, opened)
	var expected_x := (desktop.x - opened.x) * 0.5
	if absf(top_left.x - expected_x) > 0.01:
		push_error("search should be centered horizontally, got %s" % top_left)
		return 1
	if top_left.y <= 0.0 or top_left.y >= (desktop.y - opened.y) * 0.5:
		push_error("search should sit in the upper half, got %s" % top_left)
		return 1
	return 0
