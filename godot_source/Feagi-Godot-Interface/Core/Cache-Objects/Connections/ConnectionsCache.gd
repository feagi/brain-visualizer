extends Object
class_name ConnectionsCache
## stores a forward and reverse dictionary for rapid connections lookup

var forward_mappings_with_counts: Dictionary:
	get:
		return _forward_with_count

var _backward: Dictionary = {} # cortical dst -> array of cortical srcs
var _forward_with_count: Dictionary = {} # cortical src -> dict of cortitcal dst -> mapping count (int)

## Called from FEAGIs cortical_map endpoint. Adds missing connections and removes connections no longer listed
func mass_set_connections(cortical_map: Dictionary) -> void:
	# This function is not particuarly efficient. Too Bad!

	var input_sources: Array = cortical_map.keys()
	var current_sources: Array = _forward_with_count.keys()
	var sources_to_add: Array = FEAGIUtils.find_missing_elements(input_sources, current_sources)
	var sources_to_remove: Array = FEAGIUtils.find_missing_elements(current_sources, input_sources)
	var sources_to_check: Array = FEAGIUtils.find_union(current_sources, input_sources)
	
	# all connections where source is missing
	for source in sources_to_add:
		var destinations: Dictionary = cortical_map[source]
		for destination in destinations.keys():
			add_connection(source, destination, cortical_map[source][destination])
	
	# all connections that need to be removed due to removed source
	for source in sources_to_remove:
		var destinations: Dictionary = _forward_with_count[source]
		for destination in destinations.keys():
			remove_connection(source, destination)
	
	# check the source per destination
	for source in sources_to_check:
		var input_destinations: Array = cortical_map[source].keys()
		var current_destinations: Array = _forward_with_count[source].keys()
		var destinations_to_add: Array = FEAGIUtils.find_missing_elements(input_destinations, current_destinations)
		var destinations_to_remove: Array = FEAGIUtils.find_missing_elements(current_destinations, input_destinations)
		var destinations_to_check: Array = FEAGIUtils.find_union(current_destinations, input_destinations)

		for destination_add in destinations_to_add:
			add_connection(source, destination_add, cortical_map[source][destination_add])
		
		for destination_remove in destinations_to_remove:
			remove_connection(source, destination_remove)
		
		for destination_edit in destinations_to_check:
			edit_connection_mapping_count(source, destination_edit, cortical_map[source][destination_edit])  # this function already checks if number doesnt need to be changed, and skips signal if not

## For adding a connection in the data store
func add_connection(cortical_source_ID: StringName, cortical_destination_ID: StringName, number_of_mappings: int) -> void:
	_add_forward(cortical_source_ID, cortical_destination_ID, number_of_mappings)
	_add_backward(cortical_source_ID, cortical_destination_ID)
	FeagiCacheEvents.cortical_areas_connected.emit(cortical_source_ID, cortical_destination_ID, number_of_mappings)

## For removing a connection from the data store
func remove_connection(cortical_source_ID: StringName, cortical_destination_ID: StringName) -> void:
	_remove_forward(cortical_source_ID, cortical_destination_ID)
	_remove_backward(cortical_source_ID, cortical_destination_ID)

## Edits the number of mappings a particular conneciton has
func edit_connection_mapping_count(cortical_source_ID: StringName, cortical_destination_ID: StringName, number_of_mappings: int) -> void:
	if cortical_source_ID not in _forward_with_count.keys():
		push_error("Unable to update mapping count for connection of %s to %s due to missing source connection!" % [cortical_source_ID, cortical_destination_ID])
		return

	if cortical_destination_ID not in forward_mappings_with_counts[cortical_source_ID].keys():
		push_error("Unable to update mapping count for connection of %s to %s due to missing destination connection!" % [cortical_source_ID, cortical_destination_ID])
		return

	if number_of_mappings == _forward_with_count[cortical_source_ID][cortical_destination_ID]:
		# no point updating anything if the number is the same!
		return

	_forward_with_count[cortical_source_ID][cortical_destination_ID] = number_of_mappings
	FeagiCacheEvents.cortical_areas_connection_modified.emit(cortical_source_ID, cortical_destination_ID, number_of_mappings)

## Returns true if a given connections exists
func does_connection_exist(cortical_source_ID: StringName, cortical_destination_ID: StringName) -> bool:
	if cortical_source_ID not in _forward_with_count.keys(): return false
	if cortical_destination_ID not in _forward_with_count[cortical_source_ID].keys(): return false
	return true

func _add_forward(source_cortical_ID: StringName, destination_cortical_ID: StringName, number_of_mappings: int) -> void:
	if source_cortical_ID not in _forward_with_count.keys():
		_forward_with_count[source_cortical_ID] = {destination_cortical_ID: number_of_mappings}
		return
	
	_forward_with_count[source_cortical_ID][destination_cortical_ID] = number_of_mappings

func _add_backward(source_cortical_ID: StringName, destination_cortical_ID: StringName) -> void:
	if destination_cortical_ID not in _backward.keys():
		_backward[destination_cortical_ID] = [source_cortical_ID]
		return
	
	_backward[destination_cortical_ID].append(source_cortical_ID)

func _remove_forward(source_cortical_ID: StringName, destination_cortical_ID: StringName) -> void:
	if source_cortical_ID not in forward_mappings_with_counts.keys():
		push_error("Unable to remove nonexistant source cortical ID %s from forward connection dict!" % [source_cortical_ID])
		return
	
	if destination_cortical_ID not in forward_mappings_with_counts[source_cortical_ID].keys():
		push_error("Unable to remove nonexistant destination cortical ID %s from forward connection dict!" % [destination_cortical_ID])
		return

	_forward_with_count[source_cortical_ID].erase(destination_cortical_ID)
	if _forward_with_count[source_cortical_ID] == {}:
		_forward_with_count.erase(source_cortical_ID)
	
func _remove_backward(source_cortical_ID: StringName, destination_cortical_ID: StringName) -> void:
	if destination_cortical_ID not in _backward.keys():
		push_error("Unable to remove nonexistant destination cortical ID %s from backward connection dict!" % [source_cortical_ID])
		return
	
	if source_cortical_ID not in _backward[destination_cortical_ID].keys():
		push_error("Unable to remove nonexistant source cortical ID %s from backward connection dict!" % [destination_cortical_ID])
		return

	_backward[destination_cortical_ID].erase(source_cortical_ID)
	if _backward[destination_cortical_ID] == {}:
		_backward.erase(destination_cortical_ID)

