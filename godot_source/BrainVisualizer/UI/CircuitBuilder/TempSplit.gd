extends SplitContainer
class_name TempSplit

enum STATES {
	CB_FULL,
	CB_CLOSED,
	CB_HORIZONTAL,
	CB_VERTICAL
}

var _current_state: STATES = STATES.CB_CLOSED

func _ready() -> void:
	split_offset = BV.UI.screen_size.x * .6
	BV.UI.screen_size_changed.connect(_screen_size_change)
	_screen_size_change(BV.UI.screen_size)

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
			#split_offset = int(BV.UI.screen_size.y / 2.0)
			collapsed = false
		STATES.CB_VERTICAL:
			visible = true
			dragger_visibility =SplitContainer.DRAGGER_VISIBLE
			vertical = true
			#split_offset = int(BV.UI.screen_size.x / 2.0)
			collapsed = false

func _screen_size_change(new_screen_size: Vector2) -> void:
	var old_size: Vector2 = size
	var ratio: float
	size = new_screen_size
	match(_current_state):
		STATES.CB_HORIZONTAL:
			ratio = float(split_offset) / old_size.x
			split_offset = int(ratio * size.x)
		STATES.CB_VERTICAL:
			ratio = float(split_offset) / old_size.y
			split_offset = int(ratio * size.y)
