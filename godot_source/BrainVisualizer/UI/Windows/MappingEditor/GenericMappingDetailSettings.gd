extends VBoxContainer
class_name GenericMappingDetailSettings

const PREFAB_ROW: PackedScene = preload("res://BrainVisualizer/UI/Windows/MappingEditor/MappingEditorRowGeneric.tscn")

## Matches [ScrollSectionGeneric] min height in [member GenericMappingDetailSettings._scroll] scene (default list footprint).
const ESTABLISHED_SCROLL_MIN_HEIGHT_PX: float = 200.0
## Beyond this many rows, the list keeps a fixed viewport height and scrolls.
const ESTABLISHED_SCROLL_MAX_VISIBLE_ITEMS: int = 10
## Approximate rows that fit in [constant ESTABLISHED_SCROLL_MIN_HEIGHT_PX] before dynamic refit; used only if layout has not produced a row height yet.
const ESTABLISHED_SCROLL_APPROX_ROWS_AT_MIN_HEIGHT: float = 3.0

## Operate-mode table: single source of truth for column geometry. Used for the header label cells here and for
## the MainRow cells in [MappingEditorRowGeneric], so header and fields line up by construction.
## Order: mapping (dropdown 240 + 4 + edit 32), scalar (3 x 56 + 2 x 4), PSP, delay, inhibitory, modulators (min, expands), plasticity, actions.
const COLUMN_WIDTHS: Array[int] = [276, 176, 96, 64, 80, 280, 128, 32]
const COLUMN_GAP_PX: int = 16
const COLUMN_EXPANDING_INDEX: int = 5
const FIELD_HEIGHT_PX: float = 32.0
const ROW_GAP_PX: int = 8
const WINDOW_SIDE_MARGIN_PX: int = 16

signal user_changed_something()

var _restrictions: MappingRestrictionCorticalMorphology
var _defaults: MappingRestrictionDefault

var _add_button: Button
var _add_row: Control
var _established_scroll_viewport: Control
var _header_row_wrapper: HBoxContainer
var _scroll: ScrollSectionGeneric
var _empty_state: VBoxContainer

func _ready() -> void:
	_established_scroll_viewport = $EstablishedScrollViewport
	_header_row_wrapper = $HeaderRowWrapper
	_scroll = $EstablishedScrollViewport/ScrollSectionGeneric
	_add_button = $AddRow/add_button
	_add_row = $AddRow
	_empty_state = $EmptyState
	_established_scroll_viewport.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_header_column_layout()
	_scroll.get_node("BoxContainer").add_theme_constant_override(&"separation", int(scaled_px(ROW_GAP_PX)))
	_add_row.get_node("Gap").custom_minimum_size.y = scaled_px(ROW_GAP_PX)
	_established_scroll_viewport.custom_minimum_size.y = 0.0
	_scroll.item_about_to_be_deleted.connect(_on_scroll_item_about_to_be_deleted)
	if BV and BV.UI and not BV.UI.theme_changed.is_connected(_on_theme_changed):
		BV.UI.theme_changed.connect(_on_theme_changed)
	if not _scroll.resized.is_connected(_on_scroll_or_viewport_resized):
		_scroll.resized.connect(_on_scroll_or_viewport_resized)
	if not _established_scroll_viewport.resized.is_connected(_on_scroll_or_viewport_resized):
		_established_scroll_viewport.resized.connect(_on_scroll_or_viewport_resized)

## Current UI scale (theme generic_scale / 4). The table is authored in unscaled px and multiplied by this, for the
## header and the rows alike. Rows live in a [ScrollSectionGeneric] whose [ScaleThemeApplier] and the scaled dropdowns
## resize their children by this factor, so unscaled header cells drifted away from the row cells.
static func ui_scale() -> float:
	if BV != null and BV.UI != null:
		return maxf(BV.UI.loaded_theme_scale.x, 0.01)
	return 1.0

static func scaled_px(px: float) -> float:
	return roundf(px * ui_scale())

## Total width of all columns plus gaps at the current UI scale (excludes the window side margins).
static func get_table_min_width() -> float:
	var total: int = COLUMN_GAP_PX * (COLUMN_WIDTHS.size() - 1)
	for w in COLUMN_WIDTHS:
		total += w
	return scaled_px(float(total))

## Sizes the header label cells from [constant COLUMN_WIDTHS]. Labels are single-line, left-aligned and bottom-aligned.
func _apply_header_column_layout() -> void:
	var header_root := $HeaderRowWrapper/labels_box as HBoxContainer
	header_root.add_theme_constant_override(&"separation", int(scaled_px(COLUMN_GAP_PX)))
	var cells: Array[Node] = header_root.get_children()
	for i in mini(cells.size(), COLUMN_WIDTHS.size()):
		var cell: Control = cells[i] as Control
		cell.custom_minimum_size = Vector2(scaled_px(COLUMN_WIDTHS[i]), 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i == COLUMN_EXPANDING_INDEX else Control.SIZE_SHRINK_BEGIN
		var lab := cell as Label
		if lab != null:
			lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			lab.clip_text = false
			lab.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func clear() -> void:
	_scroll.remove_all_items()

func load_mappings(mappings: Array[SingleMappingDefinition], restrictions: MappingRestrictionCorticalMorphology, defaults: MappingRestrictionDefault) -> void:
	clear()
	_restrictions = restrictions
	_defaults = defaults
	
	if len(mappings) == 0:
		_show_empty_state()
		return
	
	_show_table_state()
	for mapping in mappings:
		_import_single_mapping_no_refit(mapping)
	if restrictions != null and restrictions.has_max_number_mappings():
		_add_button.disabled = restrictions.max_number_mappings < len(mappings)
	_queue_refit_established_scroll_viewport()

func _show_empty_state() -> void:
	_empty_state.visible = true
	_header_row_wrapper.visible = false
	_established_scroll_viewport.visible = false
	_add_row.visible = false

func _show_table_state() -> void:
	_empty_state.visible = false
	_header_row_wrapper.visible = true
	_established_scroll_viewport.visible = true
	_add_row.visible = true

func export_mappings() -> Array[SingleMappingDefinition]:
	var mappings: Array[SingleMappingDefinition] = []
	var list_items: Array[ScrollSectionGenericItem] = _scroll.get_all_spawned_children_of_container()
	for item in list_items:
		var mapping_row: MappingEditorRowGeneric = item.get_control()
		mappings.append(mapping_row.export_mapping())
	return mappings

func import_single_mapping(mapping: SingleMappingDefinition) -> void:
	_import_single_mapping_no_refit(mapping)
	_queue_refit_established_scroll_viewport()

func _import_single_mapping_no_refit(mapping: SingleMappingDefinition) -> void:
	var row: MappingEditorRowGeneric = PREFAB_ROW.instantiate()
	var item: ScrollSectionGenericItem = _scroll.add_generic_item(row, null, "") #NOTE: Doing this first so _ready has a chance to run
	row.sub_row_visibility_changed.connect(_queue_refit_established_scroll_viewport)
	row.minimum_size_changed.connect(_queue_refit_established_scroll_viewport)
	row.load_settings(_restrictions, _defaults)
	row.load_mapping(mapping)
	item.about_to_be_deleted.connect(_on_row_deletion)

func _add_mapping_row() -> void:
	_show_table_state()
	var row: MappingEditorRowGeneric = PREFAB_ROW.instantiate()
	var item: ScrollSectionGenericItem = _scroll.add_generic_item(row, null, "")
	item.about_to_be_deleted.connect(_on_row_deletion)
	row.sub_row_visibility_changed.connect(_queue_refit_established_scroll_viewport)
	row.minimum_size_changed.connect(_queue_refit_established_scroll_viewport)
	row.load_settings(_restrictions, _defaults)
	if _restrictions != null and _restrictions.has_max_number_mappings():
		_add_button.disabled = _restrictions.max_number_mappings >= _scroll.get_item_count()
	_queue_refit_established_scroll_viewport()

func _on_scroll_item_about_to_be_deleted(_item: ScrollSectionGenericItem) -> void:
	_queue_refit_established_scroll_viewport()
	if _scroll.get_item_count() <= 1:
		call_deferred("_show_empty_state")

## Returns the first row problem that would make FEAGI reject the mapping (for example R-STDP
## without a reward modulator), or "" when every row is sendable.
func get_validation_error() -> String:
	var list_items: Array[ScrollSectionGenericItem] = _scroll.get_all_spawned_children_of_container()
	for item in list_items:
		var mapping_row: MappingEditorRowGeneric = item.get_control()
		var error: String = mapping_row.get_validation_error()
		if not error.is_empty():
			return error
	return ""

func _on_row_deletion(item: ScrollSectionGenericItem) -> void:
	_queue_refit_established_scroll_viewport()
	if _restrictions != null and _restrictions.has_max_number_mappings():
		_add_button.disabled = _restrictions.max_number_mappings < _scroll.get_item_count() - 1
	if _scroll.get_item_count() <= 1:
		call_deferred("_show_empty_state")

func _queue_refit_established_scroll_viewport() -> void:
	if not is_node_ready():
		return
	call_deferred("_refit_established_scroll_viewport_async")

func _on_theme_changed(_new_theme: Theme) -> void:
	_apply_header_column_layout()
	_scroll.get_node("BoxContainer").add_theme_constant_override(&"separation", int(scaled_px(ROW_GAP_PX)))
	_add_row.get_node("Gap").custom_minimum_size.y = scaled_px(ROW_GAP_PX)
	_queue_refit_established_scroll_viewport()

func _on_scroll_or_viewport_resized() -> void:
	_queue_refit_established_scroll_viewport()

func _refit_established_scroll_viewport_async() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_scroll) or not is_instance_valid(_established_scroll_viewport):
		return
	var box: Container = _scroll.get_node("BoxContainer") as Container
	var count: int = box.get_child_count()
	if count == 0:
		_established_scroll_viewport.custom_minimum_size = Vector2(_established_scroll_viewport.custom_minimum_size.x, 0.0)
		_apply_header_scroll_content_width()
		return
	var content_h: float = box.get_combined_minimum_size().y
	var sep: int = box.get_theme_constant("separation", "VBoxContainer")
	# Cap = the first N rows' actual minimum heights (rows grow when modulator chips wrap) plus separators.
	var max_viewport_for_cap: float = 0.0
	var counted: int = mini(count, ESTABLISHED_SCROLL_MAX_VISIBLE_ITEMS)
	for i in counted:
		max_viewport_for_cap += (box.get_child(i) as Control).get_combined_minimum_size().y
	max_viewport_for_cap += float(sep * max(0, counted - 1))
	if count < ESTABLISHED_SCROLL_MAX_VISIBLE_ITEMS:
		max_viewport_for_cap = content_h
	# Size to content (no minimum) up to the cap, then the list scrolls; "+ Add mapping" sits right below the last row.
	var viewport_h: float = minf(content_h, max_viewport_for_cap)
	_established_scroll_viewport.custom_minimum_size = Vector2(_established_scroll_viewport.custom_minimum_size.x, viewport_h)
	await get_tree().process_frame
	await get_tree().process_frame
	_sync_header_to_scroll_row()

func _get_header_strip_width_to_match_row() -> float:
	var list_items: Array[ScrollSectionGenericItem] = _scroll.get_all_spawned_children_of_container()
	if not list_items.is_empty():
		var wrapper: Control = list_items[0] as Control
		var w: float = wrapper.size.x
		if w > 0.001:
			return w
	var scroll: ScrollContainer = _scroll as ScrollContainer
	var fallback: float = scroll.size.x
	if fallback <= 0.001:
		fallback = scroll.get_combined_minimum_size().x
	return maxf(fallback, 0.0)

func _apply_header_scroll_content_width() -> void:
	if not is_instance_valid(_header_row_wrapper) or not is_instance_valid(_scroll):
		return
	var w: float = _get_header_strip_width_to_match_row()
	if w <= 0.001:
		return
	_header_row_wrapper.custom_minimum_size.x = w
	_header_row_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func _sync_header_to_scroll_row() -> void:
	_apply_header_scroll_content_width()
