extends CBNodeConnectableBase
class_name CBNodeCorticalArea

var representing_cortical_area: BaseCorticalArea:
	get: return _representing_cortical_area

var _representing_cortical_area: BaseCorticalArea


#TODO TEMP
# Announce if cortical area was selected with one click and open cortical properties panel on double click
func _gui_input(event):
	if !(event is InputEventMouseButton): return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.is_pressed(): return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT: return
	BV.UI.user_selected_single_cortical_area_independently(_representing_cortical_area)

## Called by CB right after instantiation
func setup(cortical_area_ref: BaseCorticalArea) -> void:
	var input_path: NodePath = NodePath("Inputs")
	var output_path: NodePath = NodePath("Outputs")
	var recursive_path: NodePath = NodePath("Recursive")
	setup_base(recursive_path, input_path, output_path)
	
	_representing_cortical_area = cortical_area_ref
	_setup_node_color(cortical_area_ref.group)
	CACHE_updated_cortical_area_name(_representing_cortical_area.name)
	CACHE_updated_2D_position(_representing_cortical_area.coordinates_2D)
	name = cortical_area_ref.cortical_ID
	
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

#region Internal logic

const IPU_BOX_COLOR: Color = Color(0.25882352941176473, 0.25882352941176473, 0.25882352941176473)
const CUSTOM_BOX_COLOR: Color = Color(0, 0.32941176470588235, 0.5764705882352941)
const MEMORY_BOX_COLOR: Color = Color(0.5803921568627451, 0.06666666666666667, 0)
const OPU_BOX_COLOR: Color = Color(0.5803921568627451, 0.3215686274509804, 0)

## Set the color depnding on cortical type
func _setup_node_color(cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	match(cortical_type):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			style_box.bg_color = IPU_BOX_COLOR
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			style_box.bg_color = MEMORY_BOX_COLOR
		BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			style_box.bg_color = CUSTOM_BOX_COLOR
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			style_box.bg_color = OPU_BOX_COLOR
		BaseCorticalArea.CORTICAL_AREA_TYPE.CORE:
			pass #TODO Define an actual color here at some point!
		_:
			push_error("Cortical Node loaded unknown or invalid cortical area type!")
			pass
	add_theme_stylebox_override("titlebar", style_box)

#endregion
