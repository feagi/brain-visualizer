extends Object
class_name MorphologyName

# This script is just to segregate Morphology Names from String
# Every time you open this file, a functional programmer is born

var name: StringName:
	get: return _name
	
var str: StringName:
	get: return _name

var _name: StringName

func _init(Name: String):
	_name = Name
