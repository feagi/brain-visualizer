extends Object
class_name CorticalConnections
## stores a forward and reverse dictionary for rapid connections lookup

var _forward: Dictionary
var _backward: Dictionary


# For adding a connection in the data store
func AddConnection(cortical_source_ID: String, cortical_destination_ID: String, label: Connection_Label) -> void:
	_AddForward(cortical_source_ID, cortical_destination_ID, label)
	_AddBackward(cortical_source_ID, cortical_destination_ID, label)

# For removing a connection from the data store
func RemoveConnection(cortical_source_ID: String, cortical_destination_ID: String) -> void:
	_RemoveForward(cortical_source_ID, cortical_destination_ID)
	_RemoveBackward(cortical_source_ID, cortical_destination_ID)

# To check if a specific connection even exists
func DoesConnectionExist(cortical_source_ID: String, cortical_destination_ID: String) -> bool:
	if cortical_source_ID not in _forward.keys(): return false
	if cortical_destination_ID not in _forward[cortical_source_ID].keys(): return false
	return true

# Get a specific connection Label. Will Error if it doesn't exist
func GetSpecificConnectionLabel(cortical_source_ID: String, cortical_destination_ID: String) -> Connection_Label:
	return _forward[cortical_source_ID][cortical_destination_ID]
	
# Get an array of connection labels that have a given source
func GetConnectionLabelsWithSource(cortical_source_ID: String) -> Array[Connection_Label]:
	if cortical_source_ID not in _forward.keys: return []
	return _forward[cortical_source_ID].keys()

# Get an array of connection labels that have a given destination
func GetConnectionLabelsWithDestination(cortical_destination_ID: String) -> Array[Connection_Label]:
	if cortical_destination_ID not in _backward.keys: return []
	return _backward[cortical_destination_ID].keys()


func _AddForward(cortical_source_ID: String, cortical_destination_ID: String, label: Connection_Label) -> void:

	if cortical_source_ID not in _forward.keys():
		_forward[cortical_source_ID] = {}
	
	if cortical_destination_ID not in _forward[cortical_source_ID].keys():
		_forward[cortical_source_ID][cortical_destination_ID] = label
		return
	
	#@warning_ignore("assert_always_false")
	#assert(false, "Attemped to define already existing connection " + cortical_source_ID + " -> " + cortical_destination_ID)

func _RemoveForward(cortical_source_ID: String, cortical_destination_ID: StringD) -> void:
	_forward[cortical_source_ID].erase(cortical_destination_ID)
	if _forward[cortical_source_ID] == {}: _forward.erase(cortical_source_ID)

func _AddBackward(cortical_source_ID: String, cortical_destination_ID: String, label: Connection_Label) -> void:

		if cortical_destination_ID not in _backward.keys():
			_backward[cortical_destination_ID] = {}
		
		if cortical_source_ID not in _backward[cortical_destination_ID].keys():
			_backward[cortical_destination_ID][cortical_source_ID] = label
			return
	
		#@warning_ignore("assert_always_false")
		#assert(false, "Attemped to define already existing connection " + cortical_source_ID + " -> " + cortical_destination_ID)

func _RemoveBackward(cortical_source_ID: String, cortical_destination_ID: String) -> void:
	_backward[cortical_destination_ID].erase(cortical_source_ID)
	if _backward[cortical_destination_ID] == {}: _backward.erase(cortical_destination_ID)
