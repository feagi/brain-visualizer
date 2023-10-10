extends Object
class_name MappingProperties
## Holds all [MappingProperty] objects / data relevant between a single source and a single destination cortical area

var source_cortical_area: CorticalArea:
	get: return _src_cortical
var destination_cortical_area: CorticalArea:
	get: return _dst_cortical
var number_of_mappings: int:
	get: return len(mappings)
var mappings: Array[MappingProperty]:
	get: return _mappings

var _src_cortical: CorticalArea
var _dst_cortical: CorticalArea
var _mappings: Array[MappingProperty]

func _init(source_area: CorticalArea, destination_area: CorticalArea, mappings_between_them: Array[MappingProperty]) -> void:
	_src_cortical = source_area
	_dst_cortical = destination_area
	_mappings = mappings_between_them

## Returns an array of the internal [MappingProperty] objects as FEAGI formatted dictionaries
func to_array() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for mapping in _mappings:
		output.append(mapping.to_dictionary())
	return output

func add_mapping_manually(new_mapping: MappingProperty) -> void:
	_mappings.append(new_mapping)

func remove_mapping(index: int) -> void:
	if index >= len(_mappings) or index < 0:
		push_error("mapping index to remove is out of range! Skipping!")
		return
	_mappings.remove_at(index)

func duplicate() -> MappingProperties:
	return MappingProperties.new(_src_cortical, _dst_cortical, _mappings)

## Given the dictionary from the FEAGI mapping properties call directly creates a MappingProperties object. Yes the spelling is correct
static func from_MappingPropertys(mapping_properties_from_FEAGI: Array, source_area: CorticalArea, destination_area: CorticalArea) -> MappingProperties:
	var new_mappings: Array[MappingProperty] = []
	for raw_mappings in mapping_properties_from_FEAGI:
		if raw_mappings["morphology_id"] not in FeagiCache.morphology_cache.available_morphologies.keys():
			push_error("Unable to add specific mapping due to missing morphology %s in the internal cache! Skipping!" % [raw_mappings["morphology_id"]])
			continue
		new_mappings.append(MappingProperty.from_dict(raw_mappings))
	return MappingProperties.new(source_area, destination_area, new_mappings)

## Creates an empty mapping between a source and destination cortical area
static func create_empty_mapping(source_area: CorticalArea, destination_area: CorticalArea) -> MappingProperties:
	var empty_typed_array: Array[MappingProperty] = [] # Because the array type casting in godot is still stupid. Too Bad!
	return MappingProperties.new(source_area, destination_area, empty_typed_array)

## Creates a default mapping object given a source, destination, and morphology to use. Default settings will be used
static func create_default_mapping(source_area: CorticalArea, destination_area: CorticalArea, morphology_to_use: Morphology) -> MappingProperties:
	var default_mapping: Array[MappingProperty] = [MappingProperty.create_default_mapping(morphology_to_use)]
	return MappingProperties.new(source_area, destination_area, default_mapping)
