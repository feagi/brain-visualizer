extends VisualizationFrameDecoder
class_name Type11NativeFrameDecoder
## Type 11 / FeagiByteContainer frames decoded by the FeagiDataDeserializer GDExtension (desktop).

var _deserializer = null


func get_format_name() -> String:
	return "Type 11 (native)"


func is_available() -> bool:
	# Instantiated lazily: the GDExtension may finish registering after the sink is created.
	if _deserializer == null and ClassDB.class_exists("FeagiDataDeserializer"):
		_deserializer = ClassDB.instantiate("FeagiDataDeserializer")
		if _deserializer == null:
			push_error("🦀 CRITICAL: Failed to instantiate FEAGI Rust deserializer!")
	return _deserializer != null


func supports_multimesh_apply() -> bool:
	return true


func apply_to_multimeshes(frame: PackedByteArray, multimeshes_by_id: Dictionary, dimensions_by_id: Dictionary, clear_all_before_apply: bool) -> Dictionary:
	return _deserializer.apply_type11_packet_to_multimeshes(frame, multimeshes_by_id, dimensions_by_id, clear_all_before_apply)


func decode_areas(frame: PackedByteArray, cortical_ids: PackedStringArray = PackedStringArray()) -> Dictionary:
	if cortical_ids.is_empty():
		return _deserializer.decode_type_11_data(frame)
	return _deserializer.decode_type_11_data_filtered(frame, cortical_ids)
