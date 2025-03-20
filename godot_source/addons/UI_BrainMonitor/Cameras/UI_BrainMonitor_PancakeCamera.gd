extends Camera3D
class_name UI_BrainMonitor_PancakeCamera
## Camera interface for Brain Monitor on a flat monitor (non-vr)

const MIN_DRAG_SQUARE_DISTANCE: float = 2.0
const RAYCAST_LENGTH: float = 10000

const FPS_BOOST_MULTIPLIER : float = 3.0
const FPS_SPEED_SCALE : float = 1.17
const FPS_DEFAULT_SPEED: float = 5
const FPS_MAX_SPEED: float = 1000
const FPS_MIN_SPEED: float = 0.2

enum MODE {
	FPS, # Originally based off the MIT work of Marc Nahr: https://github.com/MarcPhi/godot-free-look-camera (TODO give proper credit on github)
	TANK, # You are stuck on a touch pad. haha!
	ANIMATION # currently being controlled by animation
}

signal BM_input_events(input_events: Array[UI_BrainMonitor_InputEvent_Abstract]) # Array can only be a length of 1 since there is only a single mouse cursor!

var movement_mode: MODE = MODE.FPS
var allow_user_control: bool = true # set to false externally if user interacting with other UI element
var FPS_sensitivity : float = 3

var _parent_viewport: Viewport
var _initial_position: Vector3
var _initial_euler_rotation: Vector3
var _fps_velocity: float = FPS_DEFAULT_SPEED

var _mouse_position_when_any_click_started: Vector2 = Vector2(-1, -1)
var _click_down_count: int = 0



func _ready() -> void:
	_parent_viewport = get_viewport()
	_initial_position = position
	_initial_euler_rotation = rotation_degrees


func _unhandled_input(event: InputEvent) -> void:
	if !current:
		return
	
	if !allow_user_control:
		return
	
	if event is InputEventMouse:
		
		# Camera Movement
		match(movement_mode):
			MODE.ANIMATION:
				return
			MODE.FPS:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					if event is InputEventMouseMotion:
						rotation.y -= event.relative.x / 1000 * FPS_sensitivity
						rotation.x -= event.relative.y / 1000 * FPS_sensitivity
						rotation.x = clamp(rotation.x, PI/-2, PI/2)
				if event is InputEventMouseButton:
					match event.button_index:
						MOUSE_BUTTON_RIGHT:
							Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
						MOUSE_BUTTON_WHEEL_UP:
							_fps_velocity = clamp(_fps_velocity * FPS_SPEED_SCALE, FPS_MIN_SPEED, FPS_MAX_SPEED)
						MOUSE_BUTTON_WHEEL_DOWN:
							_fps_velocity = clamp(_fps_velocity / FPS_SPEED_SCALE, FPS_MIN_SPEED, FPS_MAX_SPEED)
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					return # disable sending inputs while looking around
				
			MODE.TANK:
				pass # TODO
		
		
		# BM Interactions
		if event is InputEventMouseButton:
			var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
			var bm_button: UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON = _mouse_button_to_BM_CLICK_BUTTON(mouse_button_event.button_index)
			if bm_button !=  UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.NONE:
				var bm_pressed: bool = mouse_button_event.pressed
				var bm_mouse_position: Vector2 = mouse_button_event.position
				var bm_double_clicked: bool = mouse_button_event.double_click
				
				# Dragging calculation
				var bm_was_dragging: bool = false # we only say we are dragging for the last held mouse button released
				if bm_pressed:
					if _click_down_count == 0:
						# potential to start dragging
						_mouse_position_when_any_click_started = _parent_viewport.get_mouse_position()
					_click_down_count += 1
				else:
					_click_down_count -= 1
					if _click_down_count == 0 && (_parent_viewport.get_mouse_position() - _mouse_position_when_any_click_started).length() > MIN_DRAG_SQUARE_DISTANCE:
						bm_was_dragging = true
				
				var start_pos: Vector3 = project_ray_origin(bm_mouse_position)
				var end_pos: Vector3 = (project_ray_normal(bm_mouse_position) * RAYCAST_LENGTH) + start_pos
				
				var bm_click_event: UI_BrainMonitor_InputEvent_Click = UI_BrainMonitor_InputEvent_Click.new(start_pos, end_pos, bm_pressed, bm_double_clicked, bm_button, bm_was_dragging)
				var bm_click_events: Array[UI_BrainMonitor_InputEvent_Abstract] = [bm_click_event]
				BM_input_events.emit(bm_click_events)
			return

		elif event is InputEventMouseMotion:
			var mouse_motion_event: InputEventMouseMotion = event as InputEventMouseMotion
			var bm_mouse_position: Vector2 = mouse_motion_event.position
			var held_bm_buttons: Array[UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON] = _mouse_bitmask_to_selection_array(mouse_motion_event.button_mask)
			
			var start_pos: Vector3 = project_ray_origin(bm_mouse_position)
			var end_pos: Vector3 = (project_ray_normal(bm_mouse_position) * RAYCAST_LENGTH) + start_pos
			var bm_hover_event: UI_BrainMonitor_InputEvent_Hover = UI_BrainMonitor_InputEvent_Hover.new(start_pos, end_pos, held_bm_buttons)
			var bm_hover_events: Array[UI_BrainMonitor_InputEvent_Abstract] = [bm_hover_event]
			BM_input_events.emit(bm_hover_events)
			return
		

func _process(delta):
	if not current:
		return
		get_world_3d()
	
	match(movement_mode):
		MODE.ANIMATION:
			return
		MODE.FPS:
			var direction = Vector3(
				float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
				float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), 
				float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
			).normalized()
			
			if Input.is_physical_key_pressed(KEY_SHIFT): # boost
				translate(direction * _fps_velocity * delta * FPS_BOOST_MULTIPLIER)
			else:
				translate(direction * _fps_velocity * delta)


func _mouse_button_to_BM_CLICK_BUTTON(mouse_button: MouseButton) -> UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON:
	match(mouse_button):
		MouseButton.MOUSE_BUTTON_NONE:
			return UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.NONE
		MouseButton.MOUSE_BUTTON_LEFT:
			return UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.MAIN
		MouseButton.MOUSE_BUTTON_RIGHT:
			return UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.SECONDARY
		_: # we dont care about scrolling and stuff here
			return UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.NONE


func _mouse_bitmask_to_selection_array(bits: int) -> Array[UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON]:
	var output: Array[UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON] = []
	if bits & 1 == 1:
		output.append(UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.MAIN)
	if ((bits >> 1) & 1) == 1:
		output.append(UI_BrainMonitor_InputEvent_Abstract.CLICK_BUTTON.SECONDARY)
	return output
