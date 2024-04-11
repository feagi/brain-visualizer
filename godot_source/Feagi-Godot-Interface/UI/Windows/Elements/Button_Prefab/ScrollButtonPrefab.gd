extends Button
class_name ScrollButtonPrefab
## A very simple prefab that can be spawned in for the scroll container
## Use this as a simple tutorial for how to create Scroll Prefabs

signal prefab_pressed(prefab_reference: ScrollButtonPrefab)

func _ready():
	pressed.connect(_on_pressed)

# All prefabs are required to have a setup function to take in a dictionary
# when spawning, and the reference to the main window this is a part of

## Uses the "name" key from the input dictionary to set the name of the node
## and the "text" key to set the string visible on the button
func setup(data: Dictionary, _main_window: Node) -> void:
	# In this case, we don't care to have a reference to the main window
	# in some other prefabs though, you may want this
	
	name = data["name"]
	text = data["text"]

func _on_pressed() -> void:
	prefab_pressed.emit(self)
