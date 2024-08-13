extends VBoxContainer
class_name PartSpawnCorticalAreaIOPU

signal calculated_dimensions_updated(new_size: Vector3i)
signal location_changed_from_dropdown(new_location: Vector3i)


var dropdown: TemplateDropDown
var location: Vector3iSpinboxField
var device_count: SpinBox
var _iopu_image: TextureRect
var _current_dimensions_as_per_device_count: Vector3i = Vector3i(0,0,0)
var _is_IPU_not_OPU: bool

func _ready() -> void:
	dropdown = $HBoxContainer2/TopSection/TemplateDropDown
	location = $HBoxContainer/Fields/Location
	device_count = $HBoxContainer/Fields/ChannelCount
	_iopu_image = $HBoxContainer/TextureRect
	

func cortical_type_selected(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal]) -> void:
	dropdown.load_cortical_type_options(cortical_type)
	_is_IPU_not_OPU = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU
	if dropdown.get_selected_template().ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		location.current_vector = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[dropdown.get_selected_template().ID].coordinates_3D
		location_changed_from_dropdown.emit(location.current_vector)
	var move_signals: Array[Signal] = [location.user_updated_vector, location_changed_from_dropdown]
	var resize_signals: Array[Signal] = [calculated_dimensions_updated]
	BV.UI.start_cortical_area_preview(location.current_vector, _current_dimensions_as_per_device_count, move_signals, resize_signals, preview_close_signals)
	if _is_IPU_not_OPU:
		_iopu_image.texture = load(UIManager.KNOWN_ICON_PATHS["i__inf"])
	else:
		_iopu_image.texture = load(UIManager.KNOWN_ICON_PATHS["o__mot"])


func _drop_down_changed(cortical_template: CorticalTemplate) -> void:
	_current_dimensions_as_per_device_count = cortical_template.calculate_IOPU_dimension(int(device_count.value))
	calculated_dimensions_updated.emit(_current_dimensions_as_per_device_count)
	if cortical_template != null:
		_iopu_image.texture = UIManager.get_icon_texture_by_ID(cortical_template.ID, _is_IPU_not_OPU)
	if dropdown.get_selected_template().ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		location.current_vector = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[dropdown.get_selected_template().ID].coordinates_3D
		location_changed_from_dropdown.emit(location.current_vector)
	

func _proxy_device_count_changes(_new_device_count: int) -> void:
	_current_dimensions_as_per_device_count = dropdown.get_selected_template().calculate_IOPU_dimension(int(device_count.value))
	calculated_dimensions_updated.emit(_current_dimensions_as_per_device_count)
