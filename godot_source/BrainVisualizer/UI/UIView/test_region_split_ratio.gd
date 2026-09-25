extends SceneTree
## Region split gives Circuit Builder 40% and Brain Monitor tabs 60%.
## Run: godot --headless -s res://BrainVisualizer/UI/UIView/test_region_split_ratio.gd

const UI_VIEW_SCENE := "res://BrainVisualizer/UI/UIView/UIView.tscn"


func _initialize() -> void:
	var failures: int = _test_region_split_is_forty_sixty()
	if failures == 0:
		print("Region split ratio tests: PASS")
		quit(0)
	else:
		push_error("Region split ratio tests: FAIL (%d)" % failures)
		quit(1)


func _test_region_split_is_forty_sixty() -> int:
	var packed: PackedScene = load(UI_VIEW_SCENE) as PackedScene
	if packed == null:
		push_error("UIView scene failed to load")
		return 1
	var view: UIView = packed.instantiate() as UIView
	if view == null:
		push_error("UIView scene root is not UIView")
		return 1
	root.add_child(view)
	var primary: Control = view.get_node("SplitContainer/Primary")
	var secondary: Control = view.get_node("SplitContainer/Secondary")
	if not is_equal_approx(primary.size_flags_stretch_ratio, UIView.REGION_SPLIT_CIRCUIT_BUILDER_STRETCH):
		push_error("Circuit builder pane must use the 40% stretch ratio")
		return 1
	if not is_equal_approx(secondary.size_flags_stretch_ratio, UIView.REGION_SPLIT_BRAIN_MONITOR_STRETCH):
		push_error("Brain monitor pane must use the 60% stretch ratio")
		return 1
	var split: SplitContainer = view.get_node("SplitContainer")
	if not split.vertical:
		push_error("Region split must stack circuit builder above brain monitor")
		return 1
	var share: float = UIView.REGION_SPLIT_CIRCUIT_BUILDER_STRETCH / (
		UIView.REGION_SPLIT_CIRCUIT_BUILDER_STRETCH + UIView.REGION_SPLIT_BRAIN_MONITOR_STRETCH
	)
	if not is_equal_approx(share, 0.4):
		push_error("Circuit builder share must be 40%")
		return 1
	return 0
