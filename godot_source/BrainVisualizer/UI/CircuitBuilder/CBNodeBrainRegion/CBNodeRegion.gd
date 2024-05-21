extends GraphNode
class_name CBNodeRegion

var representing_region: BrainRegion:
	get: return _representing_region

var _representing_region: BrainRegion
var _inputs: VBoxContainer
var _outputs: VBoxContainer

func _ready():
	_inputs = $Inputs
	_outputs = $Outputs

## Called by CB right after instantiation
func setup(region_ref: BrainRegion) -> void:
	_representing_region = region_ref
	CACHE_updated_region_name(region_ref.name)
	CACHE_updated_2D_position(region_ref.coordinates_2d)
	
	_representing_region.name_updated.connect(CACHE_updated_region_name)
	_representing_region.coordinates_2D_updated.connect(CACHE_updated_2D_position)

# Responses to changes in cache directly. NOTE: Connection and creation / deletion we won't do here and instead allow CB to handle it, since they can involve interactions with connections
#region CACHE Events and responses

## Updates the title text of the node
func CACHE_updated_region_name(name_text: StringName) -> void:
	title = name_text

## Updates the position within CB of the node
func CACHE_updated_2D_position(new_position: Vector2i) -> void:
	position_offset = new_position

#endregion

#region CB and Line Interactions

## Called by [CircuitBuilder], add an external connection
func CB_add_external_connection_port(is_input: bool) -> void:
	pass

#endregion

#region User Interactions

signal double_clicked(self_ref: CBNodeRegion) ## Node was double clicked

func _gui_input(event):
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if !mouse_event.double_click:
			return
		double_clicked.emit(self)



#endregion
