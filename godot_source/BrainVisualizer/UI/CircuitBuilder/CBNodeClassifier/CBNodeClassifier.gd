extends CBNodeConnectableBase
class_name CBNodeClassifier
## Region-like Circuit Builder node for a [GenomeClassifier].
## Not a [CBNodeRegion] and not a [CBNodeCorticalArea]. Internals stay hidden;
## inbound mappings land on this node's input terminals.

const CLASSIFIER_BOX_COLOR: Color = Color(0.12, 0.62, 0.64)

var representing_classifier: GenomeClassifier:
	get: return _representing_classifier

var _representing_classifier: GenomeClassifier


## Called by CB right after instantiation.
func setup(classifier_ref: GenomeClassifier) -> void:
	var input_path: NodePath = NodePath("Inputs")
	var output_path: NodePath = NodePath("Outputs")
	var recursive_path: NodePath = NodePath("")
	setup_base(recursive_path, input_path, output_path)

	_representing_classifier = classifier_ref
	_setup_node_color()
	CACHE_updated_classifier_name(_representing_classifier.friendly_name)
	CACHE_updated_2D_position(_representing_classifier.coordinates_2D)
	name = classifier_ref.classifier_id

	_representing_classifier.friendly_name_updated.connect(CACHE_updated_classifier_name)
	_representing_classifier.coordinates_2D_updated.connect(CACHE_updated_2D_position)
	_representing_classifier.UI_highlighted_state_updated.connect(func(is_highlighted: bool): if is_highlighted != selected: selected = is_highlighted)


func CACHE_updated_classifier_name(name_text: StringName) -> void:
	title = name_text


func CACHE_updated_2D_position(new_position: Vector2i) -> void:
	apply_model_position_offset(new_position)


func _on_single_left_click() -> void:
	if _dragged:
		return
	var is_multi := Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_META) or Input.is_physical_key_pressed(KEY_SHIFT)
	if not is_multi:
		var cb_parent = get_parent()
		if cb_parent is CircuitBuilder:
			(cb_parent as CircuitBuilder)._select_single_graph_element(self)
		BV.UI.selection_system.clear_all_highlighted()
	BV.UI.selection_system.add_to_highlighted(_representing_classifier)
	BV.UI.selection_system.select_objects(SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_CLICK)


func _setup_node_color() -> void:
	var titlebar_box: StyleBoxFlat = StyleBoxFlat.new()
	titlebar_box.bg_color = CLASSIFIER_BOX_COLOR
	add_theme_stylebox_override("titlebar", titlebar_box)
	var panel_box: StyleBoxFlat = StyleBoxFlat.new()
	panel_box.bg_color = CLASSIFIER_BOX_COLOR
	add_theme_stylebox_override("panel", panel_box)
