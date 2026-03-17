extends VBoxContainer
class_name MorphologyScroll
## Keeps up to date with the morphology listing to show a scroll list of all morphologies

signal morphology_selected(morphology:BaseMorphology) # Mostly  proxy of item_selected, but also will emit NullMorphology when no morphology is selected

@export var load_morphologies_on_load: bool = true
@export var refresh_morphology_from_FEAGI_on_select = true

const BASE_FONT_SIZE: int = 14

var selected_morphology: BaseMorphology:
	get: return _selected_morphology

var _selected_morphology: BaseMorphology = NullMorphology.new()
var _filter_line: LineEdit
var _item_list: ItemList
var _items: Array[Dictionary] = []
var _filtered_item_indices: Array[int] = []
var _base_filter_font_size: int = 0
var _base_list_font_size: int = 0

func _ready() -> void:
	_filter_line = $MarginContainer/VBoxContainer/FilterLine
	_item_list = $MarginContainer/VBoxContainer/ItemList
	_filter_line.placeholder_text = "Filter rules"
	_filter_line.text_changed.connect(_on_filter_changed)
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_clicked.connect(_on_item_clicked)
	_item_list.item_activated.connect(_on_item_activated)
	_base_filter_font_size = _get_theme_font_size_safe(_filter_line)
	_base_list_font_size = _get_theme_font_size_safe(_item_list)
	_on_theme_change()
	BV.UI.theme_changed.connect(_on_theme_change)

	if load_morphologies_on_load:
		repopulate_from_cache()
	FeagiCore.feagi_local_cache.morphologies.morphology_about_to_be_removed.connect(_respond_to_deleted_morphology)
	FeagiCore.feagi_local_cache.morphologies.morphology_added.connect(_respond_to_added_morphology)
	FeagiCore.feagi_local_cache.morphologies.morphology_renamed.connect(_respond_to_renamed_morphology)

## Clears list, then loads morphology list from FeagiCache
func repopulate_from_cache() -> void:
	_items.clear()
	var morphologies_cache := FeagiCore.feagi_local_cache.morphologies.available_morphologies
	var morphology_names: Array = morphologies_cache.keys()
	morphology_names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a).to_lower() < String(b).to_lower()
	)
	for morphology_name in morphology_names:
		var morphology: BaseMorphology = morphologies_cache[morphology_name]
		if morphology == null:
			continue
		_items.append({"label": String(morphology.name), "payload": morphology})
	_apply_filter(_filter_line.text)

## Sets the morphologies from a manual list
func set_morphologies(morphologies: Array) -> void:
	_items.clear()
	for entry in morphologies:
		var morphology: BaseMorphology = entry as BaseMorphology
		if morphology == null and entry is StringName:
			if FeagiCore.feagi_local_cache.morphologies.available_morphologies.has(entry):
				morphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies[entry]
		if morphology == null:
			continue
		_items.append({"label": String(morphology.name), "payload": morphology})
	_apply_filter(_filter_line.text)

## Manually set the selected morphology through code.
func select_morphology(morphology: BaseMorphology) -> void:
	_selected_morphology = morphology
	_select_payload(morphology)
	if refresh_morphology_from_FEAGI_on_select:
		FeagiCore.requests.get_morphology(morphology.name)

func _respond_to_deleted_morphology(morphology: BaseMorphology) -> void:
	_remove_payload(morphology)
	if morphology.name == _selected_morphology.name:
		_selected_morphology = NullMorphology.new()
		morphology_selected.emit(_selected_morphology)

func _respond_to_added_morphology(morphology: BaseMorphology) -> void:
	_items.append({"label": morphology.name, "payload": morphology})
	_apply_filter(_filter_line.text)

func _respond_to_renamed_morphology(_old_name: StringName, morphology: BaseMorphology) -> void:
	for i in range(_items.size()):
		if _items[i].get("payload") == morphology:
			_items[i]["label"] = String(morphology.name)
			break
	_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")).to_lower() < String(b.get("label", "")).to_lower()
	)
	_apply_filter(_filter_line.text)

func _apply_filter(filter_text: String) -> void:
	_item_list.clear()
	_filtered_item_indices.clear()
	var query := filter_text.strip_edges().to_lower()
	for i in range(_items.size()):
		var label := String(_items[i].get("label", ""))
		if query == "" or label.to_lower().find(query) >= 0:
			_item_list.add_item(label)
			_filtered_item_indices.append(i)

func _on_filter_changed(new_text: String) -> void:
	_apply_filter(new_text)

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _filtered_item_indices.size():
		return
	var item_index := _filtered_item_indices[index]
	var morphology: BaseMorphology = _items[item_index].get("payload", NullMorphology.new())
	_selected_morphology = morphology
	morphology_selected.emit(morphology)
	if refresh_morphology_from_FEAGI_on_select:
		FeagiCore.requests.get_morphology(morphology.name)

func _on_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_on_item_selected(index)

func _on_item_activated(index: int) -> void:
	_on_item_selected(index)

func _select_payload(morphology: BaseMorphology) -> void:
	for i in range(_filtered_item_indices.size()):
		var item_index := _filtered_item_indices[i]
		if _items[item_index].get("payload") == morphology:
			_item_list.select(i)
			return

func _remove_payload(morphology: BaseMorphology) -> void:
	for i in range(_items.size() - 1, -1, -1):
		if _items[i].get("payload") == morphology:
			_items.remove_at(i)
	_apply_filter(_filter_line.text)

func _on_theme_change(_new_theme: Theme = null) -> void:
	_apply_scaled_fonts()

func _apply_scaled_fonts() -> void:
	var scale := 1.0
	if BV.UI and BV.UI.loaded_theme_scale:
		scale = BV.UI.loaded_theme_scale.x
	var filter_size := _scale_font_size(_base_filter_font_size, scale) + 2
	var list_size := _scale_font_size(_base_list_font_size, scale) + 2
	_filter_line.add_theme_font_size_override("font_size", filter_size)
	_item_list.add_theme_font_size_override("font_size", list_size)

func _get_theme_font_size_safe(control: Control) -> int:
	if control == null:
		return BASE_FONT_SIZE
	var size := control.get_theme_font_size("font_size")
	if size <= 0:
		return BASE_FONT_SIZE
	return size

func _scale_font_size(base_size: int, scale: float) -> int:
	return maxi(8, int(round(float(base_size) * scale)))
