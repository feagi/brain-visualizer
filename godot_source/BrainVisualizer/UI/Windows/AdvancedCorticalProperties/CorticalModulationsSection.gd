extends RefCounted
## Collapsible Modulators panel for cortical area properties.
## Fields are labeled rows inside the shared VerticalCollapsibleHiding body.


const _COLLAPSIBLE_SECTION_SCENE: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Collapsable/VerticalCollapsibleHiding.tscn")
const _NEURO_MODULATOR_TYPES: Array[String] = [
	"neuro.firing_threshold",
	"neuro.leak",
	"neuro.firing_probability",
	"memory.formation",
]
## Matches the dropdown and id fields already used in this window.
const _MODULATOR_FIELD_MIN_SIZE := Vector2(150, 0)
## Same spacer other property sections place above Apply Update.
const _SECTION_APPLY_GAP_PX := 5


## Builds the Modulators panel. Caller places it and connects the action buttons.
static func build() -> VerticalCollapsibleHiding:
	var section := _COLLAPSIBLE_SECTION_SCENE.instantiate() as VerticalCollapsibleHiding
	section.name = "Modulations"
	section.start_open = false
	section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var title := section.get_node("VerticalCollapsible/HBoxContainer/Section_Title") as Label
	title.text = "Modulators"
	title.theme_type_variation = &"Label_Header"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var body_host := section.get_node("VerticalCollapsible/PanelContainer/PutThingsHere") as MarginContainer
	var rows := VBoxContainer.new()
	rows.name = "CorticalPropertiesModulators"
	body_host.add_child(rows)

	var field := LineEdit.new()
	field.name = "ModulatorIds"
	field.placeholder_text = "subscribed instance ids, comma separated"
	field.custom_minimum_size = _MODULATOR_FIELD_MIN_SIZE
	_add_property_row(rows, "Subscriptions", field, "Instance ids of neuromodulators subscribed by this cortical area")

	var type_list := OptionButton.new()
	type_list.name = "ModulatorType"
	type_list.custom_minimum_size = _MODULATOR_FIELD_MIN_SIZE
	for kind in _NEURO_MODULATOR_TYPES:
		type_list.add_item(kind)
	_add_property_row(rows, "Type", type_list, "Neuromodulator type used when listing or creating instances")

	var existing := OptionButton.new()
	existing.name = "ExistingModulator"
	existing.custom_minimum_size = _MODULATOR_FIELD_MIN_SIZE
	existing.add_item("(refresh to list instances)")
	_add_property_row(rows, "Instance", existing, "Existing modulator instance to subscribe")

	rows.add_child(_make_action_button("RefreshInstances", "Refresh instances"))
	rows.add_child(_make_action_button("SubscribeExisting", "Subscribe selected instance"))

	var new_id := LineEdit.new()
	new_id.name = "NewModulatorId"
	new_id.placeholder_text = "new instance id"
	new_id.custom_minimum_size = _MODULATOR_FIELD_MIN_SIZE
	_add_property_row(rows, "New instance", new_id, "Id for a modulator instance to create")

	var magnitude := LineEdit.new()
	magnitude.name = "NewModulatorMagnitude"
	magnitude.placeholder_text = "magnitude percent"
	magnitude.text = "0"
	magnitude.custom_minimum_size = _MODULATOR_FIELD_MIN_SIZE
	_add_property_row(rows, "Magnitude (%)", magnitude, "Magnitude percent for the new modulator instance")

	rows.add_child(_make_action_button("CreateAndSubscribe", "Create instance and subscribe"))
	var gap := Control.new()
	gap.name = "GAP"
	gap.custom_minimum_size = Vector2(0, _SECTION_APPLY_GAP_PX)
	rows.add_child(gap)
	rows.add_child(_make_action_button("ApplySubscriptions", "Apply Update"))
	return section


## Copies the expand arrow size from a theme-scaled sibling toggle.
static func match_expand_button(section: Node, reference: TextureButton) -> void:
	if section == null or reference == null:
		return
	var toggle := section.get_node_or_null("VerticalCollapsible/HBoxContainer/Collapsible_Toggle") as TextureButton
	if toggle == null:
		return
	toggle.custom_minimum_size = reference.custom_minimum_size


static func _add_property_row(rows: VBoxContainer, label_text: String, field: Control, tooltip: String) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % field.name
	var lab := Label.new()
	lab.text = label_text
	lab.tooltip_text = tooltip
	lab.mouse_filter = Control.MOUSE_FILTER_STOP
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	field.tooltip_text = tooltip
	row.add_child(field)
	rows.add_child(row)


static func _make_action_button(node_name: String, label_text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
