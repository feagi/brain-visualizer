extends MappingEditorRowGeneric
class_name MappingEditorRowGenericPartial

signal add_pressed(mapping: SingleMappingDefinition)

func _pressed_add() -> void:
	add_pressed.emit(export_mapping())
	queue_free()
