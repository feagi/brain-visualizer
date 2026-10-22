extends RefCounted
class_name CorticalLayoutSide
## Which layout column a cortical area belongs in, and its order within the input/output column.
## Shared by Circuit Builder and the Circuit Schematic so both place areas the same way.

const SIDE_LEFT: String = "left"
const SIDE_RIGHT: String = "right"
const SIDE_MIDDLE: String = "middle"


## [constant SIDE_LEFT] for inputs, [constant SIDE_RIGHT] for outputs, [constant SIDE_MIDDLE] otherwise.
static func classify(area: AbstractCorticalArea) -> String:
	var area_id_lower := String(area.cortical_ID).to_lower()
	var area_name_lower := String(area.friendly_name).to_lower()
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
		return SIDE_LEFT
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
		return SIDE_RIGHT
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE:
		var core_label := core_io_label(area)
		if core_label == "power":
			return SIDE_LEFT
		if core_label in ["fatigue", "pain", "pleasure", "fear", "hope", "death"]:
			return SIDE_RIGHT
		if area_id_lower.begins_with("i") or area_name_lower.contains("input") or area_name_lower.contains("ipu"):
			return SIDE_LEFT
		if area_id_lower.begins_with("o") or area_name_lower.contains("output") or area_name_lower.contains("opu"):
			return SIDE_RIGHT
		return SIDE_RIGHT
	if area_id_lower.begins_with("i"):
		return SIDE_LEFT
	if area_id_lower.begins_with("o"):
		return SIDE_RIGHT
	return SIDE_MIDDLE


## Lower sorts first. Core areas lead their column: power on the input side, then fatigue, pain,
## pleasure, fear, hope and death on the output side.
static func io_priority(area: AbstractCorticalArea, is_input_column: bool) -> int:
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE:
		var label := core_io_label(area)
		if is_input_column and label == "power":
			return -100
		if (not is_input_column) and label == "fatigue":
			return -100
		if (not is_input_column) and label == "pain":
			return -95
		if (not is_input_column) and label == "pleasure":
			return -94
		if (not is_input_column) and label == "fear":
			return -93
		if (not is_input_column) and label == "hope":
			return -92
		if (not is_input_column) and label == "death":
			return -90
	return 0


static func core_io_label(area: AbstractCorticalArea) -> String:
	var area_id_lower := String(area.cortical_ID).to_lower()
	var area_name_lower := String(area.friendly_name).to_lower()
	var special_core_name := AbstractCorticalArea.get_special_core_area_name(area.cortical_ID)
	if not special_core_name.is_empty():
		return special_core_name
	if area_id_lower.contains("pwr") or area_name_lower.contains("power"):
		return "power"
	if area_name_lower.contains("fatigue"):
		return "fatigue"
	if area_name_lower.contains("pain"):
		return "pain"
	if area_name_lower.contains("pleasure"):
		return "pleasure"
	if area_name_lower.contains("fear"):
		return "fear"
	if area_name_lower.contains("hope"):
		return "hope"
	if area_name_lower.contains("death"):
		return "death"
	return "other"


## The [LayeredGraphLayout] column for an area.
static func layout_column(area: AbstractCorticalArea) -> LayeredGraphLayout.COLUMN:
	match classify(area):
		SIDE_LEFT:
			return LayeredGraphLayout.COLUMN.INPUT
		SIDE_RIGHT:
			return LayeredGraphLayout.COLUMN.OUTPUT
	return LayeredGraphLayout.COLUMN.MIDDLE
