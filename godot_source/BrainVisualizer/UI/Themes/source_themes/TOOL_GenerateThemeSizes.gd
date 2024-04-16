@tool
extends EditorScript

#Config - change to relevant targets
const BASE_SCALE_THEME: Theme = preload("res://BrainVisualizer/UI/Themes/source_themes/source_dark.tres") # The 1.0 base theme to import
const size_targets: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] # the scaling options
const THEME_BASE_NAME: StringName = "DARK" # the root name of your themes
const THEME_EXPORT_FOLDER: StringName = "res://BrainVisualizer/UI/Themes/"

# Run this code by right clicking this script in the code editor and clicking run


## Code

func _run():

	var folder: DirAccess = DirAccess.open(THEME_EXPORT_FOLDER) # Will error immedietly if the theme export folder isnt valid
#	
	for scalar: float in size_targets:
		var export_theme: Theme = BASE_SCALE_THEME.duplicate()
		print("\nGenerating theme for scale %f" % scalar)
		var types: PackedStringArray = export_theme.get_type_list()
		for type: StringName in types:
			print("Scaling %s..." % type)
			
			if export_theme.has_constant("size_x", type):
				export_theme.set_constant("size_x", type, int( float(export_theme.get_constant("size_x", type)) * scalar))
			if export_theme.has_constant("size_y", type):
				export_theme.set_constant("size_y", type, int( float(export_theme.get_constant("size_y", type)) * scalar))
			if export_theme.has_font_size("font_size", type):
				export_theme.set_font_size("font_size", type, int( float(export_theme.get_font_size("font_size", type)) * scalar))
			if export_theme.has_font_size("bold_font_size", type):
				export_theme.set_font_size("bold_font_size", type, int( float(export_theme.get_font_size("bold_font_size", type)) * scalar))
			if export_theme.has_font_size("bold_italics_font_size", type):
				export_theme.set_font_size("bold_italics_font_size", type, int( float(export_theme.get_font_size("bold_italics_font_size", type)) * scalar))
			if export_theme.has_font_size("italics_font_size", type):
				export_theme.set_font_size("italics_font_size", type, int( float(export_theme.get_font_size("italics_font_size", type)) * scalar))
			if export_theme.has_font_size("mono_font_size", type):
				export_theme.set_font_size("mono_font_size", type, int( float(export_theme.get_font_size("mono_font_size", type)) * scalar))
			if export_theme.has_font_size("normal_font_size", type):
				export_theme.set_font_size("normal_font_size", type, int( float(export_theme.get_font_size("normal_font_size", type)) * scalar))
			if export_theme.has_font_size("margin_bottom", type):
				export_theme.set_font_size("margin_bottom", type, int( float(export_theme.get_font_size("margin_bottom", type)) * scalar))
			if export_theme.has_font_size("margin_left", type):
				export_theme.set_font_size("margin_left", type, int( float(export_theme.get_font_size("margin_left", type)) * scalar))
			if export_theme.has_font_size("margin_right", type):
				export_theme.set_font_size("margin_right", type, int( float(export_theme.get_font_size("margin_right", type)) * scalar))
			if export_theme.has_font_size("margin_top", type):
				export_theme.set_font_size("margin_top", type, int( float(export_theme.get_font_size("margin_top", type)) * scalar))
		var name_prefix: StringName = str(scalar) + "-"
		var err = ResourceSaver.save(export_theme, THEME_EXPORT_FOLDER + name_prefix + THEME_BASE_NAME + ".tres")
	
	
	



