extends Object
class_name CortexID

# This script is just to segregate CortexIDs from String
# Every time you open this file, a functional programmer is born

var ID: StringName:
	get: return _ID

#TODO we probably shouldn't be calling this str
var str: StringName:
	get: return _ID

var _ID: StringName

func _init(id: StringName):
	_ID = id
