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
	add_child(new_CB)
	set_tab_icon(get_tab_idx_from_control(new_CB) , ICON_CB)
	BV.UI.root_multi_tab_view.CB_register(new_CB as CircuitBuilder)

func add_existing_tab(view: Control) -> void:
	if view is CircuitBuilder:
		add_child(view)
		set_tab_icon(get_tab_idx_from_control(view) , ICON_CB)
		BV.UI.root_multi_tab_view.CB_register(view as CircuitBuilder)
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

