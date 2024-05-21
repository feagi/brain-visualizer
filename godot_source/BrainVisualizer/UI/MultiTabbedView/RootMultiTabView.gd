extends MultiTabView
class_name RootMultiTabView
## [MultiTabView] but with additional functions to allow child views to register themselves to this

var circuit_builder_instances: Dictionary: ## Key'd by ID String
	get: return _circuit_builder_instances

var _circuit_builder_instances: Dictionary = {}

## Called by [UIManager] upon the loading of a genome, sets up the views of the root region
func setup_with_root_regions() -> void:
	if !FeagiCore.feagi_local_cache.brain_regions.is_root_available():
		push_error("UI: Unable to add views of root region as the region does not exist!")
		return
	primary_tabs.add_CB_tab(FeagiCore.feagi_local_cache.brain_regions.return_root_region())
	$SplitContainer/Secondary.visible = false
	

## Called by [MultiTabView] during their instantiation to be registered to this object
func CB_register(circuit_builder_ref: CircuitBuilder) -> void:
	if circuit_builder_ref.representing_region.ID in _circuit_builder_instances.keys():
		push_error("UI: Unable to add circuit builder ref of region %s to RootMultiTabView when it already exists!" % circuit_builder_ref.representing_region.ID)
		return
	_circuit_builder_instances[circuit_builder_ref.representing_region.ID] = circuit_builder_ref

## Called by [MultiTabView] during their destrution to be deregistered to this object
func CB_deregister(circuit_builder_ref: CircuitBuilder) -> void:
	if !(circuit_builder_ref.representing_region.ID in _circuit_builder_instances.keys()):
		push_error("UI: Unable to remove circuit builder ref of region %s to RootMultiTabView when it isn't there!" % circuit_builder_ref.representing_region.ID)
		return
	_circuit_builder_instances.erase(circuit_builder_ref.representing_region.ID)

## Gets the CB instance representing root (null if not registed)
func get_root_CB() -> CircuitBuilder:
	if BrainRegion.ROOT_REGION_ID in _circuit_builder_instances.keys():
		return _circuit_builder_instances[BrainRegion.ROOT_REGION_ID]
	return null

func is_existing_CB_of_region(region: BrainRegion) -> bool:
	return region.ID in circuit_builder_instances.keys()
