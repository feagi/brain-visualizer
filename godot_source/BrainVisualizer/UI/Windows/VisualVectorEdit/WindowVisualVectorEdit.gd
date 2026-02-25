extends BaseDraggableWindow
class_name WindowVisualVectorEdit
## Visual editor for vector connectivity rules. Multiple Z slices, click-to-toggle grid.

const WINDOW_NAME: StringName = &"visual_vector_edit"

var _grid: VectorEditGrid
var _z_prev: Button
var _z_next: Button
var _z_spin: SpinBox
var _cancel_button: Button
var _save_button: Button
var _on_save: Callable
var _z_min: int = -10
var _z_max: int = 10

func _ready() -> void:
	super()
	_grid = $WindowPanel/WindowMargin/WindowInternals/GridContainer/VectorEditGrid
	_z_prev = $WindowPanel/WindowMargin/WindowInternals/ZRow/ZPrev
	_z_next = $WindowPanel/WindowMargin/WindowInternals/ZRow/ZNext
	_z_spin = $WindowPanel/WindowMargin/WindowInternals/ZRow/ZSpin
	_cancel_button = $WindowPanel/WindowMargin/WindowInternals/ButtonRow/Cancel
	_save_button = $WindowPanel/WindowMargin/WindowInternals/ButtonRow/Save

	_grid.setup()
	_z_prev.pressed.connect(_on_z_prev)
	_z_next.pressed.connect(_on_z_next)
	_z_spin.value_changed.connect(_on_z_spin_changed)
	_cancel_button.pressed.connect(close_window)
	_save_button.pressed.connect(_on_save_pressed)

func setup(initial_vectors: Array[Vector3i], on_save: Callable) -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Visual Edit - Vectors"
	_on_save = on_save

	var selection: Dictionary = {}
	var z_vals: Array[int] = []
	for v in initial_vectors:
		selection[_vec_key(v.x, v.y, v.z)] = true
		if v.z not in z_vals:
			z_vals.append(v.z)

	z_vals.sort()
	if !z_vals.is_empty():
		_z_min = mini(_z_min, z_vals[0])
		_z_max = maxi(_z_max, z_vals[z_vals.size() - 1])

	_z_spin.min_value = _z_min
	_z_spin.max_value = _z_max
	var initial_z: int = z_vals[0] if !z_vals.is_empty() else 0
	_z_spin.value = initial_z
	_grid.set_full_selection(selection)
	_grid.set_current_z(initial_z)

func _vec_key(x: int, y: int, z: int) -> String:
	return str(x) + "," + str(y) + "," + str(z)

func _on_z_prev() -> void:
	var v: float = _z_spin.value
	if v > _z_spin.min_value:
		_z_spin.value = v - 1
	else:
		_z_spin.min_value = int(v) - 1
		_z_spin.value = v - 1

func _on_z_next() -> void:
	var v: float = _z_spin.value
	if v < _z_spin.max_value:
		_z_spin.value = v + 1
	else:
		_z_spin.max_value = int(v) + 1
		_z_spin.value = v + 1

func _on_z_spin_changed(_new_value: float) -> void:
	_grid.set_current_z(int(_z_spin.value))

func _on_save_pressed() -> void:
	var sel: Dictionary = _grid.get_full_selection()
	var vectors: Array[Vector3i] = []
	for key in sel.keys():
		var parts: PackedStringArray = key.split(",", false)
		if parts.size() == 3:
			vectors.append(Vector3i(int(parts[0]), int(parts[1]), int(parts[2])))
	vectors.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z: return a.z < b.z
		if a.y != b.y: return a.y < b.y
		return a.x < b.x
	)
	_on_save.call(vectors)
	close_window()
