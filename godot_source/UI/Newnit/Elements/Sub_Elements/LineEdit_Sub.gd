extends LineEdit_Base_Sub
class_name LineEdit_Sub


var value:
	get: return rootText
	set(v): SetText(v, rootText)



# built in vars
# text: String
# size: Vector2
# editable: bool
# expand_to_text_length: bool
# max_length: int
# text_changed: Signal
# text_submitted: Signal
# placeholder_text: String
