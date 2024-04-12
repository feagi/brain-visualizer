extends RefCounted
class_name ScaleThemeApplier
## Iterates over UI nodes (including recursively through children), and updates custom elements from theme automatically


var _nodes_to_not_include_or_search: Array[Node] ## when searching and this node is encountered, stop. We may have custom things here instead
var _texture_buttons: Array[TextureButton] = []
var _text_buttons: Array[Button] = []
var _texture_rects: Array[TextureRect] = []
var _line_edits: Array[LineEdit] # applies for [FloatInput], [IntInput], and the other custom input types
#var _detailed_container_buttons: Array[DetailedPanelContainerButton] = []

## Call this when all children were added to the tree so the reference arrays can be built
func setup(starting_node: Node, nodes_to_not_include_or_search: Array[Node], current_loaded_theme: Theme) -> void:
	_nodes_to_not_include_or_search = nodes_to_not_include_or_search
	search_for_matching_children(starting_node)
	update_theme_customs(current_loaded_theme)

## Recursive search to find all supported types and add them to arrays. ONLY call externally if structure changes, as this isnt efficient to keep rerunning
func search_for_matching_children(starting_node: Node) -> void:
	for child: Node in starting_node.get_children():
		#NOTE: When changing this, verify things like the top bar image drop down work as expected
		
		if child in _nodes_to_not_include_or_search:
			continue #skip
		
		if child is TitleBar:
			continue # Has its own sizing system
		
		if child is BooleanIndicator:
			continue # Has its own sizing system
		
		elif child is TextureButton:
			_texture_buttons.append(child)
		
		elif child is Button:
			_text_buttons.append(child)
		
		elif child is TextureRect:
			_texture_rects.append(child)
		
		elif child is LineEdit:
			_line_edits.append(child)

		
		
		search_for_matching_children(child) # Recursion!

## Applies custom data changes from new theme to all cached references
func update_theme_customs(updated_theme: Theme) -> void:
	# TextureButton
	for tb: TextureButton in _texture_buttons:
		update_minimum_size(tb)
	
	for but: Button in _text_buttons:
		update_minimum_size(but)

## Uses size_x and size_y 
func update_minimum_size(control: Control) -> void:
	var size_x: int = 32 # default texture size
	var size_y: int = 32
	
	if control.has_theme_constant("size_x"):
		size_x = control.get_theme_constant("size_x")
	else:
		push_error("THEME: Loaded theme file is missing size_x for %s. There will be sizing issues!" % control.name)
	if control.has_theme_constant("size_y"):
		size_y = control.get_theme_constant("size_y")
	else:
		push_error("THEME: Loaded theme file is missing size_y for %s. There will be sizing issues!" % control.name)
	
	control.custom_minimum_size = Vector2i(size_x, size_y)
	
