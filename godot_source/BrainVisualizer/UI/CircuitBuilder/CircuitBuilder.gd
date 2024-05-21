extends GraphEdit
class_name CircuitBuilder
## A 2D Node based representation of a specific Genome Region

@export var move_time_delay_before_update_FEAGI: float = 5.0
@export var initial_position: Vector2
@export var initial_zoom: float
@export var keyboard_movement_speed: Vector2 = Vector2(1,1)
@export var keyboard_move_speed: float = 50.0


var representing_region: BrainRegion:
	get: return _representing_region
var cortical_nodes: Dictionary:## All cortical nodes on CB, key'd by their cortical ID 
	get: return  _cortical_nodes 
var subregion_nodes: Dictionary: ## All subregion nodes on CB, key'd by their region ID
	get: return _subregion_nodes

var _cortical_nodes: Dictionary = {}
var _subregion_nodes: Dictionary = {}
var _representing_region: BrainRegion

func setup(region: BrainRegion) -> void:
	_representing_region = region
	
	for area: BaseCorticalArea in _representing_region.contained_cortical_areas:
		CACHE_add_cortical_area(area)
	
	for subregion: BrainRegion in _representing_region.contained_regions:
		CACHE_add_subregion(subregion)
	
	name = region.name
	
	region.name_changed.connect(CACHE_region_name_update)

#region Responses to Cache Signals

func CACHE_add_cortical_area(area: BaseCorticalArea) -> void:
	print("adding " + area.cortical_ID)

func CACHE_remove_cortical_area(area: BaseCorticalArea) -> void:
	pass

func CACHE_add_subregion(subregion: BrainRegion) -> void:
	print("adding " + subregion.ID)

func CACHE_remove_subregion(subregion: BrainRegion) -> void:
	pass

func CACHE_region_name_update(new_name: StringName) -> void:
	name = new_name
