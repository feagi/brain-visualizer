extends VBoxContainer
class_name GenericMappingDetailSettings

const PREFAB_ROW: PackedScene = preload("res://BrainVisualizer/UI/Windows/MappingEditor/MappingEditorRowGeneric.tscn")

## Matches [ScrollSectionGeneric] min height in [member GenericMappingDetailSettings._scroll] scene (default list footprint).
const ESTABLISHED_SCROLL_MIN_HEIGHT_PX: float = 200.0
## Beyond this many rows, the list keeps a fixed viewport height and scrolls.
const ESTABLISHED_SCROLL_MAX_VISIBLE_ITEMS: int = 10
## Approximate rows that fit in [constant ESTABLISHED_SCROLL_MIN_HEIGHT_PX] before dynamic refit; used only if layout has not produced a row height yet.
const ESTABLISHED_SCROLL_APPROX_ROWS_AT_MIN_HEIGHT: float = 3.0

signal user_changed_something()

var _restrictions: MappingRestrictionCorticalMorphology
var _defaults: MappingRestrictionDefault

var _add_button: TextureButton
## Wrapper for the established-mappings scroll; list height is set only through custom_minimum_size (custom_maximum_size is not assignable on this Control in this build).
var _established_scroll_viewport: Control
var _scroll: ScrollSectionGeneric

func _ready() -> void:
	_established_scroll_viewport = $EstablishedScrollViewport
	_scroll = $EstablishedScrollViewport/ScrollSectionGeneric
	_add_button = $labels_box/add_button
	# Shrink to [member Control.custom_minimum_size] height so the list does not expand past the computed viewport.
	_established_scroll_viewport.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.item_about_to_be_deleted.connect(_on_scroll_item_about_to_be_deleted)

func clear() -> void:
	_scroll.remove_all_items()

func load_mappings(mappings: Array[SingleMappingDefinition], restrictions: MappingRestrictionCorticalMorphology, defaults: MappingRestrictionDefault) -> void:
	clear()
	_restrictions = restrictions
	_defaults = defaults
	for mapping in mappings:
		_import_single_mapping_no_refit(mapping)
	if restrictions != null and restrictions.has_max_number_mappings():
		_add_button.disabled = restrictions.max_number_mappings < len(mappings)
	_queue_refit_established_scroll_viewport()

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
	row.load_settings(_restrictions, _defaults)
	row.load_mapping(mapping)
	item.about_to_be_deleted.connect(_on_row_deletion)

func _add_mapping_row() -> void:
	var row: MappingEditorRowGeneric = PREFAB_ROW.instantiate()
	var item: ScrollSectionGenericItem = _scroll.add_generic_item(row, null, "")
	item.about_to_be_deleted.connect(_on_row_deletion)
	row.load_settings(_restrictions, _defaults)
	if _restrictions != null and _restrictions.has_max_number_mappings():
		_add_button.disabled = _restrictions.max_number_mappings >= _scroll.get_item_count()
	_queue_refit_established_scroll_viewport()

func _on_scroll_item_about_to_be_deleted(_item: ScrollSectionGenericItem) -> void:
	_queue_refit_established_scroll_viewport()

func _on_row_deletion(item: ScrollSectionGenericItem) -> void:
	if _restrictions != null and _restrictions.has_max_number_mappings():
		_add_button.disabled = _restrictions.max_number_mappings < _scroll.get_item_count() - 1 # Subtract 1 since it is about to be 1 less

func _queue_refit_established_scroll_viewport() -> void:
	if not is_node_ready():
		return
	call_deferred("_refit_established_scroll_viewport_async")

func _refit_established_scroll_viewport_async() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_scroll) or not is_instance_valid(_established_scroll_viewport):
		return
	var box: Container = _scroll.get_node("BoxContainer") as Container
	var count: int = box.get_child_count()
	if count == 0:
		_established_scroll_viewport.custom_minimum_size = Vector2(_established_scroll_viewport.custom_minimum_size.x, ESTABLISHED_SCROLL_MIN_HEIGHT_PX)
		return
	var content_h: float = box.size.y
	var sep: int = box.get_theme_constant("separation", "VBoxContainer")
	var first: Control = box.get_child(0) as Control
	var row_h: float = first.size.y
	if row_h <= 0.001:
		row_h = first.get_combined_minimum_size().y
	if row_h <= 0.001:
		row_h = ESTABLISHED_SCROLL_MIN_HEIGHT_PX / ESTABLISHED_SCROLL_APPROX_ROWS_AT_MIN_HEIGHT
	var max_viewport_for_cap: float = row_h * float(ESTABLISHED_SCROLL_MAX_VISIBLE_ITEMS) + float(sep * max(0, ESTABLISHED_SCROLL_MAX_VISIBLE_ITEMS - 1))
	var viewport_h: float = maxf(ESTABLISHED_SCROLL_MIN_HEIGHT_PX, minf(content_h, max_viewport_for_cap))
	_established_scroll_viewport.custom_minimum_size = Vector2(_established_scroll_viewport.custom_minimum_size.x, viewport_h)
