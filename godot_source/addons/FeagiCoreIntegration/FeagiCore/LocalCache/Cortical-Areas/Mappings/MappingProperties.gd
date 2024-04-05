extends Object
class_name MappingProperties
## Holds all [MappingProperty] objects / data relevant between a single source and a single destination cortical area

enum SIGNAL_TYPE{
	EXCITATORY,
	INHIBITORY,
	MIXED
}

signal mappings_changed(self_mappings: MappingProperties)
signal mappings_about_to_be_deleted()

var source_cortical_area: BaseCorticalArea:
	get: return _src_cortical
var destination_cortical_area: BaseCorticalArea:
	get: return _dst_cortical
var mappings: Array[MappingProperty]:
	get: return _mappings
var number_mappings: int:
	get: return len(_mappings)
var max_axis_indexmapping_count_limit: int:
	get: return _max_number_mappings_supported
var morphologies_restricted_to: Array[ BaseMorphology]:
	get: return _morphologies_restricted_to
var is_limit_on_mapping_count: bool:
	get: return _max_number_mappings_supported != -1
var is_restriction_on_morphologies_used: bool:
	get: return len(_morphologies_restricted_to) != 0

var _src_cortical: BaseCorticalArea
var _dst_cortical: BaseCorticalArea
var _mappings: Array[MappingProperty]
var _max_number_mappings_supported: int = -1
var _morphologies_restricted_to: Array[ BaseMorphology] = []

func _init(source_area: BaseCorticalArea, destination_area: BaseCorticalArea, mappings_between_them: Array[MappingProperty]) -> void:
	_src_cortical = source_area
	_dst_cortical = destination_area
	_mappings = mappings_between_them
	_max_number_mappings_supported = MappingHints.get_allowed_mapping_count(source_area, destination_area)
	_morphologies_restricted_to = MappingHints.get_allowed_morphologies_to_map_toward(source_area, destination_area)

## Given the dictionary from the FEAGI mapping properties call directly creates a MappingProperties object. Yes the spelling is correct
static func from_FEAGI_mapping_properties(mapping_properties_from_FEAGI: Array, source_area: BaseCorticalArea, destination_area: BaseCorticalArea) -> MappingProperties:
	var new_mappings: Array[MappingProperty] = []
	for raw_mappings in mapping_properties_from_FEAGI:
		if raw_mappings["morphology_id"] not in FeagiCache.morphology_cache.available_morphologies.keys():
			push_error("Unable to add specific mapping due to missing morphology %s in the internal cache! Skipping!" % [raw_mappings["morphology_id"]])
			continue
		new_mappings.append(MappingProperty.from_dict(raw_mappings))
	return MappingProperties.new(source_area, destination_area, new_mappings)

## Creates an empty mapping between a source and destination cortical area
static func create_empty_mapping(source_area: BaseCorticalArea, destination_area: BaseCorticalArea) -> MappingProperties:
	var empty_typed_array: Array[MappingProperty] = [] # Because the array type casting in godot is still stupid. Too Bad!
	return MappingProperties.new(source_area, destination_area, empty_typed_array)

## Creates a default mapping object given a source, destination, and morphology to use. Default settings will be used
static func create_default_mapping(source_area: BaseCorticalArea, destination_area: BaseCorticalArea, morphology_to_use: Base BaseMorphology) -> MappingProperties:
	var default_mapping: Array[MappingProperty] = [MappingProperty.create_default_mapping(morphology_to_use)]
	return MappingProperties.new(source_area, destination_area, default_mapping)

## Returns an array of the [MappingProperty] objects as FEAGI formatted dictionaries
static func mapping_properties_to_FEAGI_formated_array(input_mappings: Array[MappingProperty]) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for mapping: MappingProperty in input_mappings:
		if !mapping.is_null_placeholder:
			output.append(mapping.to_dictionary())
		else:
			push_error("Exporting MappingProperty that is a placeholder mapping. These placeholders will be skipped in the export in an attempt at stability, but this should never happen!")
	return output

## Returns an array with no duplicates of all morphologies within an array of Mapping Propertys
static func get_involved_morphologies_from_mapping_propertys(input_mappings: Array[MappingProperty]) -> Array[ BaseMorphology]:
	var morphologies_involved: Array[ BaseMorphology] = []
	for mapping: MappingProperty in input_mappings:
		if !(mapping.morphology_used in morphologies_involved):
			morphologies_involved.append(mapping.morphology_used)
	return morphologies_involved

## Returns an array of the internal [MappingProperty] objects as FEAGI formatted dictionaries
func to_FEAGI_formatted_array() -> Array[Dictionary]:
	return MappingProperties.mapping_properties_to_FEAGI_formated_array(_mappings)

func add_mapping_manually(new_mapping: MappingProperty) -> void:
	_mappings.append(new_mapping)

func remove_mapping(index: int) -> void:
	if index >= len(_mappings) or index < 0:
		push_error("mapping index to remove is out of range! Skipping!")
		return
	_mappings.remove_at(index)

## Deletes all mappings
func clear() -> void:
	var empty: Array[MappingProperty] = []
	_mappings = empty # casting shenanigans
	mappings_changed.emit(self)

func duplicate() -> MappingProperties:
	return MappingProperties.new(_src_cortical, _dst_cortical, _mappings)

## Merges the mappings of another [MappingProperties] (given that the source and destination cortical areas match)
func merge_in_mapping_properties(to_merge_in: MappingProperties) -> void:
	if _src_cortical.cortical_ID != to_merge_in.source_cortical_area.cortical_ID:
		push_error("Unable to merge MappingProperties with different source areas! Skipping merge!")
		return
	if _dst_cortical.cortical_ID != to_merge_in.destination_cortical_area.cortical_ID:
		push_error("Unable to merge MappingProperties with different destination areas! Skipping merge!")
		return
	_mappings.append_array(to_merge_in.mappings)

## Returns true if any other internal mappings are plastic
func is_any_mapping_plastic() -> bool:
	for mapping: MappingProperty in mappings:
		if mapping.is_plastic:
			return true
	return false

## Returns true if any mapping's PSP multiplier is positive
func is_any_PSP_multiplier_positive() -> bool:
	for mapping: MappingProperty in mappings:
		if mapping.post_synaptic_current_multiplier > 0.0:
			return true
	return false

## Returns true if any mapping's PSP multiplier is negative
func is_any_PSP_multiplier_negative() -> bool:
	for mapping: MappingProperty in mappings:
		if mapping.post_synaptic_current_multiplier < 0.0:
			return true
	return false

func is_PSP_multiplers_mixed_sign() -> bool:
	return is_any_PSP_multiplier_negative() and is_any_PSP_multiplier_positive()

func get_PSP_signal_type() -> SIGNAL_TYPE:
	if is_any_PSP_multiplier_negative():
		if is_any_PSP_multiplier_positive():
			return SIGNAL_TYPE.MIXED
		else:
			return SIGNAL_TYPE.INHIBITORY
	return SIGNAL_TYPE.EXCITATORY

## Returns true if the connection maps a cortical area toward itself
func is_recursive() -> bool:
	return source_cortical_area.cortical_ID == destination_cortical_area.cortical_ID

## Returns true if there are no mappings (disconnected), about to be deleted
func is_empty() -> bool:
	return len(_mappings) == 0

## Replace mapping data within this object
func update_mappings(updated_mappings: Array[MappingProperty]) -> void:
	_mappings = updated_mappings
	mappings_changed.emit(self)

## Replace mapping data with an empty array
## NOTE: This object gets deleted if its empty, beware of null references!
func update_mappings_to_empty() -> void:
	var empty: Array[MappingProperty] = []
	_mappings = empty
	mappings_changed.emit(self)

## Does mapping follow mapping count and morphology restrictions from cortical areas?
func is_mapping_valid() -> bool:
	return MappingHints.is_mapping_property_array_invalid_for_cortical_areas(_src_cortical, _dst_cortical, _mappings)
