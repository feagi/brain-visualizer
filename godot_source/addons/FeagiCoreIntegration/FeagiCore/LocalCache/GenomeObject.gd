extends RefCounted
class_name GenomeObject
## An 'Abstract' class. Any singular object that exists in the genome (essentially any object that can be within a region) that can be linked and exist in a [BrainRegion]

signal friendly_name_updated(new_name: StringName)
signal coordinates_2D_updated(new_position: Vector2i)
signal coordinates_3D_updated(new_position: Vector3i)
signal dimensions_3D_updated(new_dimension: Vector3i)
signal parent_region_updated(old_region: BrainRegion, new_region: BrainRegion)
signal input_link_added(link: ConnectionChainLink)
signal output_link_added(link: ConnectionChainLink)
signal input_link_removed(link: ConnectionChainLink)
signal output_link_removed(link: ConnectionChainLink)
signal about_to_be_deleted() # Each inherited class calls this in its own way
signal highlighted_state_updated(is_highlighted: bool) ## UI use, for letting UIs know if this object is highlighted or not

enum ARRAY_MAKEUP {
	SINGLE_CORTICAL_AREA,
	SINGLE_BRAIN_REGION,
	MULTIPLE_CORTICAL_AREAS,
	MULTIPLE_BRAIN_REGIONS,
	VARIOUS_GENOME_OBJECTS,
	UNKNOWN
}

enum SINGLE_MAKEUP {
	SINGLE_CORTICAL_AREA,
	SINGLE_BRAIN_REGION,
	ANY_GENOME_OBJECT,
	UNKNOWN
}

## The ID FEAGI uses to identify this object. Beware that cortical IDs != BrainRegion IDs
var genome_ID: StringName:
	get: return _genome_ID

var friendly_name: StringName:
	get: return _friendly_name

var coordinates_2D: Vector2i:
	get: return _coordinates_2D

var coordinates_3D: Vector3i:
	get: return _coordinates_3D

var dimensions_3D: Vector3i:
	get: return _dimensions_3D

## What region is this object under?
var current_parent_region: BrainRegion:
	get: return _parent_region

## What [ConnectionChainLink]s are going into this object?
var input_chain_links: Array[ConnectionChainLink]:
	get: return _input_chain_links

## What [ConnectionChainLink] are leaving this object
var output_chain_links: Array[ConnectionChainLink]:
	get: return _output_chain_links

var is_highlighted: bool:
	get: return _is_highlighted

var _genome_ID: StringName
var _friendly_name: StringName
var _coordinates_2D: Vector2i
var _coordinates_3D: Vector3i
var _dimensions_3D: Vector3i
var _parent_region: BrainRegion
var _input_chain_links: Array[ConnectionChainLink]
var _output_chain_links: Array[ConnectionChainLink]
var _is_highlighted: bool = false

#region Static Functions

## Check if 2 Genome Object have the same parent region
static func are_siblings(A: GenomeObject, B: GenomeObject) -> bool:
	var par_A: BrainRegion = A.current_parent_region
	var par_B: BrainRegion = B.current_parent_region
	
	if (par_A == null) or (par_B == null):
		return false
	return par_A.region_ID == par_B.region_ID

## Return if a given array of GenomeObjects are only of one type, or mixed
static func get_makeup_of_array(genome_objects: Array[GenomeObject]) -> ARRAY_MAKEUP:
	if len(genome_objects) == 0:
		return ARRAY_MAKEUP.UNKNOWN
	if len(genome_objects) == 1:
		if genome_objects[0] is AbstractCorticalArea:
			return ARRAY_MAKEUP.SINGLE_CORTICAL_AREA
		if genome_objects[0] is BrainRegion:
			return ARRAY_MAKEUP.SINGLE_BRAIN_REGION
		return ARRAY_MAKEUP.UNKNOWN
	var br: bool
	var ca: bool
	for selection in genome_objects:
		if selection == null:
			return ARRAY_MAKEUP.UNKNOWN
		if selection is AbstractCorticalArea:
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

static func get_makeup_of_single_object(genome_object: GenomeObject) -> SINGLE_MAKEUP:
	if genome_object == null:
		return SINGLE_MAKEUP.UNKNOWN
	if genome_object is AbstractCorticalArea:
		return SINGLE_MAKEUP.SINGLE_CORTICAL_AREA
	if genome_object is BrainRegion:
		return SINGLE_MAKEUP.SINGLE_BRAIN_REGION
	return SINGLE_MAKEUP.UNKNOWN

static func is_given_object_covered_by_makeup(given: GenomeObject, makeup: SINGLE_MAKEUP) -> bool:
	var given_type: SINGLE_MAKEUP = GenomeObject.get_makeup_of_single_object(given)
	if given_type == SINGLE_MAKEUP.UNKNOWN:
		return false
	if makeup == SINGLE_MAKEUP.ANY_GENOME_OBJECT:
		return true
	return given_type == makeup
	

## Given an array of GenomeObjects, return a String Array of their Genome_IDs
static func get_ID_array(genome_objects: Array[GenomeObject]) -> Array[StringName]:
	var output: Array[StringName] = []
	for object in genome_objects:
		output.append(object.genome_ID)
	return output

## Given an Array of GenomeObjects, return only the AbstractCorticalAreas
static func filter_cortical_areas(genome_objects: Array[GenomeObject]) -> Array[AbstractCorticalArea]:
	var output: Array[AbstractCorticalArea] = []
	for object in genome_objects:
		if object is AbstractCorticalArea:
			output.append(object as AbstractCorticalArea)
	return output

## Given an Array of GenomeObjects, return only the BrainRegions
static func filter_brain_regions(genome_objects: Array[GenomeObject]) -> Array[BrainRegion]:
	var output: Array[BrainRegion] = []
	for object in genome_objects:
		if object is BrainRegion:
			output.append(object as BrainRegion)
	return output

## Gets average 2D location of all given [GenomeObject]s. Probably only makes sense if you use this on objects all within one subregion
static func get_average_2D_location(objects: Array[GenomeObject]) -> Vector2i:
	var output: Vector2i = Vector2i(0,0)
	for object in objects:
		output += object.coordinates_2D
	return Vector2i( int( float(output.x) / float(len(objects) )), int( float(output.y) / float(len(objects) )) )
	
	

#endregion

#region FEAGI Interactions

func FEAGI_change_friendly_name(new_name: StringName) -> void:
	if new_name == _friendly_name:
		return
	_friendly_name = new_name
	friendly_name_updated.emit(new_name)

func FEAGI_change_coordinates_2D(new_coord_2D: Vector2i) -> void:
	if _coordinates_2D == new_coord_2D:
		return
	_coordinates_2D = new_coord_2D
	coordinates_2D_updated.emit(new_coord_2D)

func FEAGI_change_coordinates_3D(new_coord_3D: Vector3i) -> void:
	if _coordinates_3D == new_coord_3D:
		return
	_coordinates_3D = new_coord_3D
	coordinates_3D_updated.emit(new_coord_3D)

func FEAGI_change_dimensions_3D(new_dim_3D: Vector3i) -> void:
	if _dimensions_3D == new_dim_3D:
		return
	_dimensions_3D = new_dim_3D
	dimensions_3D_updated.emit(new_dim_3D)

## Change from one existing parent region to another
func FEAGI_change_parent_brain_region(new_parent_region: BrainRegion) -> void:
	if new_parent_region.region_ID == _parent_region.region_ID:
		return
	var old_region_cache: BrainRegion = _parent_region # yes this method uses more memory but avoids potential shenanigans
	_parent_region = new_parent_region
	old_region_cache.FEAGI_genome_object_deregister_as_child(self)
	new_parent_region.FEAGI_genome_object_register_as_child(self)
	parent_region_updated.emit(old_region_cache, new_parent_region)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region. 
func FEAGI_input_add_link(link: ConnectionChainLink) -> void:
	if link in _input_chain_links:
		push_error("CORE CACHE: Unable to add input link to object %s when it already exists!" % _genome_ID)
		return
	_input_chain_links.append(link)
	input_link_added.emit(link)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func FEAGI_output_add_link(link: ConnectionChainLink) -> void:
	if link in _output_chain_links:
		push_error("CORE CACHE: Unable to add output link to object %s when it already exists!" % _genome_ID)
		return
	_output_chain_links.append(link)
	output_link_added.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func FEAGI_input_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _input_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from object %s as it wasn't found!" % _genome_ID)
		return
	_input_chain_links.remove_at(index)
	input_link_removed.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func FEAGI_output_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _output_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from object %s as it wasn't found!" % _genome_ID)
		return
	_output_chain_links.remove_at(index)
	output_link_removed.emit(link)

#endregion

##
func is_sibling(possible_sibling: GenomeObject) -> bool:
	return GenomeObject.are_siblings(self, possible_sibling)

func set_highlighted_state(highlighted: bool) -> void:
	if highlighted == _is_highlighted:
		return
	_is_highlighted = highlighted
	highlighted_state_updated.emit(highlighted)

func _init_self_to_brain_region(parent_region: BrainRegion) -> void:
	_parent_region = parent_region
	if _parent_region != null: ## The root region has no parent
		parent_region.FEAGI_genome_object_register_as_child(self)
