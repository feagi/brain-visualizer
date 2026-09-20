extends RefCounted
class_name UI_BrainMonitor_SceneLabel3D
## Shared Label3D setup for BV 3D scene names.
## One MSDF font and modest font_size; role-specific pixel_size keeps prior visual scale.
## Region titles keep fixed_size; area names and plate tags do not.


enum ROLE {
	AREA_NAME,
	REGION_TITLE,
	PLATE_TAG,
}

const FONT_SIZE: int = 48
const MSDF_PIXEL_RANGE: int = 8
const OUTLINE_SIZE: int = 4
const OUTLINE_MODULATE: Color = Color.BLACK

## Previous constructors used font_size * pixel_size for on-screen / world size.
const AREA_NAME_VISUAL_SCALE: float = 512.0 * 0.005
const REGION_TITLE_VISUAL_SCALE: float = 32.0 * 0.001
const PLATE_TAG_VISUAL_SCALE: float = 18.0 * 0.002

const AREA_NAME_PIXEL_SIZE: float = AREA_NAME_VISUAL_SCALE / float(FONT_SIZE)
const REGION_TITLE_PIXEL_SIZE: float = REGION_TITLE_VISUAL_SCALE / float(FONT_SIZE)
const PLATE_TAG_PIXEL_SIZE: float = PLATE_TAG_VISUAL_SCALE / float(FONT_SIZE)

const AREA_NAME_RENDER_PRIORITY: int = 1
const REGION_TITLE_RENDER_PRIORITY: int = 10
const PLATE_TAG_RENDER_PRIORITY: int = 11
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
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	match role:
		ROLE.AREA_NAME:
			label.fixed_size = false
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


static func pixel_size_for_role(role: ROLE) -> float:
	match role:
		ROLE.AREA_NAME:
			return AREA_NAME_PIXEL_SIZE
		ROLE.REGION_TITLE:
			return REGION_TITLE_PIXEL_SIZE
		ROLE.PLATE_TAG:
			return PLATE_TAG_PIXEL_SIZE
	push_error("UI_BrainMonitor_SceneLabel3D.pixel_size_for_role: unknown role %s" % role)
	return AREA_NAME_PIXEL_SIZE


static func uses_fixed_size(role: ROLE) -> bool:
	return role == ROLE.REGION_TITLE
