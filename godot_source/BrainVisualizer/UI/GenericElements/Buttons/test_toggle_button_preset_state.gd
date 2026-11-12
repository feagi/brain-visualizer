extends SceneTree
## ToggleButton keeps pressed state set before it enters the tree.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/GenericElements/Buttons/test_toggle_button_preset_state.gd

const ToggleScript = preload("res://BrainVisualizer/UI/GenericElements/Buttons/ToggleButton.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var toggle = ToggleScript.new()
	toggle.enable_autoscaling_with_theme = false # avoids the BV autoload
	toggle.set_toggle_no_signal(true)
	root.add_child(toggle)
	await process_frame
	if not toggle.button_pressed or toggle.texture_normal != ToggleScript.TEX_ENABLED_ON:
		push_error("ToggleButton lost pressed state set before add_child")
		quit(1)
		return
	print("ToggleButton preset state test: PASS")
	quit(0)
