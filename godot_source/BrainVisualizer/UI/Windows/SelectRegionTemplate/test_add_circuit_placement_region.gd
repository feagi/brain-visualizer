extends SceneTree
## Packaged circuits opened from a brain-circuit tab place on that tab, not the root scene.
## Run: godot --headless -s res://BrainVisualizer/UI/Windows/SelectRegionTemplate/test_add_circuit_placement_region.gd

const SELECT_PATH := "res://BrainVisualizer/UI/Windows/SelectRegionTemplate/WindowSelectRegionTemplate.gd"
const WINDOW_MANAGER_PATH := "res://BrainVisualizer/UI/Windows/WindowManager.gd"
const AMALGAMATION_PATH := "res://BrainVisualizer/UI/Windows/AmalgamationRequest/WindowAmalgamationRequest.gd"


func _initialize() -> void:
	var failures: int = 0
	failures += _check_upload_stores_initiating_region()
	failures += _check_spawn_uses_stored_region()
	failures += _check_setup_prefers_initiating_region()
	failures += _check_import_shadow_has_move_gizmo()
	if failures == 0:
		print("Add Circuit placement region tests: PASS")
		quit(0)
		return
	push_error("Add Circuit placement region tests: FAIL (%d)" % failures)
	quit(1)


func _check_upload_stores_initiating_region() -> int:
	var source := FileAccess.get_file_as_string(SELECT_PATH)
	var upload_at: int = source.find("func _upload_circuit")
	var remember_at: int = source.find("func _remember_packaged_circuit_placement_region")
	if upload_at < 0 or remember_at < 0:
		push_error("Packaged circuit upload must remember the circuit that opened Add Circuit")
		return 1
	var upload_body: String = source.substr(upload_at, remember_at - upload_at)
	var failures: int = 0
	if upload_body.find("_remember_packaged_circuit_placement_region()") < 0:
		push_error("Upload must store the initiating circuit before the amalgamation request")
		failures += 1
	if upload_body.find("request_amalgamation_by_upload") < upload_body.find("_remember_packaged_circuit_placement_region()"):
		push_error("The initiating circuit must be stored before the upload is sent")
		failures += 1
	var fail_at: int = upload_body.find("has_errored")
	if fail_at < 0 or upload_body.find("_forget_packaged_circuit_placement_region()", fail_at) < 0:
		push_error("A failed upload must drop the stored circuit")
		failures += 1
	var remember_body: String = source.substr(remember_at, source.find("func _forget_packaged_circuit_placement_region") - remember_at)
	if remember_body.find("_force_main_scene_context") < 0 or remember_body.find("note_amalgamation_placement_region") < 0:
		push_error("Top-bar Add Circuit must stay on the root scene; a circuit tab must store its region")
		failures += 1
	return failures


func _check_spawn_uses_stored_region() -> int:
	var source := FileAccess.get_file_as_string(WINDOW_MANAGER_PATH)
	var spawn_at: int = source.find("func spawn_amalgamation_window")
	if spawn_at < 0:
		push_error("Amalgamation window spawn is missing")
		return 1
	var spawn_body: String = source.substr(spawn_at, source.find("\nfunc ", spawn_at + 1) - spawn_at)
	var failures: int = 0
	if spawn_body.find("_amalgamation_placement_region") < 0:
		push_error("Placement window must read the circuit stored at upload time")
		failures += 1
	if spawn_body.find("setup(amalgamation_ID, genome_title, circuit_size, placement_region)") < 0:
		push_error("Placement window must receive the stored circuit")
		failures += 1
	var ready_at: int = spawn_body.find("_is_root_region_ready_for_amalgamation()")
	var setup_call_at: int = spawn_body.find("import_amalgamation.setup(")
	if ready_at < 0 or setup_call_at < ready_at:
		push_error("Placement window must wait until the root circuit is loaded")
		failures += 1
	return failures


func _check_setup_prefers_initiating_region() -> int:
	var source := FileAccess.get_file_as_string(AMALGAMATION_PATH)
	var setup_at: int = source.find("func setup(")
	var clone_at: int = source.find("func setup_for_clone")
	if setup_at < 0 or clone_at < setup_at:
		push_error("Amalgamation setup is missing")
		return 1
	var setup_body: String = source.substr(setup_at, clone_at - setup_at)
	var failures: int = 0
	if setup_body.find("parent_region: BrainRegion = null") < 0:
		push_error("Amalgamation setup must accept the initiating circuit")
		failures += 1
	var parent_use: int = setup_body.find("var placement_region: BrainRegion = parent_region")
	var ready_at: int = setup_body.find("is_root_available()")
	var root_use: int = setup_body.find("get_root_region()")
	if parent_use < 0 or ready_at < parent_use or root_use < ready_at:
		push_error("Amalgamation setup must use the initiating circuit, and the root circuit only after it is loaded")
		failures += 1
	if setup_body.find("_region_button.setup(placement_region") < 0:
		push_error("The parent-circuit selector must start on the initiating circuit")
		failures += 1
	return failures


func _check_import_shadow_has_move_gizmo() -> int:
	var source := FileAccess.get_file_as_string(AMALGAMATION_PATH)
	var attach_at: int = source.find("func _attach_placement_preview")
	var cleanup_at: int = source.find("func _cleanup_placement_previews")
	if attach_at < 0 or cleanup_at < attach_at:
		push_error("Amalgamation placement preview is missing")
		return 1
	var attach_body: String = source.substr(attach_at, cleanup_at - attach_at)
	var import_at: int = attach_body.find("else:")
	if import_at < 0:
		push_error("Packaged-circuit import preview branch is missing")
		return 1
	var import_body: String = attach_body.substr(import_at)
	var failures: int = 0
	if import_body.find("start_cortical_preview_relocation") < 0:
		push_error("The import box shadow must start the move gizmo")
		failures += 1
	if import_body.find("Do not auto-frame") < 0:
		push_error("The import preview must not auto-frame, or the move gizmo is pushed out of view")
		failures += 1
	var cleanup_body: String = source.substr(cleanup_at, source.find("\nfunc ", cleanup_at + 1) - cleanup_at)
	if cleanup_body.find("stop_cortical_preview_relocation") < 0:
		push_error("Closing the import window must remove the move gizmo")
		failures += 1
	return failures
