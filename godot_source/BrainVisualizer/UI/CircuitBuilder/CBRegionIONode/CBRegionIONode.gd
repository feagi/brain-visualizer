extends CBAbstractNode
class_name CBRegionIO

const KNOWN_ICON_PATHS : Dictionary = {
	"iv00_C" : "res://BrainVisualizer/UI/CircuitBuilder/Resources/IOIcons/knowns/iv00_C.png",
	"i_spos" : "res://BrainVisualizer/UI/CircuitBuilder/Resources/IOIcons/knowns/i_spos.png",
	"o__mot" : "res://BrainVisualizer/UI/CircuitBuilder/Resources/IOIcons/knowns/o__mot.png",
	"___pwr" : "res://BrainVisualizer/UI/CircuitBuilder/Resources/IOIcons/knowns/___pwr.png",
}
const ICON_CUSTOM_INPUT: StringName = "res://BrainVisualizer/UI/CircuitBuilder/Resources/IOIcons/unknowns/custom-input.png"
const ICON_CUSTOM_OUTPUT: StringName = "res://BrainVisualizer/UI/CircuitBuilder/Resources/IOIcons/unknowns/custom-input.png"
const ICON_UNKNOWN_INPUT: StringName = "res://BrainVisualizer/UI/CircuitBuilder/Resources/IOIcons/unknowns/custom-input.png"
const ICON_UNKNOWN_OUTPUT: StringName = "res://BrainVisualizer/UI/CircuitBuilder/Resources/IOIcons/unknowns/custom-input.png"

var _is_region_input: bool
var _outside: GenomeObject
var _inside: GenomeObject
var _path_between_objects: Array[GenomeObject]

var _icon: TextureRect
var _path: Button
var _arrow: Button
var _endpoint: CBLineEndpoint




func setup(outside_object: GenomeObject, inside_object: GenomeObject, is_region_input: bool) -> void:
	setup_base()
	_arrow = $HBoxContainer/Arrow
	_path = $HBoxContainer/Path
	_arrow = $HBoxContainer/Arrow
	_endpoint = $HBoxContainer/CbLineEndPoint
	
	_outside = outside_object
	_inside = inside_object
	
	_set_direction(is_region_input)
	_outside_name_updated(outside_object.friendly_name)
	_path_updated()
	_set_icon(outside_object)
	
	outside_object.friendly_name_updated.connect(_outside_name_updated)
	outside_object.parent_region_updated.connect(_path_updated)
	inside_object.parent_region_updated.connect(_path_updated)
	
	

## Creates and adds an input CBLineEndpoint # NOTE: Does not call the base implementation since we dont need to spawn a CBLineEndpoint
func add_input_endpoint(_endpoint_prefab: PackedScene, port_style: CBLineEndpoint.PORT_STYLE) -> CBLineEndpoint:
	_endpoint.setup(self, node_moved, port_style)
	_set_direction(true)
	return _endpoint

## Creates and adds an output CBLineEndpoint # NOTE: Does not call the base implementation since we dont need to spawn a CBLineEndpoint
func add_output_endpoint(_endpoint_prefab: PackedScene, port_style: CBLineEndpoint.PORT_STYLE) -> CBLineEndpoint:
	_endpoint.setup(self, node_moved, port_style)
	_set_direction(false)
	return _endpoint

func _outside_name_updated(new_name: StringName) -> void:
	_arrow.text = new_name

func _set_direction(is_input: bool) -> void:
	_is_region_input = is_input
	if is_input:
		move_child(_icon, 0)
		move_child(_path, 1)
		move_child(_arrow, 2)
		move_child(_endpoint, 3)
	else:
		move_child(_endpoint, 0)
		move_child(_arrow, 1)
		move_child(_path, 2)
		move_child(_icon, 3)

func _path_updated(_irrelevant1 = null, _irrelevant2 = null) -> void:
	if _is_region_input:
		_path_between_objects = FeagiCore.feagi_local_cache.brain_regions.get_total_path_between_objects(_outside, _inside)
	else:
		_path_between_objects = FeagiCore.feagi_local_cache.brain_regions.get_total_path_between_objects(_inside, _outside)
	_toggle_path_button(_path.button_pressed)

func _toggle_path_button(toggled_open: bool) -> void:
	var text: String
	if toggled_open:
		text = ""
		for object in _path_between_objects:
			text += "/" + object.friendly_name
	else:
		text = str(len(_path_between_objects))
	_path.text = text
	size = Vector2(0,0)
	# TODO line shenanigans

func _set_icon(external_object: GenomeObject) -> void:
	if external_object.genome_ID in KNOWN_ICON_PATHS:
		_icon.texture = load(KNOWN_ICON_PATHS[external_object.genome_ID])
		return
	if external_object is AbstractCorticalArea:
		if (external_object as AbstractCorticalArea).cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			if _is_region_input:
				_icon.texture = load(ICON_CUSTOM_INPUT)
			else:
				_icon.texture = load(ICON_CUSTOM_OUTPUT)
			return
	if _is_region_input:
		_icon.texture = load(ICON_UNKNOWN_INPUT)
	else:
		_icon.texture = load(ICON_UNKNOWN_OUTPUT)


