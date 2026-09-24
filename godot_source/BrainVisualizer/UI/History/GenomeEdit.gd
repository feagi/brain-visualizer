extends RefCounted
class_name GenomeEdit
## One undoable genome gesture. Position and delete steps share this stack.


var label: String = ""


func is_empty() -> bool:
	return true
