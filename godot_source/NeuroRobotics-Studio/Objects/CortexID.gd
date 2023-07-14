extends Object
class_name CortexID

# This script is just to segregate CortexIDs from String
# Every time you open this file, a functional programmer is born

var ID: String:
	get: return _ID
	
var str: String:
	get: return _ID

var _ID: String

func _init(id: String):
	_ID = id
