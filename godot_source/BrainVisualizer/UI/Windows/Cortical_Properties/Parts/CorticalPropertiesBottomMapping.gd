extends HBoxContainer
class_name CorticalPropertiesBottomMappingPrefab

var _ID_Button: Button
var _Delete_Button: TextureButton
var _source_area: BaseCorticalArea
var _destination_area: BaseCorticalArea
var _left_window_ref: Node

func _ready():
	_ID_Button = $Cortical_ID
	_Delete_Button = $Delete_Button
	

func setup(data: Dictionary, _main_window: Node) -> void:
	# we expect the source and destination area here
	_left_window_ref = _main_window
	_source_area = data["source"]
	_destination_area = data["destination"]
	_source_area.efferent_mappings[_destination_area.cortical_ID].mappings_changed.connect(_mapping_changed)
	
	if data["aff2this"]:
		# afferent
		_ID_Button.text = _source_area.name
		_source_area.name_updated.connect(_cortical_name_changed)
		name = _source_area.cortical_ID
	else:
		# efferent
		_ID_Button.text = _destination_area.name
		_destination_area.name_updated.connect(_cortical_name_changed)
		name = _destination_area.cortical_ID
	

func _user_pressed_delete_button():
	print("Cortical Properties is requesting Cortical Connection Deletion")
	FeagiCore.requests.delete_mappings_between_corticals(_source_area, _destination_area)
	
func _user_pressed_edit_button():
	print("Cortical Properties is requesting Cortical Connection Editing")
	BV.WM.spawn_edit_mappings(_source_area, _destination_area)

func _cortical_name_changed(new_name: StringName, _cortical_area: BaseCorticalArea) -> void:
	_ID_Button.text = new_name

func _mapping_changed(mapping: MappingProperties) -> void:
	if mapping.is_empty():
		queue_free()
