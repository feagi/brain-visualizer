extends Node
## Centralized shutdown manager for Brain Visualizer
##
## Access globally via: ShutdownManager (autoload singleton)
##
## This class handles:
## - Graceful FEAGI shutdown (subprocess and embedded)
## - Complete state cleanup (logs, cache, working directories)
## - Future: User warnings for unsaved work
## - Future: Save prompts and data persistence
##
## To use:
##   ShutdownManager.request_shutdown()  # Graceful shutdown with cleanup
##   ShutdownManager.force_shutdown()    # Immediate shutdown (emergency)

signal shutdown_started()
signal cleanup_completed()
signal shutdown_completed()

var _shutdown_in_progress: bool = false
var _feagi_embedded_instance = null  # Reference to FeagiEmbedded instance
var _ui_manager = null  # Reference to UIManager for shutdown screen

## Register the FeagiEmbedded instance for shutdown
## Call this from BrainVisualizer.gd after creating the instance
func register_embedded_instance(instance) -> void:
	_feagi_embedded_instance = instance
	print("🔌 [ShutdownManager] Registered embedded FEAGI instance")

## Register the UIManager for shutdown screen
## Call this from BrainVisualizer.gd during initialization
func register_ui_manager(ui_manager) -> void:
	_ui_manager = ui_manager
	print("🖥️ [ShutdownManager] Registered UIManager for shutdown screen")

## Request a graceful shutdown (async version for UI updates)
## This is the main entry point for shutdown
func request_shutdown_async() -> void:
	if _shutdown_in_progress:
		print("⚠️ [ShutdownManager] Shutdown already in progress")
		return
	
	_shutdown_in_progress = true
	shutdown_started.emit()
	
	print("")
	print("=" . repeat(60))
	print("🛑 SHUTDOWN SEQUENCE INITIATED")
	print("=" . repeat(60))
	
	# Show shutdown screen
	if _ui_manager:
		await _ui_manager.show_shutdown_screen()
		await _ui_manager.update_shutdown_status("Shutting down FEAGI...")
	
	# Future: Add user warning dialogs here
	# if has_unsaved_work():
	#     var confirmed = await show_save_dialog()
	#     if not confirmed:
	#         _shutdown_in_progress = false
	#         return
	
	# Step 1: Stop FEAGI processes
	await _shutdown_feagi_async()
	
	# Step 2: Clean up all state
	if _ui_manager:
		await _ui_manager.update_shutdown_status("Cleaning up state...")
	await _cleanup_all_state_async()
	
	# Step 3: Signal completion
	cleanup_completed.emit()
	if _ui_manager:
		await _ui_manager.update_shutdown_status("Shutdown complete!")
	
	print("=" . repeat(60))
	print("✅ SHUTDOWN SEQUENCE COMPLETE")
	print("=" . repeat(60))
	print("")
	
	shutdown_completed.emit()

## Synchronous wrapper for emergency situations
func request_shutdown() -> void:
	print("⚠️ [ShutdownManager] Synchronous shutdown requested (no UI updates)")
	_shutdown_in_progress = true
	_shutdown_feagi()
	_cleanup_all_state()
	_shutdown_in_progress = false

## Force shutdown without cleanup (emergency only)
func force_shutdown() -> void:
	print("⚠️ [ShutdownManager] FORCE SHUTDOWN - no cleanup")
	get_tree().quit()

## Shutdown FEAGI gracefully (async version with UI updates)
func _shutdown_feagi_async() -> void:
	print("")
	print("─" . repeat(60))
	print("🔌 SHUTTING DOWN FEAGI")
	print("─" . repeat(60))
	
	# Shutdown embedded FEAGI if running
	if _feagi_embedded_instance:
		print("   🦀 Shutting down embedded FEAGI extension...")
		if _ui_manager:
			await _ui_manager.update_shutdown_status("Stopping embedded FEAGI...")
		_feagi_embedded_instance.shutdown()
		_feagi_embedded_instance = null
		print("   ✅ Embedded FEAGI shut down")
	
	# Stop FEAGI subprocess if running
	if FeagiProcessManager.is_running():
		var pid = FeagiProcessManager._process_id if FeagiProcessManager._process_id > 0 else 0
		print("   🐧 Stopping FEAGI subprocess (PID: %d)..." % pid)
		if _ui_manager:
			await _ui_manager.update_shutdown_status("Stopping FEAGI subprocess...")
		print("   🔍 Process running check: %s" % str(OS.is_process_running(pid)))
		FeagiProcessManager.stop_feagi()
		print("   ✅ FEAGI subprocess stop_feagi() completed")
		print("   🔍 Process still running after stop: %s" % str(OS.is_process_running(pid)))
	
	if not _feagi_embedded_instance and not FeagiProcessManager.is_running():
		print("   ℹ️ No FEAGI instances were running")
	
	print("─" . repeat(60))
	print("✅ FEAGI SHUTDOWN COMPLETE")
	print("─" . repeat(60))
	print("")

## Shutdown FEAGI gracefully (sync version for emergency)
func _shutdown_feagi() -> void:
	print("")
	print("─" . repeat(60))
	print("🔌 SHUTTING DOWN FEAGI")
	print("─" . repeat(60))
	
	# Shutdown embedded FEAGI if running
	if _feagi_embedded_instance:
		print("   🦀 Shutting down embedded FEAGI extension...")
		_feagi_embedded_instance.shutdown()
		_feagi_embedded_instance = null
		print("   ✅ Embedded FEAGI shut down")
	
	# Stop FEAGI subprocess if running
	if FeagiProcessManager.is_running():
		var pid = FeagiProcessManager._process_id if FeagiProcessManager._process_id > 0 else 0
		print("   🐧 Stopping FEAGI subprocess (PID: %d)..." % pid)
		print("   🔍 Process running check: %s" % str(OS.is_process_running(pid)))
		FeagiProcessManager.stop_feagi()
		print("   ✅ FEAGI subprocess stop_feagi() completed")
		print("   🔍 Process still running after stop: %s" % str(OS.is_process_running(pid)))
	
	if not _feagi_embedded_instance and not FeagiProcessManager.is_running():
		print("   ℹ️ No FEAGI instances were running")
	
	print("─" . repeat(60))
	print("✅ FEAGI SHUTDOWN COMPLETE")
	print("─" . repeat(60))
	print("")

## Clean up all state directories (async version with UI updates)
func _cleanup_all_state_async() -> void:
	if OS.has_feature("editor"):
		print("   ℹ️ [ShutdownManager] Skipping cleanup in editor mode (for debugging)")
		return
	
	print("")
	print("─" . repeat(60))
	print("🧹 CLEANING UP STATE")
	print("─" . repeat(60))
	
	var cleaned_anything = false
	
	# Clean up FEAGI working directory
	if _ui_manager:
		await _ui_manager.update_shutdown_status("Removing FEAGI working directory...")
	cleaned_anything = _cleanup_feagi_working_directory() or cleaned_anything
	
	# Clean up FEAGI launch logs
	if _ui_manager:
		await _ui_manager.update_shutdown_status("Removing FEAGI logs...")
	cleaned_anything = _cleanup_feagi_launch_logs() or cleaned_anything
	
	# Future: Add more cleanup locations here
	# - User cache
	# - Temporary files
	# - Network state
	
	if not cleaned_anything:
		print("   ℹ️ Nothing to clean up")
	
	print("─" . repeat(60))
	print("✅ CLEANUP COMPLETE")
	print("─" . repeat(60))
	print("")

## Clean up all state directories (sync version for emergency)
func _cleanup_all_state() -> void:
	if OS.has_feature("editor"):
		print("   ℹ️ [ShutdownManager] Skipping cleanup in editor mode (for debugging)")
		return
	
	print("")
	print("─" . repeat(60))
	print("🧹 CLEANING UP STATE")
	print("─" . repeat(60))
	
	var cleaned_anything = false
	
	# Clean up FEAGI working directory
	cleaned_anything = _cleanup_feagi_working_directory() or cleaned_anything
	
	# Clean up FEAGI launch logs
	cleaned_anything = _cleanup_feagi_launch_logs() or cleaned_anything
	
	# Future: Add more cleanup locations here
	# - User cache
	# - Temporary files
	# - Network state
	
	if not cleaned_anything:
		print("   ℹ️ Nothing to clean up")
	
	print("─" . repeat(60))
	print("✅ CLEANUP COMPLETE")
	print("─" . repeat(60))
	print("")

## Clean up FEAGI's working directory
## Returns true if anything was cleaned
func _cleanup_feagi_working_directory() -> bool:
	var state_dir = OS.get_environment("HOME") + "/Library/Application Support/BrainVisualizer/feagi"
	
	print("   📂 Checking FEAGI working directory...")
	print("      Path: %s" % state_dir)
	
	# Check if directory exists
	if not DirAccess.dir_exists_absolute(state_dir):
		print("      ℹ️ Directory doesn't exist (nothing to clean)")
		return false
	
	# Remove entire directory and all contents
	print("      🗑️ Removing entire FEAGI working directory...")
	_remove_directory_recursive(state_dir)
	
	print("      ✅ FEAGI working directory completely removed")
	return true

## Clean up FEAGI launch logs
## Returns true if anything was cleaned
func _cleanup_feagi_launch_logs() -> bool:
	var log_dir = OS.get_environment("HOME") + "/Library/Logs/BrainVisualizer"
	
	print("   📂 Checking FEAGI launch logs...")
	print("      Path: %s" % log_dir)
	
	var dir = DirAccess.open(log_dir)
	if not dir:
		print("      ℹ️ Directory doesn't exist (nothing to clean)")
		return false
	
	var cleaned = false
	
	# Remove feagi_launch.log
	if FileAccess.file_exists(log_dir + "/feagi_launch.log"):
		print("      🗑️ Removing feagi_launch.log...")
		DirAccess.remove_absolute(log_dir + "/feagi_launch.log")
		cleaned = true
	
	if cleaned:
		print("      ✅ FEAGI launch logs cleaned")
	else:
		print("      ℹ️ No launch logs to clean")
	
	return cleaned

## Recursively remove a directory and all its contents
func _remove_directory_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("      ⚠️ Failed to open directory for removal: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path + "/" + file_name
			if dir.current_is_dir():
				_remove_directory_recursive(full_path)
			else:
				var error = dir.remove(file_name)
				if error != OK:
					push_warning("      ⚠️ Failed to remove file: %s (error: %d)" % [file_name, error])
		file_name = dir.get_next()
	dir.list_dir_end()
	
	var error = DirAccess.remove_absolute(path)
	if error != OK:
		push_warning("      ⚠️ Failed to remove directory: %s (error: %d)" % [path, error])

