extends BaseDraggableWindow
class_name WindowPatternVisualEdit
## Per-pair visual editor for pattern connectivity. Editable form on top, read-only grids below.

const WINDOW_NAME: StringName = &"pattern_visual_edit"
## Max Z coordinate; matches cortical-area-acceptable max from Vector3iField/Vector3iSpinboxField
const Z_MAX: int = 9999999999

var _form_source: PatternVector3Field
var _form_dest: PatternVector3Field
var _grid_source: PatternPreviewGrid
var _grid_dest: PatternPreviewGrid
var _z_source_prev: Button
var _z_source_next: Button
var _z_source_spin: SpinBox
var _z_dest_prev: Button
var _z_dest_next: Button
var _z_dest_spin: SpinBox
var _cancel_button: Button
var _save_button: Button
var _on_save: Callable

func _ready() -> void:
	super()
	_form_source = $WindowPanel/WindowMargin/WindowInternals/FormRow/SourceField
	_form_dest = $WindowPanel/WindowMargin/WindowInternals/FormRow/DestField
	_grid_source = $WindowPanel/WindowMargin/WindowInternals/GridsRow/SourceSide/SourceGrid
	_grid_dest = $WindowPanel/WindowMargin/WindowInternals/GridsRow/DestSide/DestGrid
	_z_source_prev = $WindowPanel/WindowMargin/WindowInternals/GridsRow/SourceSide/ZRow/ZPrev
	_z_source_next = $WindowPanel/WindowMargin/WindowInternals/GridsRow/SourceSide/ZRow/ZNext
	_z_source_spin = $WindowPanel/WindowMargin/WindowInternals/GridsRow/SourceSide/ZRow/ZSpin
	_z_dest_prev = $WindowPanel/WindowMargin/WindowInternals/GridsRow/DestSide/ZRow/ZPrev
	_z_dest_next = $WindowPanel/WindowMargin/WindowInternals/GridsRow/DestSide/ZRow/ZNext
	_z_dest_spin = $WindowPanel/WindowMargin/WindowInternals/GridsRow/DestSide/ZRow/ZSpin
	_cancel_button = $WindowPanel/WindowMargin/WindowInternals/ButtonRow/Cancel
	_save_button = $WindowPanel/WindowMargin/WindowInternals/ButtonRow/Save

	_grid_source.setup()
	_grid_dest.setup()

	_form_source.user_updated_vector.connect(_on_form_changed)
	_form_dest.user_updated_vector.connect(_on_form_changed)

	_z_source_spin.value_changed.connect(_on_z_source_changed)
	_z_dest_spin.value_changed.connect(_on_z_dest_changed)
	_z_source_prev.pressed.connect(_on_z_source_prev)
	_z_source_next.pressed.connect(_on_z_source_next)
	_z_dest_prev.pressed.connect(_on_z_dest_prev)
	_z_dest_next.pressed.connect(_on_z_dest_next)
	_z_source_spin.min_value = 0
	_z_source_spin.max_value = Z_MAX
	_z_dest_spin.min_value = 0
	_z_dest_spin.max_value = Z_MAX

	_cancel_button.pressed.connect(close_window)
	_save_button.pressed.connect(_on_save_pressed)

func setup(initial_pair: PatternVector3Pairs, on_save: Callable) -> void:
	_setup_base_window(WINDOW_NAME)
	_titlebar.title = "Visual Edit - Pattern Pair"
	_on_save = on_save

	_form_source.current_vector = initial_pair.incoming
	_form_dest.current_vector = initial_pair.outgoing

	_z_source_spin.value = 0
	_z_dest_spin.value = 0
	_update_z_prev_buttons()

	_refresh_grids()

func _on_form_changed(_pv: PatternVector3) -> void:
	_refresh_grids()

func _on_z_source_changed(_v: float) -> void:
	var z: int = maxi(0, int(_z_source_spin.value))
	_z_source_spin.value = z
	_grid_source.set_current_z(z)
	_update_z_prev_buttons()

func _on_z_dest_changed(_v: float) -> void:
	var z: int = maxi(0, int(_z_dest_spin.value))
	_z_dest_spin.value = z
	_grid_dest.set_current_z(z)
	_update_z_prev_buttons()

func _on_z_source_prev() -> void:
	if _z_source_spin.value > 0:
		_z_source_spin.value = _z_source_spin.value - 1

func _on_z_source_next() -> void:
	_z_source_spin.value = _z_source_spin.value + 1

func _on_z_dest_prev() -> void:
	if _z_dest_spin.value > 0:
		_z_dest_spin.value = _z_dest_spin.value - 1

func _on_z_dest_next() -> void:
	_z_dest_spin.value = _z_dest_spin.value + 1

func _update_z_prev_buttons() -> void:
	_z_source_prev.disabled = _z_source_spin.value <= 0
	_z_dest_prev.disabled = _z_dest_spin.value <= 0

func _refresh_grids() -> void:
	_grid_source.set_pattern(_form_source.current_vector)
	_grid_dest.set_pattern(_form_dest.current_vector)
	_grid_source.set_current_z(int(_z_source_spin.value))
	_grid_dest.set_current_z(int(_z_dest_spin.value))

func _on_save_pressed() -> void:
	var pair: PatternVector3Pairs = PatternVector3Pairs.new(_form_source.current_vector, _form_dest.current_vector)
	_on_save.call(pair)
	close_window()
