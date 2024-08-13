extends AbstractLineInput
class_name TextInput
## Text box that user can input Strings into

# useful properties inherited
# text (NOTE - changing this via code does not cause signal up!)
# editable
# max_length

# do not use the text_changed and text_submitted signals due top various limitations with them, unless you have a specific reason to

## Only emits if user changes the text THEN focuses off the textbox
signal text_confirmed(new_text: String)


func _ready():
	super()

# In this context, any string is valid
## OVERRIDDEN: Formats the input to something acceptable for the use, or returns an empty string if this isn't possible
func _set_input_text_valid(input_text: String) -> String:
	return input_text

func _proxy_emit_confirmed_value(value_as_string: String) -> void:
	text_confirmed.emit(value_as_string)
