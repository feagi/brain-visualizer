extends SceneTree
## Parse check for the Shift title reveal call. Deleted after the run.


func _initialize() -> void:
	var scene_script: GDScript = load("res://addons/UI_BrainMonitor/UI_BrainMonitor_3DScene.gd")
	if scene_script == null:
		push_error("UI_BrainMonitor_3DScene failed to parse")
		quit(1)
		return
	print("UI_BrainMonitor_3DScene parsed")
	quit(0)
