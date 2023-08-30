extends Object
class_name MappingsFactory
## a static class meant to hand generating mapping objects from the dictionaries FEAGI outputs

## Given the dictionary from the FEAGI mapping properties call directly creates a MappingProperties object
static func MappingProperties_from_mapping_properties(mapping_properties_from_FEAGI: Array[Dictionary], source_area: CorticalArea, destination_area: CorticalArea) -> MappingProperties:
    var mappings: Array[MappingProperty] = []
    for raw_mappings in mapping_properties_from_FEAGI:
        if raw_mappings["morphology_id"] not in FeagiCache.morphology_cache.available_morphologies.keys():
            push_error("Unable to add specific mapping due to missing morphology %s in the internal cache! Skipping!" % [raw_mappings["morphology_id"]])
            continue
        mappings.append(MappingProperty_from_dict(raw_mappings))
    return MappingProperties.new(source_area, destination_area, mappings)

## Given the dictionary from FEAGI directly creates a MappingProperty object
static func MappingProperty_from_dict(mapping_property: Dictionary) -> MappingProperty:
    var morphology_used: Morphology = FeagiCache.morphology_cache.available_morphologies[mapping_property["morphology_id"]]
    var scalar_used: Vector3i = FEAGIUtils.array_to_vector3i(mapping_property["morphology_scalar"])
    var multiplier: float = mapping_property["postSynapticCurrent_multiplier"]
    var plasticity: bool = mapping_property["plasticity_flag"]
    return MappingProperty.new(morphology_used, scalar_used, multiplier, plasticity)
