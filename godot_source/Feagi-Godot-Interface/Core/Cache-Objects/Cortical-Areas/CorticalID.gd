extends Object
class_name CorticalID
## This script is just to segregate CortexIDs from String
## Every time you gaze upon this file, a functional programmer is born

var ID: StringName:
	get: return _ID

var string: StringName:
	get: return _ID

var _ID: StringName

func _init(id: StringName):
	_ID = id
