extends RefCounted
class_name UI_BrainMonitor_SceneLabel3D
## Shared Label3D setup for BV 3D scene names.
## One MSDF font and modest font_size; role-specific pixel_size sets the size.
## Area names and region titles use fixed_size so a far title stays the same on-screen size. Plate tags do not.
## Area names are capped at the top-bar Circuits / Inputs / Outputs font size.


enum ROLE {
	AREA_NAME,
	REGION_TITLE,
	PLATE_TAG,
	REGION_DESCRIPTION,
}

const FONT_SIZE: int = 48
const MSDF_PIXEL_RANGE: int = 8
const OUTLINE_SIZE: int = 4
const OUTLINE_MODULATE: Color = Color.BLACK

## 1x Circuits / Inputs / Outputs label ([code]Label_Header[/code] in [code]1-DARK.tres[/code]).
const TOP_BAR_HEADER_FONT_PX: float = 20.0
## Frustum the reference area-name scale is matched against. Live views recompute from the real header, FOV, and viewport.
const REFERENCE_VERTICAL_FOV_DEG: float = 75.0
const REFERENCE_VIEWPORT_HEIGHT_PX: float = 1080.0

## Screen-constant title height. Godot fixed_size draws this world height as if the camera were 1 unit away,
## so the title stays readable when the area is far.
## Region titles keep the legacy 32px * 0.001 height. Area names match the top-bar header on the reference frustum.
const REGION_TITLE_VISUAL_SCALE: float = 32.0 * 0.001
const AREA_NAME_VISUAL_SCALE: float = 0.028419518
const PLATE_TAG_VISUAL_SCALE: float = 18.0 * 0.002
const REGION_DESCRIPTION_VISUAL_SCALE: float = 24.0 * 0.001
const REGION_DESCRIPTION_WRAP_WIDTH_PX: float = 960.0

const AREA_NAME_PIXEL_SIZE: float = AREA_NAME_VISUAL_SCALE / float(FONT_SIZE)
const REGION_TITLE_PIXEL_SIZE: float = REGION_TITLE_VISUAL_SCALE / float(FONT_SIZE)
const PLATE_TAG_PIXEL_SIZE: float = PLATE_TAG_VISUAL_SCALE / float(FONT_SIZE)
const REGION_DESCRIPTION_PIXEL_SIZE: float = REGION_DESCRIPTION_VISUAL_SCALE / float(FONT_SIZE)

const AREA_NAME_RENDER_PRIORITY: int = 1
const REGION_TITLE_RENDER_PRIORITY: int = 10
const PLATE_TAG_RENDER_PRIORITY: int = 11
const REGION_DESCRIPTION_RENDER_PRIORITY: int = 12
const PLATE_TAG_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.9)

static var _msdf_font: Font = null


## Creates a Label3D already styled for [param role].
static func create(role: ROLE, node_name: StringName) -> Label3D:
	var label := Label3D.new()
	label.name = String(node_name)
	apply(label, role)
	return label


## Applies the shared MSDF/outline setup and the role-specific size flags.
static func apply(label: Label3D, role: ROLE) -> void:
	label.font = scene_font()
	label.font_size = FONT_SIZE
	label.pixel_size = pixel_size_for_role(role)
	label.outline_size = OUTLINE_SIZE
	label.outline_modulate = OUTLINE_MODULATE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match role:
		ROLE.AREA_NAME:
			label.fixed_size = true
			label.no_depth_test = false
			apply_render_priority(label, AREA_NAME_RENDER_PRIORITY)
			label.modulate = Color.WHITE
		ROLE.REGION_TITLE:
			label.fixed_size = true
			label.no_depth_test = true
			apply_render_priority(label, REGION_TITLE_RENDER_PRIORITY)
			label.modulate = Color.WHITE
		ROLE.PLATE_TAG:
			label.fixed_size = false
			label.no_depth_test = false
			apply_render_priority(label, PLATE_TAG_RENDER_PRIORITY)
			label.modulate = PLATE_TAG_MODULATE
		ROLE.REGION_DESCRIPTION:
			label.fixed_size = true
			label.no_depth_test = true
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.width = REGION_DESCRIPTION_WRAP_WIDTH_PX
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			apply_render_priority(label, REGION_DESCRIPTION_RENDER_PRIORITY)
			label.modulate = Color.WHITE


## Text must sort in front of its outline. Equal priorities make the black outline cover the fill.
static func apply_render_priority(label: Label3D, text_priority: int) -> void:
	label.render_priority = text_priority
	label.outline_render_priority = text_priority - 1


## MSDF FontFile derived from Godot's bundled theme font. Cached per process.
static func scene_font() -> Font:
	if _msdf_font != null:
		return _msdf_font
	var base_font: Font = ThemeDB.fallback_font
	if base_font is FontFile:
		var font_file := (base_font as FontFile).duplicate() as FontFile
		font_file.multichannel_signed_distance_field = true
		font_file.msdf_pixel_range = MSDF_PIXEL_RANGE
		font_file.msdf_size = FONT_SIZE
		_msdf_font = font_file
		return _msdf_font
	push_error("UI_BrainMonitor_SceneLabel3D requires ThemeDB.fallback_font to be a FontFile for MSDF")
	return base_font


## Vertical FOV in degrees. [param camera_fov_degrees] is vertical when [param keep_height] is true.
static func vertical_fov_degrees(camera_fov_degrees: float, keep_height: bool, aspect: float) -> float:
	if keep_height or aspect <= 0.001 or camera_fov_degrees <= 0.0:
		return camera_fov_degrees
	var half_vertical: float = atan(tan(deg_to_rad(camera_fov_degrees) * 0.5) / aspect)
	return rad_to_deg(half_vertical * 2.0)


## World em height of a fixed-size Label3D that occupies [param screen_px] on a KEEP_HEIGHT-equivalent frustum.
## Godot draws fixed_size as if the label were 1 unit from the camera, then scales by depth.
static func visual_scale_for_screen_px(screen_px: float, vertical_fov_degrees: float, viewport_height_px: float) -> float:
	if screen_px <= 0.0 or viewport_height_px <= 1.0 or vertical_fov_degrees <= 0.0:
		return 0.0
	var visible_height: float = 2.0 * tan(deg_to_rad(vertical_fov_degrees) * 0.5)
	if visible_height <= 0.0:
		return 0.0
	return screen_px * visible_height / viewport_height_px


## On-screen em height of a fixed-size label whose unit-distance height is [param visual_scale].
static func screen_px_for_visual_scale(visual_scale: float, vertical_fov_degrees: float, viewport_height_px: float) -> float:
	if visual_scale <= 0.0 or viewport_height_px <= 1.0 or vertical_fov_degrees <= 0.0:
		return 0.0
	var visible_height: float = 2.0 * tan(deg_to_rad(vertical_fov_degrees) * 0.5)
	if visible_height <= 0.0:
		return 0.0
	return visual_scale * viewport_height_px / visible_height


static func pixel_size_for_role(role: ROLE) -> float:
	match role:
		ROLE.AREA_NAME:
			return AREA_NAME_PIXEL_SIZE
		ROLE.REGION_TITLE:
			return REGION_TITLE_PIXEL_SIZE
		ROLE.PLATE_TAG:
			return PLATE_TAG_PIXEL_SIZE
		ROLE.REGION_DESCRIPTION:
			return REGION_DESCRIPTION_PIXEL_SIZE
	push_error("UI_BrainMonitor_SceneLabel3D.pixel_size_for_role: unknown role %s" % role)
	return AREA_NAME_PIXEL_SIZE


static func uses_fixed_size(role: ROLE) -> bool:
	return role == ROLE.AREA_NAME or role == ROLE.REGION_TITLE or role == ROLE.REGION_DESCRIPTION
