extends Label
class_name Label_Element

@export var max_length: int = 20

@export var label_text: String:
	get: return text
	set(v):
		text = FEAGIUtils.limit_text_length(v, max_length)
	
