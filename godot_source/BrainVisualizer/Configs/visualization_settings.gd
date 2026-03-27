extends Resource
class_name VisualizationSettings
## Configuration for brain visualization rendering performance
##
## This resource defines performance limits for neuron visualization
## to balance visual fidelity with frame rate.

## Performance warning threshold - no hard limits!
## 
## The system will warn when exceeding this many neurons but will still process all of them
## 
## Recommended thresholds:
##   With Rust acceleration (desktop):
##     - 50,000: Conservative (very safe)
##     - 100,000: Balanced (recommended)
##     - 500,000: Aggressive (high-end hardware)
##   With Rust acceleration (WASM/web):
##     - 30,000: Conservative
##     - 50,000: Balanced
##   Without Rust (GDScript fallback):
##     - 10,000: Performance degrades significantly beyond this
@export var performance_warning_threshold: int = 50000

## Enable performance monitoring logs
## Shows processing time and neuron counts
@export var enable_performance_logs: bool = true

## Frame rate warning threshold
## Warn if FPS drops below this value
@export var fps_warning_threshold: int = 30

## Auto-adjust neuron limit based on performance
## Experimental: automatically reduce limit if FPS drops
@export var auto_adjust_performance: bool = false

## When the camera is farther than [camera_distance_far_threshold] (world units) from a cortical
## area, and **x or y** (not z) of that area's dimensions is <= [small_cortical_dimension_threshold],
## the DDA volume uses the same outline pass as mouse hover so tiny areas stay visible.
@export var small_cortical_dimension_threshold: int = 2
@export var camera_distance_far_threshold: float = 65

func _init():
	# Defaults are set via @export annotations above
	pass

## Get warning threshold - there are NO hard limits!
## This just returns when to warn the user about potential performance impacts
func get_warning_threshold() -> int:
	return performance_warning_threshold

## Returns true when [distance_to_cortical_center] is beyond the far threshold and **x or y**
## (z excluded) of [dimensions_3d] is at or below [member small_cortical_dimension_threshold].
func should_apply_far_distance_highlight_for_dimensions(
	dimensions_3d: Vector3i,
	distance_to_cortical_center: float
) -> bool:
	var t: int = small_cortical_dimension_threshold
	var has_small_extent_xy: bool = dimensions_3d.x <= t or dimensions_3d.y <= t
	return has_small_extent_xy and distance_to_cortical_center >= camera_distance_far_threshold
