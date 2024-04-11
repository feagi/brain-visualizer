extends RefCounted
class_name ScaleThemeApplier
## Iterates over UI nodes (including recursively through children), and updates custom elements from theme automatically

var _nodes_to_not_include_or_search: Array[Node] ## when searching and this node is encountered, stop. We may have custom things here instead
var _texture_buttons: Array[TextureButton] = []
#var _detailed_container_buttons: Array[DetailedPanelContainerButton] = []

## Call this when all children were added to the tree so the reference arrays can be built
func setup(starting_node: Node, nodes_to_not_include_or_search: Array[Node], current_loaded_theme: Theme) -> void:
	_nodes_to_not_include_or_search = nodes_to_not_include_or_search
	search_for_matching_children(starting_node)
	update_theme_customs(current_loaded_theme)

## Recursive search to find all supported types and add them to arrays. ONLY call externally if structure changes, as this isnt efficient to keep rerunning
func search_for_matching_children(starting_node: Node) -> void:
	for child: Node in starting_node.get_children():
		
		if child in _nodes_to_not_include_or_search:
			continue #skip
		
		if child is TextureButton:
			_texture_buttons.append(child)
		
		#if child is DetailedPanelContainerButton:
		#	_detailed_container_buttons.append(child)
		
		
		search_for_matching_children(child) # Recusrion!

## Applies custom data changes from new theme to all cached references
func update_theme_customs(updated_theme: Theme) -> void:
	var size_x: int = 0
	var size_y: int = 0
	var box_normal: StyleBoxFlat
	var box_pressed: StyleBoxFlat
	var box_hover: StyleBoxFlat

	# TextureButton
	if updated_theme.has_constant("size_x", "TextureButton") && updated_theme.has_constant("size_y", "TextureButton"):
		size_x = updated_theme.get_constant("size_x", "TextureButton")
		size_y = updated_theme.get_constant("size_y", "TextureButton")
		for texture_button: TextureButton in _texture_buttons:
			if texture_button == null:
				continue
			texture_button.custom_minimum_size = Vector2i(size_x, size_y)
	else:
		push_error("THEME: Loaded theme file is missing size_x and/or size_y for TextureButton. There will be sizing issues!")
	
	##DetailedPanelContainerButton (has a script on its own so we can let that handle it.
	#for panel: DetailedPanelContainerButton in _detailed_container_buttons:
	#	panel.external_update_theme_params()
