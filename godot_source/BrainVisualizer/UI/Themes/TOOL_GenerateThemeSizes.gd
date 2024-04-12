@tool
extends EditorScript

#Config - change to relevant targets
const BASE_SCALE_THEME: Theme = preload("res://BrainVisualizer/UI/Themes/dark.tres") # The 1.0 base theme to import
const size_targets: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] # the scaling options
const THEME_BASE_NAME: StringName = "Dark" # the root name of your themes

# Run this code by right clicking this script in the code editor and clicking run


## Code

func _run():
	
	for size: float in size_targets:
		
		var export_theme: Theme = BASE_SCALE_THEME.duplicate()
		
		
	
	
	



