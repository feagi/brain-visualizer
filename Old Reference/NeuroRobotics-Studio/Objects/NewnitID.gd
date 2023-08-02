extends Object
class_name NewnitID

# This script is just to segregate Newnit from String
# Every time you open this file, a functional programmer is born
# TODO: Implement

var ID: String:
	get: return _ID
	
var str: String:
	get: return _ID

var _ID: String

func _init(id: String):
	_ID = id
