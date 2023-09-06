extends Node
class_name LeftBarBottomMappingPrefab

var _ID_Button: TextButton_Element
var _Delete_Button: TextureButton_Element
var _source_area: CorticalArea
var _destination_area: CorticalArea
var _left_window_ref: Node

func _ready():
	_ID_Button = $Cortical_ID
	_Delete_Button = $Delete_Button
	

func setup(data: Dictionary, _main_window: Node) -> void:
	# we expect the source and destination area here
	_left_window_ref = _main_window
	_source_area = data["source"]
	_destination_area = data["destination"]
	if data["aff2this"]:
		# afferent
		_ID_Button.text = _source_area.cortical_ID
		name = _source_area.cortical_ID
	else:
		# efferent
		_ID_Button.text = _destination_area.cortical_ID
		name = _destination_area.cortical_ID

func _user_pressed_delete_button():
	print("Left Bar is requesting Cortical Connection Deletion")
	FeagiRequests.request_delete_connection_between_corticals(_source_area, _destination_area)
	queue_free() # TODO THIS IS BAD! WE SHOULD WAIT ON FEAGI
	
	

func _user_pressed_edit_button():
	print("Left Bar is requesting Cortical Connection Editing")
	VisConfig.window_manager.spawn_edit_mappings(_source_area, _destination_area)

