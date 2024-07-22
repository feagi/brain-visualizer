extends HBoxContainer
class_name PartSpawnCorticalAreaSelection

signal cortical_type_selected(type: AbstractCorticalArea.CORTICAL_AREA_TYPE)

func _on_input_pressed() -> void:
	cortical_type_selected.emit(AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU)

func _on_output_pressed() -> void:
	cortical_type_selected.emit(AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU)

func _on_interconnect_pressed() -> void:
	cortical_type_selected.emit(AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM)

func _on_memory_pressed() -> void:
	cortical_type_selected.emit(AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY)
