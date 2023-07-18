extends Object
class_name MorphologyBase
# Base class for other morphology types

signal morphologyUpdated(MorphologyBase)

var name: String:
	get: return _name

var timeOfLastMorphologyUpdate: float:
	get: return _timeOfLastMorphologyUpdate

var secondsSinceLastMorphologyUpdate: float:
	get: return  _timeOfLastMorphologyUpdate - Time.get_unix_time_from_system()

var _name: String
var _timeOfLastMorphologyUpdate: float

func _init(morphologyName: String):
	_name = morphologyName
	_timeOfLastMorphologyUpdate = Time.get_unix_time_from_system()

