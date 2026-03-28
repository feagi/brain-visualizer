extends SplitContainer
class_name TempSplit

enum STATES {
	CB_FULL,
	CB_CLOSED,
	CB_HORIZONTAL,
	CB_VERTICAL
}

var _current_state: STATES = STATES.CB_CLOSED

## Get the current split view state
var current_state: STATES:
	get: return _current_state
var initial_y_offset: int

## Upper bound on how many icon tabs we size for when opening side-by-side split (see UITabContainer tab metrics).
const _ESTIMATE_MAX_VISIBLE_TABS: int = 10

func _ready() -> void:
	initial_y_offset = position.y
	# Initial value; CB_HORIZONTAL/CB_VERTICAL apply layout-aware offsets in set_view().
	split_offset = int(BV.UI.screen_size.x * 0.75)
	BV.UI.screen_size_changed.connect(_screen_size_change)
	_screen_size_change(BV.UI.screen_size)


## Minimum width for the UIView (second child) so TabBar icon tabs stay visible in side-by-side split.
## Kept in sync with UITabContainer TAB_*_BASE_PX constants.
func _min_secondary_width_for_tab_bar() -> int:
	var scale: float = BV.UI.loaded_theme_scale.x if BV.UI != null else 1.0
	var per_tab: float = (
		float(
			UITabContainer.TAB_ICON_MAX_WIDTH_BASE_PX
			+ UITabContainer.TAB_H_SEPARATION_BASE_PX
			+ UITabContainer.TAB_LEFT_PADDING_BASE_PX
		) + 8.0
	) * scale
	return int(round(per_tab * float(_ESTIMATE_MAX_VISIBLE_TABS) + 40.0))


## Side-by-side split: cap first-child width so the main UIView keeps enough width for the tab icon row.
func _apply_horizontal_split_offset() -> void:
	var w: int = int(size.x)
	if w <= 0:
		w = int(BV.UI.screen_size.x) if BV.UI != null else 1280
	var sep: int = 20
	if theme != null:
		sep = int(get_theme_constant("separation", "SplitContainer"))
	var min_right: int = _min_secondary_width_for_tab_bar()
	var max_first: int = maxi(0, w - sep - min_right)
	var desired: int = int(round(float(w) * 0.45))
	split_offset = clampi(desired, 0, max_first)


func _apply_vertical_split_offset() -> void:
	call_deferred("_deferred_apply_vertical_split_offset")


func _deferred_apply_vertical_split_offset() -> void:
	var h: int = int(size.y)
	if h <= 0:
		h = int(maxf(1.0, BV.UI.screen_size.y - float(initial_y_offset))) if BV.UI != null else 600
	split_offset = maxi(1, int(round(float(h) * 0.5)))


func set_view(state: STATES) -> void:
	_current_state = state
	match state:
		STATES.CB_CLOSED:
			visible = false
		STATES.CB_FULL:
			visible = true
			dragger_visibility =SplitContainer.DRAGGER_HIDDEN_COLLAPSED
			#split_offset = 0
			collapsed = true
		STATES.CB_HORIZONTAL:
			visible = true
			dragger_visibility =SplitContainer.DRAGGER_VISIBLE
			vertical = false
			_apply_horizontal_split_offset()
			collapsed = false
		STATES.CB_VERTICAL:
			visible = true
			dragger_visibility =SplitContainer.DRAGGER_VISIBLE
			vertical = true
			_apply_vertical_split_offset()
			collapsed = false

## Close the split view and return to single screen.
func close_split_view() -> void:
	set_view(STATES.CB_CLOSED)

func _screen_size_change(new_screen_size: Vector2) -> void:
	var old_size: Vector2 = size
	var ratio: float
	size = new_screen_size - Vector2(0,initial_y_offset)
	match(_current_state):
		STATES.CB_HORIZONTAL:
			_apply_horizontal_split_offset()
		STATES.CB_VERTICAL:
			ratio = float(split_offset) / old_size.y
			split_offset = int(ratio * size.y)
