extends BaseDraggableWindow
class_name AdvancedCorticalProperties
## Shows properties of various cortical areas and allows multi-editing


const WINDOW_NAME: StringName = "cortical_properties"

var _cortical_area_refs: Array[AbstractCorticalArea]


static func set_UI_element_value(areas: Array[AbstractCorticalArea], section_name: StringName, value_name: StringName, UI_element: Control) -> void:
	var differences: int = -1 # first one will always fail
	var current_value: Variant = null
	var prev_value: Variant = null
	var section_object: RefCounted
	for area in areas:
		if section_name != "":
			section_object = area.get(section_name) # Assumption is that all cortical areas have the section
		else:
			section_object = area # to allow us to grab universal properties
		current_value = section_object.get(value_name)
		if current_value != prev_value:
			prev_value = current_value
			differences += 1
			if differences > 0:
				# Differences, assign invalid
				if UI_element is AbstractLineInput:
					(UI_element as AbstractLineInput).set_text_as_invalid()
					return
				# TODO button
				return
	
	# if we get to this point, values are consistent
	if UI_element is FloatInput:
		(UI_element as FloatInput).current_float = current_value
	# TODO other types
	
static func connect_FEAGI_signals(areas: Array[AbstractCorticalArea], section_name: StringName, signal_name: StringName, UI_element: Control) -> void:
	var section_object: RefCounted
	var signal_ref: Signal
	for area in areas:
		if section_name != "":
			section_object = area.get(section_name) # Assumption is that all cortical areas have the section
		else:
			section_object = area # to allow us to grab universal properties
		signal_ref = section_object.get(signal_name)
		if UI_element is FloatInput:
			signal_ref.connect((UI_element as FloatInput).set_float)
			continue


func _ready():
	super()


## Load in initial values of the cortical area from Cache
func setup(cortical_area_references: Array[AbstractCorticalArea]) -> void:
	_setup_base_window(WINDOW_NAME)
	_cortical_area_refs = cortical_area_references
	var top_bar
	
	
