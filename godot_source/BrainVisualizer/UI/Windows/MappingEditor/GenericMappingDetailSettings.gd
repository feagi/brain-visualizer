extends VBoxContainer
class_name GenericMappingDetailSettings

const PREFAB_ROW: PackedScene = preload("res://BrainVisualizer/UI/Windows/MappingEditor/MappingEditorRowGeneric.tscn")

## Matches [ScrollSectionGeneric] min height in [member GenericMappingDetailSettings._scroll] scene (default list footprint).
const ESTABLISHED_SCROLL_MIN_HEIGHT_PX: float = 200.0
## Beyond this many rows, the list keeps a fixed viewport height and scrolls.
const ESTABLISHED_SCROLL_MAX_VISIBLE_ITEMS: int = 10
## Approximate rows that fit in [constant ESTABLISHED_SCROLL_MIN_HEIGHT_PX] before dynamic refit; used only if layout has not produced a row height yet.
const ESTABLISHED_SCROLL_APPROX_ROWS_AT_MIN_HEIGHT: float = 3.0
const META_HEADER_CLIP_WRAP: StringName = &"bv_header_clip_wrap"

signal user_changed_something()

var _restrictions: MappingRestrictionCorticalMorphology
var _defaults: MappingRestrictionDefault

var _add_button: TextureButton
var _established_scroll_viewport: Control
var _header_row_wrapper: HBoxContainer
var _header_align_lead: Control
var _scroll: ScrollSectionGeneric
var _empty_state: VBoxContainer

func _ready() -> void:
	_established_scroll_viewport = $EstablishedScrollViewport
	_header_row_wrapper = $HeaderRowWrapper
	_header_align_lead = $HeaderRowWrapper/HeaderAlignLead
	_scroll = $EstablishedScrollViewport/ScrollSectionGeneric
	_add_button = $HeaderRowWrapper/labels_box/add_button
	_empty_state = $EmptyState
	_established_scroll_viewport.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.item_about_to_be_deleted.connect(_on_scroll_item_about_to_be_deleted)
	if BV and BV.UI and not BV.UI.theme_changed.is_connected(_on_theme_changed):
		BV.UI.theme_changed.connect(_on_theme_changed)
	if not _scroll.resized.is_connected(_on_scroll_or_viewport_resized):
		_scroll.resized.connect(_on_scroll_or_viewport_resized)
	if not _established_scroll_viewport.resized.is_connected(_on_scroll_or_viewport_resized):
		_established_scroll_viewport.resized.connect(_on_scroll_or_viewport_resized)

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

func _show_table_state() -> void:
	_empty_state.visible = false
	_header_row_wrapper.visible = true
	_established_scroll_viewport.visible = true

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
	_show_table_state()
	var row: MappingEditorRowGeneric = PREFAB_ROW.instantiate()
	var item: ScrollSectionGenericItem = _scroll.add_generic_item(row, null, "")
	item.about_to_be_deleted.connect(_on_row_deletion)
	row.load_settings(_restrictions, _defaults)
	if _restrictions != null and _restrictions.has_max_number_mappings():
		_add_button.disabled = _restrictions.max_number_mappings >= _scroll.get_item_count()
	_queue_refit_established_scroll_viewport()

func _on_scroll_item_about_to_be_deleted(_item: ScrollSectionGenericItem) -> void:
	_queue_refit_established_scroll_viewport()
	if _scroll.get_item_count() <= 1:
		call_deferred("_show_empty_state")

func _on_row_deletion(item: ScrollSectionGenericItem) -> void:
	if _restrictions != null and _restrictions.has_max_number_mappings():
		_add_button.disabled = _restrictions.max_number_mappings < _scroll.get_item_count() - 1
	if _scroll.get_item_count() <= 1:
		call_deferred("_show_empty_state")

func _queue_refit_established_scroll_viewport() -> void:
	if not is_node_ready():
		return
	call_deferred("_refit_established_scroll_viewport_async")

func _on_theme_changed(_new_theme: Theme) -> void:
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
		_established_scroll_viewport.custom_minimum_size = Vector2(_established_scroll_viewport.custom_minimum_size.x, ESTABLISHED_SCROLL_MIN_HEIGHT_PX)
		_apply_header_scroll_content_width()
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
	await get_tree().process_frame
	await get_tree().process_frame
	await _sync_header_to_scroll_row()

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
	await _sync_header_columns_to_first_row()

## Clears any prior run's separation override so header and data rows keep theme spacing independently.
func _clear_hbox_separation_overrides(hbox: HBoxContainer) -> void:
	hbox.remove_theme_constant_override("separation")

## [Label] minimum width follows full text size; [clip_text] does not shrink layout minimum. Wrap in a fixed-width [Control] with [member Control.clip_contents] so header column widths match data row cells.
func _ensure_label_clipped_to_width(lab: Label, width_px: float) -> void:
	var p: Node = lab.get_parent()
	if p is Control and (p as Control).has_meta(META_HEADER_CLIP_WRAP):
		var clip: Control = p as Control
		clip.custom_minimum_size.x = width_px
		var h: float = maxf(clip.custom_minimum_size.y, lab.get_combined_minimum_size().y)
		clip.custom_minimum_size.y = h
		lab.clip_text = true
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		return
	var parent_box: Container = lab.get_parent() as Container
	if parent_box == null:
		return
	var idx: int = lab.get_index()
	var clip := Control.new()
	clip.set_meta(META_HEADER_CLIP_WRAP, true)
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(width_px, lab.get_combined_minimum_size().y)
	clip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent_box.add_child(clip)
	parent_box.move_child(clip, idx)
	lab.reparent(clip)
	lab.clip_text = true
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.offset_left = 0.0
	lab.offset_top = 0.0
	lab.offset_right = 0.0
	lab.offset_bottom = 0.0

## Shifts header labels horizontally so column 0's left edge matches the data row. Uses [member _header_align_lead] width so [VBoxContainer] layout does not overwrite a manual position each frame.
func _align_header_strip_to_row_column_zero(row: HBoxContainer, header_root: HBoxContainer) -> void:
	var r0: Control = row.get_child(0) as Control
	var h0: Control = header_root.get_child(0) as Control
	if r0 == null or h0 == null:
		return
	var dx: float = r0.global_position.x - h0.global_position.x
	if abs(dx) <= 0.5:
		return
	if is_instance_valid(_header_align_lead):
		var next_lead: float = maxf(0.0, _header_align_lead.custom_minimum_size.x + dx)
		_header_align_lead.custom_minimum_size.x = next_lead
	else:
		_header_row_wrapper.global_position.x += dx

## Left-edge mismatch at index i is fixed by changing the width of column i - 1 (not i).
func _sync_header_columns_to_first_row() -> void:
	var list_items: Array[ScrollSectionGenericItem] = _scroll.get_all_spawned_children_of_container()
	if list_items.is_empty():
		return
	var row: HBoxContainer = list_items[0].get_control() as HBoxContainer
	if row == null:
		return
	var header_root := $HeaderRowWrapper/labels_box as HBoxContainer
	if is_instance_valid(_header_align_lead):
		_header_align_lead.custom_minimum_size.x = 0.0
	_clear_hbox_separation_overrides(row)
	_clear_hbox_separation_overrides(header_root)
	var row_count: int = row.get_child_count()
	var header_count: int = header_root.get_child_count()
	if row_count != header_count:
		push_warning(
			"GenericMappingDetailSettings: header column count (%d) != data row column count (%d); alignment may drift."
			% [header_count, row_count]
		)
	var pair_count: int = mini(row_count, header_count)
	for idx in range(pair_count):
		var row_node: Control = row.get_child(idx) as Control
		var header_node: Control = header_root.get_child(idx) as Control
		if row_node == null or header_node == null:
			continue
		var w_row: float = row_node.size.x
		if w_row <= 0.001:
			w_row = row_node.get_combined_minimum_size().x
		if w_row <= 0.001:
			continue
		if header_node is HBoxContainer and row_node is HBoxContainer:
			var hg: HBoxContainer = header_node as HBoxContainer
			var rg: HBoxContainer = row_node as HBoxContainer
			var inner_n: int = mini(hg.get_child_count(), rg.get_child_count())
			for j in range(inner_n):
				var rc: Control = rg.get_child(j) as Control
				var hc: Control = hg.get_child(j) as Control
				if rc == null or hc == null:
					continue
				var w_inner: float = rc.size.x
				if w_inner <= 0.001:
					w_inner = rc.get_combined_minimum_size().x
				if w_inner <= 0.001:
					continue
				if hc is Label:
					_ensure_label_clipped_to_width(hc as Label, w_inner)
				else:
					hc.custom_minimum_size = Vector2(w_inner, hc.custom_minimum_size.y)
			header_node.custom_minimum_size = Vector2(w_row, header_node.custom_minimum_size.y)
		elif header_node is Label:
			_ensure_label_clipped_to_width(header_node as Label, w_row)
		else:
			header_node.custom_minimum_size = Vector2(w_row, header_node.custom_minimum_size.y)
	await get_tree().process_frame
	await get_tree().process_frame
	_align_header_strip_to_row_column_zero(row, header_root)
	await get_tree().process_frame
	const ALIGN_PASSES: int = 8
	const ALIGN_EPS: float = 0.5
	for _pass in range(ALIGN_PASSES):
		var moved: bool = false
		for idx in range(1, pair_count):
			var row_node: Control = row.get_child(idx) as Control
			var header_node: Control = header_root.get_child(idx) as Control
			var prev_header: Control = header_root.get_child(idx - 1) as Control
			if row_node == null or header_node == null or prev_header == null:
				continue
			var err: float = row_node.global_position.x - header_node.global_position.x
			if abs(err) <= ALIGN_EPS:
				continue
			prev_header.custom_minimum_size.x = maxf(0.0, prev_header.custom_minimum_size.x + err)
			moved = true
		_align_header_strip_to_row_column_zero(row, header_root)
		if not moved:
			break
		await get_tree().process_frame
