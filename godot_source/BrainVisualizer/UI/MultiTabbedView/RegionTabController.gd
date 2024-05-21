extends TabContainer
class_name RegionTabController

const PREFAB_CIRCUITBUILDER: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.tscn")
const ICON_CB: Texture2D = preload("res://BrainVisualizer/UI/GenericResources/ButtonIcons/Circuit_Builder_S.png")

signal all_tabs_removed() ## Emitted when all tabs are removed, this container should be destroyed

var _tab_bar: TabBar

func _ready():
	_tab_bar = get_tab_bar()
	tab_changed.connect(_on_top_tab_change)

func add_CB_tab(region: BrainRegion) -> void:
	var new_CB: CircuitBuilder = PREFAB_CIRCUITBUILDER.instantiate()
	new_CB.setup(region)
	_add_existing_circuit_builder_as_tab(new_CB)

func add_existing_tab(view: Control) -> void:
	if view is CircuitBuilder:
		_add_existing_circuit_builder_as_tab(view as CircuitBuilder)
		return
	push_error("UI: Unknown Control attempted to be added to tab! Skipping!")

## Get all tabs (eeither CB or BV instances)
func get_tabs() -> Array[Control]:
	var output: Array[Control] = []
	output.assign(get_children())
	return output

func is_current_top_view_root_region() -> bool:
	var top_control = get_current_tab_control()
	if top_control is CircuitBuilder:
		return (top_control as CircuitBuilder).representing_region.is_root_region()
	push_error("UI: Unknown top control!")
	return false

func _on_top_tab_change(_tab_index: int) -> void:
	if is_current_top_view_root_region():
		_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	else:
		_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY

func _add_existing_circuit_builder_as_tab(cb: CircuitBuilder) -> void:
	add_child(cb)
	var tab_idx: int = get_tab_idx_from_control(cb)
	set_tab_icon(tab_idx , ICON_CB)
	BV.UI.root_multi_tab_view.CB_register(cb)
	cb.user_request_viewing_subregion.connect(_user_request_create_circuit_builder_tab)
	current_tab = tab_idx

func _user_request_create_circuit_builder_tab(region: BrainRegion) -> void:
	if BV.UI.root_multi_tab_view.is_existing_CB_of_region(region):
		# A CB already exists with this region, bring it up
		#TODO bring up tab in whatever CB to view
		return
	add_CB_tab(region)
