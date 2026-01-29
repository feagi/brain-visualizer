extends EditAbstractParameter
class_name EditOptionalParameter
## Editor for OptionalParameter with enable toggle.

var _enabled_toggle: CheckBox
var _inner_container: VBoxContainer
var _inner_editor: EditAbstractParameter

## Set up the UI from the given OptionalParameter.
func setup(parameter: OptionalParameter) -> void:
	base_setup(parameter)
	_enabled_toggle = $Enabled
	_inner_container = $InnerContainer
	_enabled_toggle.button_pressed = parameter.enabled
	_enabled_toggle.toggled.connect(_on_toggled)
	_rebuild_inner_editor(parameter)

## Export the edited OptionalParameter.
func export() -> AbstractParameter:
	var parameter: OptionalParameter = super()
	parameter.enabled = _enabled_toggle.button_pressed
	if parameter.enabled and _inner_editor != null:
		parameter.inner = _inner_editor.export()
	return parameter

## Handle toggle to show/hide nested editor.
func _on_toggled(pressed: bool) -> void:
	_inner_container.visible = pressed

## Rebuild the nested editor with the provided parameter.
func _rebuild_inner_editor(parameter: OptionalParameter) -> void:
	for child in _inner_container.get_children():
		child.queue_free()
	_inner_editor = null
	if parameter.inner == null:
		_inner_container.visible = false
		return
	_inner_container.visible = parameter.enabled
	_inner_editor = EditAbstractParameter.spawn_and_add_parameter_editor(parameter.inner, _inner_container)
