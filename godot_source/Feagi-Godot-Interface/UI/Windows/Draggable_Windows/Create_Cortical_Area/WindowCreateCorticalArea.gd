extends GrowingPanel
class_name WindowCreateCorticalArea

signal dimensions_updated(dimensions: Vector3i)
signal location_updated(location: Vector3i)

var _field_cortical_name: TextInput
var _field_3D_coordinates: Vector3iField
var _field_type_radio: RadioButtons
var _field_dimensions: Vector3iField
var _field_channel: IntInput
var _dropdown_cortical_dropdown: CorticalDropDown
var _holder_dropdown: HBoxContainer
var _holder_channel: HBoxCOntainer

func _ready() -> void:
    _field_cortical_name = $BoxContainer/HBoxContainer/Cortical_Name
    _field_3D_coordinates = $BoxContainer/HBoxContainer2/Coordinates_3D
    _field_type_radio = $BoxContainer/HBoxContainer3/options
    _field_dimensions = $BoxContainer/dimensions_holder/Dimensions
    _field_channel = $BoxContainer/channel_holder/Channel_Input
    _dropdown_cortical_dropdown = $BoxContainer/cortical_dropdown_holder/CorticalDropDown
    _holder_dropdown = $BoxContainer/cortical_dropdown_holder
    _holder_channel = $BoxContainer/channel_holder





func _switch_UI_between_cortical_types(cortical_type: CorticalArea.CORTICAL_AREA_TYPE) -> void:
    match cortical_type:
        CorticalArea.CORTICAL_AREA_TYPE.IPU:
            _holder_dropdown.visible = true
            _holder_channel.visible = true
            _field_dimensions.editable = false
        CorticalArea.CORTICAL_AREA_TYPE.OPU:
            _holder_dropdown.visible = true
            _holder_channel.visible = true
            _field_dimensions.editable = false
        CorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
            _holder_dropdown.visible = false
            _holder_channel.visible = false
            _field_dimensions.editable = true


func _calculate_IOPU_dimension(input_dimension: Vector3i, channel_count: int) -> Vector3i:
    input_dimension.x = input_dimension.x * channel_count
    return input_dimension