extends PanelContainer
class_name MultiTabView
## Holds a split container that can show 2 sets of [TabContainer]s. Secondary window starts disabled

var primary_tabs: TabContainer
var secondary_tabs: TabContainer

var _split_container: SplitContainer


func _ready():
	_split_container = $SplitContainer
	primary_tabs = $SplitContainer/Primary/TabContainer
	secondary_tabs = $SplitContainer/Secondary/TabContainer

func setup_with_1_control_set(primary_control_set: Array[Control]) -> void:
	for control in primary_control_set:
		primary_tabs.add_child(control)
		if control is CircuitBuilder:
			BV.UI.root_multi_tab_view.CB_register(control as CircuitBuilder)
	
	$SplitContainer/Secondary.visible = false


func toggle_secondary_visibility(is_second_visible: bool) -> void:
	_split_container.collapsed = !is_second_visible

func set_split_vertical(should_be_vertical: bool) -> void:
	_split_container.vertical = should_be_vertical

func is_split_vertical() -> bool:
	return _split_container.vertical

