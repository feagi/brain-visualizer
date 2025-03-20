extends SubViewportContainer
class_name UI_BrainMonitor_3DScene
## Handles running the scene of Brain monitor, which shows a single instance of a brain region
const SCENE_BRAIN_MOINITOR_PATH: StringName = "res://addons/UI_BrainMonitor/BrainMonitor.tscn"

var representing_region: BrainRegion:
	get: return _representing_region

var _node_3D_root: Node3D
var _world_3D: World3D # used for physics stuff
var _representing_region: BrainRegion
var _cortical_visualizations_by_ID: Dictionary[StringName, UI_BrainMonitor_CorticalArea]
var _pancake_cam: UI_BrainMonitor_PancakeCamera


## Spawns an non-setup Brain Visualizer Scene. # WARNING be sure to add it to the scene tree before running setup on it!
static func create_uninitialized_brain_monitor() -> UI_BrainMonitor_3DScene:
	return load(SCENE_BRAIN_MOINITOR_PATH).instantiate()

func _ready() -> void:
	_node_3D_root = $SubViewport/Center
	
	
	# TODO check mode (PC)
	_pancake_cam = $SubViewport/Center/PancakeCam
	if _pancake_cam:
		_pancake_cam.BM_input_events.connect(_process_user_input)
		_world_3D = _pancake_cam.get_world_3d()
	

func setup(region: BrainRegion) -> void:
	_representing_region = region
	name = "BM_" + region.region_ID

	for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
		_add_cortical_area(area)



func _process_user_input(bm_input_events: Array[UI_BrainMonitor_InputEvent_Abstract]) -> void:
	var current_space: PhysicsDirectSpaceState3D = _world_3D.direct_space_state
	for bm_input_event in bm_input_events: # multiple events can happen at once
		if bm_input_event is UI_BrainMonitor_InputEvent_Hover:
			var hit: Dictionary = current_space.intersect_ray(bm_input_event.get_ray_query())
			if not hit.is_empty():
				print(hit)


#region Cache Responses

# NOTE: Cortical area movements, resizes, and renames are handled by the [UI_BrainMonitor_CorticalArea]s themselves!

func _add_cortical_area(area: AbstractCorticalArea) -> void:
	if area.cortical_ID in _cortical_visualizations_by_ID:
		push_warning("Unable to add to BM already existing cortical area of ID %s!" % area.cortical_ID)
		return
	var rendering_area: UI_BrainMonitor_CorticalArea = UI_BrainMonitor_CorticalArea.new()
	_node_3D_root.add_child(rendering_area)
	rendering_area.setup(area)
	_cortical_visualizations_by_ID[area.cortical_ID] = rendering_area

func _remove_cortical_area(area: AbstractCorticalArea) -> void:
	if area.cortical_ID not in _cortical_visualizations_by_ID:
		push_warning("Unable to remove from BM nonexistant cortical area of ID %s!" % area.cortical_ID)
		return
	var rendering_area: UI_BrainMonitor_CorticalArea = _cortical_visualizations_by_ID[area.cortical_ID]
	rendering_area.queue_free()
	_cortical_visualizations_by_ID.erase(area.cortical_ID)


#endregion
