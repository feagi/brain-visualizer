extends SceneTree
## A looping tween whose lambda captures a child node must be bound to that child,
## so freeing the child ends the tween without Godot's "Lambda capture ... was freed" error.
## Run (one mode per process, so stderr can be counted):
##   godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_tween_bound_to_animated_node.gd -- old
##   godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_tween_bound_to_animated_node.gd -- new
## "old" is the faulty pattern (tween owned by the parent) and is expected to log the error;
## "new" binds the tween to the child (child not yet in the tree when the tween is created)
## and must log nothing, while the tween still runs before the child is freed.

var _mode: String = "new"
var _parent: Node3D
var _child: Node3D
var _ticks: Array[int] = [0]
var _frame: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	_parent = Node3D.new()
	root.add_child(_parent)
	_child = Node3D.new()
	var ticks := _ticks
	var child := _child
	var step := func(_value: float) -> void:
		ticks[0] += 1
		child.position.x = _value
	var tween: Tween
	if _mode == "old":
		tween = _parent.create_tween()
	else:
		tween = _parent.create_tween().bind_node(_child)
	tween.set_loops()
	tween.tween_method(step, 0.0, 1.0, 0.05)
	_parent.add_child(_child)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 10:
		if _ticks[0] == 0:
			push_error("Tween never ran before the child was freed")
			quit(1)
			return true
		print("ticks before free: %d" % _ticks[0])
		_child.free()
	elif _frame == 20:
		print("Tween bound-to-animated-node test (%s): done" % _mode)
		quit(0)
	return false
