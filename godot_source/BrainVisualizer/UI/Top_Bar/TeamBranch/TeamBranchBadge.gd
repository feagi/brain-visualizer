extends PanelContainer
class_name TeamBranchBadge
## Persistent top bar badge: "Collaborative genome" vs "Independent fork".
##
## Driven by the DesktopTeamEvents autoload (desktop is the source of truth).
## Hidden unless a team experiment is running. Live teammate changes to the
## collaborative genome are shown through the notification system.

const COLLABORATIVE_COLOR: Color = Color(0.25, 0.55, 0.95)
const FORK_COLOR: Color = Color(0.8, 0.45, 0.9)
const NEUTRAL_COLOR: Color = Color(0.6, 0.6, 0.6)

var _label: Label


func _ready() -> void:
	name = "TeamBranchBadge"
	mouse_filter = Control.MOUSE_FILTER_PASS
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	visible = false
	var events: Node = get_node_or_null("/root/DesktopTeamEvents")
	if events == null:
		return
	events.team_brain_state_changed.connect(_on_state_changed)
	events.team_main_branch_event.connect(_on_main_branch_event)
	_on_state_changed(events.latest_state)


func _on_state_changed(state: Dictionary) -> void:
	if not TeamBranchText.is_team_state(state):
		visible = false
		return
	_label.text = TeamBranchText.badge_label(state)
	tooltip_text = TeamBranchText.badge_tooltip(state)
	var color: Color = NEUTRAL_COLOR
	match TeamBranchText.mode_of(state):
		TeamBranchText.MODE_COLLABORATIVE:
			color = COLLABORATIVE_COLOR
		TeamBranchText.MODE_FORK:
			color = FORK_COLOR
	_label.add_theme_color_override("font_color", color)
	visible = true


func _on_main_branch_event(event: Dictionary) -> void:
	if BV.UI == null or BV.UI.notification_system == null:
		return
	BV.UI.notification_system.add_notification(
		TeamBranchText.event_text(event), NotificationSystemNotification.NOTIFICATION_TYPE.INFO
	)
