extends DraggableWindow
class_name WindowAmalgamationRequest

var _field_title: TextInput
var _field_3d_location: Vector3iSpinboxField

var _amalgamation_ID: StringName


func _ready() -> void:
	super._ready()
	_field_title = $Container/HBoxContainer/AmalgamationTitle
	_field_3d_location = $Container/HBoxContainer2/Coordinates_3D
	

func setup(amalgamation_ID: StringName, genome_title: StringName) -> void:
	_amalgamation_ID = amalgamation_ID
	_field_title.text = genome_title
	
func _cancel_pressed():
	close_window("import_amalgamation")

func _import_pressed():
	FeagiRequests.request_import_amalgamation(_field_3d_location.current_vector, _amalgamation_ID)
	close_window("import_amalgamation", false)

#OVERRIDE
func close_window(window_name: StringName, request_cancel: bool = true) -> void:
	super(window_name)
	if request_cancel:
		FeagiRequests.request_cancel_amalgamation(_amalgamation_ID)
