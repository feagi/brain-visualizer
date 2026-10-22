extends VisualizationFrameDecoder
class_name Type11WasmFrameDecoder
## Type 11 / FeagiByteContainer frames decoded by the WASM module (web builds, no GDExtensions).

const WASMDecoder = preload("res://Utils/WASMDecoder.gd")


func _init() -> void:
	# Kick off the WASM loader early so it's ready by the time data arrives
	WASMDecoder.ensure_wasm_loaded()


func get_format_name() -> String:
	return "Type 11 (WASM)"


func is_available() -> bool:
	return WASMDecoder.is_wasm_ready()


func queue_until_available() -> bool:
	return true


func decode_areas(frame: PackedByteArray, _cortical_ids: PackedStringArray = PackedStringArray()) -> Dictionary:
	var decoded: Dictionary = WASMDecoder.decode_type_11(frame)
	if not decoded:
		return {"success": false, "error": "no result"}
	return decoded
