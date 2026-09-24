extends SceneTree
## Classifier is an Integrated Circuit on the Add Circuit window, not a packaged genome.
## Run: godot --headless -s res://BrainVisualizer/UI/Windows/SelectRegionTemplate/test_add_circuit_classifier_tile.gd

const SCRIPT_PATH := "res://BrainVisualizer/UI/Windows/SelectRegionTemplate/WindowSelectRegionTemplate.gd"


func _initialize() -> void:
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	var failures: int = 0
	if source.find("const INTEGRATED_CIRCUIT_MARK") < 0 or source.find("\"IC\"") < 0:
		push_error("Classifier tile must carry a compact IC chip")
		failures += 1
	if source.find("A custom circuit you configure") < 0 or source.find("genomes or connectomes") < 0:
		push_error("The IC chip tooltip must say you configure it, and that the others are genomes or connectomes")
		failures += 1
	if source.find("host.size.x - chip_size.x + overhang") < 0 or source.find("-overhang") < 0:
		push_error("The IC chip must hang off the top-right corner of the circuit image")
		failures += 1
	if source.find("IC_CHIP_BACKGROUND: Color = Color(0.92, 0.72, 0.16, 1)") < 0 or source.find("IC_CHIP_TEXT: Color = Color(0, 0, 0, 1)") < 0:
		push_error("The IC chip must use a gold plate and dark text")
		failures += 1
	if source.find("carbon.png") < 0:
		push_error("Classifier tile must use the carbon icon")
		failures += 1
	if source.find(".z_index") >= 0:
		push_error("Classifier tile must stay in the window draw order")
		failures += 1
	var populate_at: int = source.find("func _populate_grid")
	var manifest_at: int = source.find("_add_manifest_tiles()", populate_at)
	var classifier_at: int = source.find("_add_classifier_tile()", populate_at)
	if populate_at < 0 or manifest_at < 0 or classifier_at < manifest_at:
		push_error("Classifier tile must be added after the packaged circuit tiles")
		failures += 1
	var opener_at: int = source.find("func _open_create_classifier")
	var next_func: int = source.find("\nfunc ", opener_at + 1)
	if opener_at < 0 or next_func < 0:
		push_error("Classifier opener is missing")
		failures += 1
	else:
		var body: String = source.substr(opener_at, next_func - opener_at)
		if body.find("spawn_create_classifier_for_region") < 0:
			push_error("Classifier tile must open the classifier editor")
			failures += 1
		if body.find("_upload_circuit") >= 0 or body.find("request_amalgamation") >= 0:
			push_error("Classifier must not be uploaded as a packaged genome")
			failures += 1
	if failures == 0:
		print("Add Circuit classifier tile tests: PASS")
		quit(0)
		return
	push_error("Add Circuit classifier tile tests: FAIL (%d)" % failures)
	quit(1)
