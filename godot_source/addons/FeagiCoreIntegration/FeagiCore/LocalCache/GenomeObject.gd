extends RefCounted
class_name GenomeObject
## Any singular object that exists in the genome (essentially any object that can be within a region) that can be linked

enum ARRAY_MAKEUP {
	SINGLE_CORTICAL_AREA,
	SINGLE_BRAIN_REGION,
	MULTIPLE_CORTICAL_AREAS,
	MULTIPLE_BRAIN_REGIONS,
	VARIOUS_GENOME_OBJECTS,
	UNKNOWN
}

static func are_siblings(A: GenomeObject, B: GenomeObject) -> bool:
	var par_A: BrainRegion = A.get_parent_region()
	var par_B: BrainRegion = B.get_parent_region()
	
	if (par_A == null) or (par_B == null):
		return false
	return par_A.ID == par_B.ID


static func get_makeup_of_array(genome_objects: Array[GenomeObject]) -> ARRAY_MAKEUP:
	if len(genome_objects) == 0:
		return ARRAY_MAKEUP.UNKNOWN
	if len(genome_objects) == 1:
		if genome_objects[0] is BaseCorticalArea:
			return ARRAY_MAKEUP.SINGLE_CORTICAL_AREA
		if genome_objects[0] is BrainRegion:
			return ARRAY_MAKEUP.SINGLE_BRAIN_REGION
		return ARRAY_MAKEUP.UNKNOWN
	var br: bool
	var ca: bool
	for selection in genome_objects:
		if selection is BaseCorticalArea:
			ca = true
			continue
		if selection is BrainRegion:
			br = true
			continue
		return ARRAY_MAKEUP.UNKNOWN
		
	if br and ca:
		return ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS
	if br:
		return ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS
	return ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS

static func get_ID_array(genome_objects: Array[GenomeObject]) -> Array[StringName]:
	var output: Array[StringName] = []
	for object in genome_objects:
		output.append(object.get_ID())
	return output

static func filter_cortical_areas(genome_objects: Array[GenomeObject]) -> Array[BaseCorticalArea]:
	var output: Array[BaseCorticalArea] = []
	for object in genome_objects:
		if object is BaseCorticalArea:
			output.append(object as BaseCorticalArea)
	return output

static func filter_brain_regions(genome_objects: Array[GenomeObject]) -> Array[BrainRegion]:
	var output: Array[BrainRegion] = []
	for object in genome_objects:
		if object is BrainRegion:
			output.append(object as BrainRegion)
	return output

## Generic function to ge tthe parent region of a [GenomeObject]. Returns null if this is run on the root parent
func get_parent_region() -> BrainRegion:
	if self is BrainRegion:
		if (self as BrainRegion).is_root_region():
			return null
		return (self as BrainRegion).parent_region
	if self is BaseCorticalArea:
		return (self as BaseCorticalArea).current_region
	push_error("FEAGI CORE CACHE: Unable to get parent region of unknown GenomeObject type!")
	return null

func get_name() -> StringName:
	if self is BrainRegion:
		return (self as BrainRegion).name
	if self is BaseCorticalArea:
		return (self as BaseCorticalArea).name
	return "UNKNOWN"

func get_ID() -> StringName:
	if self is BrainRegion:
		return (self as BrainRegion).cortical_ID
	if self is BaseCorticalArea:
		return (self as BaseCorticalArea).ID
	return "UNKNOWN"
