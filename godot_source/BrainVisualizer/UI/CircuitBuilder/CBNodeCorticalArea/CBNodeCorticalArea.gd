extends GraphNode
class_name CBNodeCorticalArea


var representing_cortical_area: BaseCorticalArea:
	get: return _representing_cortical_area

var _representing_cortical_area: BaseCorticalArea
var _recursives: VBoxContainer
var _inputs: VBoxContainer
var _outputs: VBoxContainer

func _ready():
	_recursives = $Recursive
	_inputs = $Inputs
	_outputs = $Outputs

## Called by CB right after instantiation
func setup(cortical_area_ref: BaseCorticalArea) -> void:
	_representing_cortical_area = cortical_area_ref
	CACHE_updated_cortical_area_name(_representing_cortical_area.name)
	CACHE_updated_2D_position(_representing_cortical_area.coordinates_2D)
	
	_representing_cortical_area.name_updated.connect(CACHE_updated_cortical_area_name)
	_representing_cortical_area.coordinates_2D_updated.connect(CACHE_updated_2D_position)

# Responses to changes in cache directly. NOTE: Connection and creation / deletion we won't do here and instead allow CB to handle it, since they can involve interactions with connections
#region CACHE Events and responses

## Updates the title text of the node
func CACHE_updated_cortical_area_name(name_text: StringName) -> void:
	title = name_text

## Updates the position within CB of the node
func CACHE_updated_2D_position(new_position: Vector2i) -> void:
	position_offset = new_position

#endregion

#region CB and Line Interactions

## Called by [CircuitBuilder], add a recursive connection
func CB_add_recursive_connection_port() -> void:
	pass

## Called by [CircuitBuilder], add an external connection
func CB_add_external_connection_port(is_input: bool) -> void:
	pass

#endregion
