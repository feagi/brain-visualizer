extends ButtonTextureRectScaling
class_name GenomeHistoryButton
## History control in the top bar, immediately before Settings.
##
## One chip on the bottom-right of the icon shows the combined unseen count.
## It stays blue when every change is yours, and turns yellow when anyone else
## has changes. The tooltip lists your count and each other person on their own line.
## Opening the history window clears the chip.

const _CHIP_WIDTH: float = 48.0
const _CHIP_HEIGHT: float = 36.0
const _CHIP_FONT: int = 22
const _OWN_COLOR: Color = Color(0.25, 0.55, 0.95)
const _SHARED_COLOR: Color = Color(0.93, 0.76, 0.18)
const _SHARED_TEXT: Color = Color(0.15, 0.12, 0.05)
const _IDLE_TOOLTIP: String = "Genome change history"

var _chip: PanelContainer
var _chip_label: Label
var _chip_style: StyleBoxFlat


func _ready() -> void:
	super._ready()
	clip_contents = false
	_build_chip()
	pressed.connect(_open_history)
	var events: Node = get_node_or_null("/root/DesktopTeamEvents")
	if events == null:
		return
	events.change_history_changed.connect(_refresh_chip)
	_refresh_chip()
	# TopBar attaches TooltipTrigger after this control is added.
	call_deferred("_refresh_chip")


func _open_history() -> void:
	if BV.WM != null:
		BV.WM.spawn_genome_change_history()


func _build_chip() -> void:
	_chip = PanelContainer.new()
	_chip.name = "ChangeCountChip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.custom_minimum_size = Vector2(_CHIP_WIDTH, _CHIP_HEIGHT)
	_chip.z_index = 2
	_chip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_chip.offset_left = -_CHIP_WIDTH
	_chip.offset_top = -_CHIP_HEIGHT
	_chip.offset_right = 0.0
	_chip.offset_bottom = 0.0
	_chip_style = StyleBoxFlat.new()
	_chip_style.bg_color = _OWN_COLOR
	_chip_style.set_corner_radius_all(16)
	_chip_style.content_margin_left = 6.0
	_chip_style.content_margin_right = 6.0
	_chip_style.content_margin_top = 0.0
	_chip_style.content_margin_bottom = 0.0
	_chip.add_theme_stylebox_override("panel", _chip_style)
	_chip_label = Label.new()
	_chip_label.name = "Count"
	_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip_label.add_theme_font_size_override("font_size", _CHIP_FONT)
	_chip_label.add_theme_color_override("font_color", Color.WHITE)
	_chip.add_child(_chip_label)
	add_child(_chip)
	_chip.visible = false


func _refresh_chip() -> void:
	var events: Node = get_node_or_null("/root/DesktopTeamEvents")
	if events == null or _chip_label == null:
		return
	var total := int(events.unseen_change_count)
	var text := TeamBranchText.change_count_chip(total)
	_chip_label.text = text
	_chip.visible = text != ""
	var shared := TeamBranchText.change_chip_is_yellow(int(events.unseen_other_count))
	_chip_style.bg_color = _SHARED_COLOR if shared else _OWN_COLOR
	_chip_label.add_theme_color_override("font_color", _SHARED_TEXT if shared else Color.WHITE)
	if total <= 0:
		_set_breakdown_tooltip(_IDLE_TOOLTIP)
		return
	_set_breakdown_tooltip(TeamBranchText.change_breakdown_tooltip(events.unseen_by_actor))


func _set_breakdown_tooltip(text: String) -> void:
	var trigger := get_node_or_null("TooltipTrigger")
	if trigger == null:
		return
	trigger.set("show_full_text", true)
	if trigger.has_method("set_tooltip_text"):
		trigger.set_tooltip_text(text)
