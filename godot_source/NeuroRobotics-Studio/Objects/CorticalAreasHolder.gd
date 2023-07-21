extends Object
## Holds the various cortical area cached data and proccess them automatically
class_name CorticalAreasHolder


var CorticalAreaID2NameMapping: Dictionary:
	get: return _CorticalAreaID2NameMapping

var timeOfLastMappingUpdate: float:
	get: return _timeofLastMappingUpdate

var secondsSinceLastMappingUpdate: float:
	get: return  _timeofLastMappingUpdate - Time.get_unix_time_from_system()


var _timeofLastMappingUpdate: float
var _CorticalAreaID2NameMapping: Dictionary
var _CorticalAreasMapped2IDs: Dictionary
var _coreRef: Core


func _init(coreReference: Core) -> void:
	_coreRef = coreReference

func _UpdateCorticalAreaID2NameMapping( mapping: Dictionary) -> void:
	_CorticalAreaID2NameMapping = mapping
	
	pass
