extends RefCounted
class_name GenomeObject
## Any singular object that exists in the genome (essentially any object that can be within a region) that can be linked

static func are_siblings(A: GenomeObject, B: GenomeObject) -> bool:
	var par_A: BrainRegion = A.get_parent_region()
	var par_B: BrainRegion = B.get_parent_region()
	
	if (par_A == null) or (par_B == null):
		return false
	return par_A.ID == par_B.ID
		
	
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
