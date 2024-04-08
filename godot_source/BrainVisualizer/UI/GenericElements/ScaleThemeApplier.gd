extends RefCounted
class_name ScaleThemeApplier
## Iterates over UI nodes (including recursively through children), and updates custom elements from theme automatically

var _nodes_to_not_include_or_search: Array[Node] ## when searching and this node is encountered, stop. We may have custom things here instead
var _texture_buttons: Array[TextureButton] = []
var _PanelContainerButtons: Array[PanelContainerButton] = []

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
		
		elif child is PanelContainerButton:
			_PanelContainerButtons.append(child)
		
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
	
	# PanelContainerButton
	if updated_theme.has_stylebox("panel", "PanelContainerButton") and updated_theme.has_stylebox("panel_hover", "PanelContainerButton") and updated_theme.has_stylebox("panel_pressed", "PanelContainerButton"):
		box_normal = updated_theme.get_stylebox("panel", "PanelContainerButton")
		box_hover = updated_theme.get_stylebox("panel_hover", "PanelContainerButton")
		box_pressed = updated_theme.get_stylebox("panel_pressed", "PanelContainerButton")
		for container_button: PanelContainerButton in _PanelContainerButtons:
			if container_button == null:
				continue
			container_button.update_theme(box_normal, box_hover, box_pressed)
	else:
		push_error("THEME: Loaded theme file is missing styleboxes for PanelContainerButton. There will be coloring issues!")

