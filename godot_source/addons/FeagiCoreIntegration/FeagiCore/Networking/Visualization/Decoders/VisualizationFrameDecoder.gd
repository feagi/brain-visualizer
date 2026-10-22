extends RefCounted
class_name VisualizationFrameDecoder
## Decodes one visualization frame for [FEAGIVisualizationSink]. One implementation per stream format
## (Type 11 byte containers today; the feagi-interop/zenoh format later). The sink only talks to this
## interface, so the MultiMesh fast path, bulk-decode registry, recorder and live inspector work with
## any format.


## Human-readable format name for logs.
func get_format_name() -> String:
	return "none"


## Whether frames can be decoded right now.
func is_available() -> bool:
	return false


## Whether frames arriving before [method is_available] should be queued (e.g. a decoder still loading)
## rather than dropped.
func queue_until_available() -> bool:
	return false


## Whether [method apply_to_multimeshes] is implemented. Without it, every area goes through
## [method decode_areas].
func supports_multimesh_apply() -> bool:
	return false


## Write [param frame] straight into Brain Monitor MultiMeshes keyed by cortical ID. Returns
## {success, areas_applied, neurons_applied, area_counts, error}.
func apply_to_multimeshes(_frame: PackedByteArray, _multimeshes_by_id: Dictionary, _dimensions_by_id: Dictionary, _clear_all_before_apply: bool) -> Dictionary:
	return {"success": false, "areas_applied": 0, "neurons_applied": 0, "error": "multimesh apply not supported by %s" % get_format_name()}


## Decode [param frame] into {success, error, areas: {cortical_id: {x_array, y_array, z_array, p_array}}},
## with cortical IDs as base64 strings. A non-empty [param cortical_ids] limits the result to those areas
## (case-insensitive); decoders may ignore it and return every area.
func decode_areas(_frame: PackedByteArray, _cortical_ids: PackedStringArray = PackedStringArray()) -> Dictionary:
	return {"success": false, "error": "%s cannot decode frames" % get_format_name()}
