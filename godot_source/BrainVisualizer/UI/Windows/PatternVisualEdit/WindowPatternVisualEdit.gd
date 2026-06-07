extends BaseDraggableWindow
class_name WindowPatternVisualEdit
## Per-pair visual editor for pattern connectivity. Editable form on top, read-only grids below.
## When the source pattern matches multiple neurons and the destination uses relative patterns,
## a hint instructs the user to hover over source cells to preview destination matches.

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
var _hover_hint_label: Label
var _on_save: Callable
## Whether interactive hover mode is active (multiple sources + relative destination)
var _hover_mode_active: bool = false

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

	_hover_hint_label = Label.new()
	_hover_hint_label.text = "Hover over a source cell to preview its destination connections"
	_hover_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	_hover_hint_label.visible = false
	$WindowPanel/WindowMargin/WindowInternals.add_child(_hover_hint_label)
	$WindowPanel/WindowMargin/WindowInternals.move_child(_hover_hint_label, 2)

	_grid_source.setup()
	_grid_dest.setup()

	_grid_source.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_source.gui_input.connect(_on_source_grid_input)

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
	if _hover_mode_active:
		_grid_dest.clear_reference_coordinate()

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
	var src_vec: PatternVector3 = _form_source.current_vector
	var dst_vec: PatternVector3 = _form_dest.current_vector

	_grid_source.set_pattern(src_vec)
	_grid_dest.set_pattern(dst_vec)
	_grid_source.set_current_z(int(_z_source_spin.value))
	_grid_dest.set_current_z(int(_z_dest_spin.value))

	var source_matches_multiple: bool = _pattern_matches_multiple(src_vec)
	var dest_has_relative: bool = _pattern_has_relative(dst_vec)

	_hover_mode_active = source_matches_multiple and dest_has_relative
	_hover_hint_label.visible = _hover_mode_active

	if _hover_mode_active:
		_grid_dest.clear_reference_coordinate()
		_grid_source.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		var ref: Vector3i = Vector3i(
			int(src_vec.x.data) if src_vec.x.isInt else PatternPreviewGrid.DEFAULT_RADIUS,
			int(src_vec.y.data) if src_vec.y.isInt else PatternPreviewGrid.DEFAULT_RADIUS,
			int(_z_source_spin.value)
		)
		_grid_dest.set_reference_coordinate(ref)
		_grid_source.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _on_source_grid_input(event: InputEvent) -> void:
	if !_hover_mode_active:
		return
	if event is InputEventMouseMotion:
		var cell_coord: Vector2i = _grid_source.get_cell_at_position(event.position)
		if cell_coord.x >= 0:
			var ref: Vector3i = Vector3i(cell_coord.x, cell_coord.y, int(_z_source_spin.value))
			_grid_dest.set_reference_coordinate(ref)

## Returns true if a PatternVector3 matches more than one coordinate on any axis.
func _pattern_matches_multiple(pv: PatternVector3) -> bool:
	return !pv.x.isInt or !pv.y.isInt or !pv.z.isInt

## Returns true if a PatternVector3 contains any source-relative pattern element.
func _pattern_has_relative(pv: PatternVector3) -> bool:
	return pv.x.isRelative or pv.y.isRelative or pv.z.isRelative

func _on_save_pressed() -> void:
	var pair: PatternVector3Pairs = PatternVector3Pairs.new(_form_source.current_vector, _form_dest.current_vector)
	_on_save.call(pair)
	close_window()
