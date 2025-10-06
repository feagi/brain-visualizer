extends Resource
class_name VisualizationSettings
## Configuration for brain visualization rendering performance
##
## This resource defines performance limits for neuron visualization
## to balance visual fidelity with frame rate.

## Maximum neurons to render per cortical area
## 
## With Rust acceleration:
##   - 100,000: Excellent performance (recommended)
##   - 500,000: Good performance on modern hardware
##   - 1,000,000: Possible on high-end systems
## 
## Without Rust acceleration (GDScript fallback):
##   - 10,000: Maximum practical limit
@export var max_neurons_per_area: int = 100000

## Enable Rust acceleration if available
## Provides 40-50x performance improvement over GDScript
@export var use_rust_acceleration: bool = true

## Enable performance monitoring logs
## Shows processing time and neuron counts
@export var enable_performance_logs: bool = true

## Frame rate warning threshold
## Warn if FPS drops below this value
@export var fps_warning_threshold: int = 30

## Auto-adjust neuron limit based on performance
## Experimental: automatically reduce limit if FPS drops
@export var auto_adjust_performance: bool = false

func _init():
	# Defaults are set via @export annotations above
	pass

## Get effective neuron limit based on system capabilities
func get_effective_limit() -> int:
	if use_rust_acceleration and ClassDB.class_exists("FeagiDataDeserializer"):
		return max_neurons_per_area
	else:
		# Fallback to GDScript limit
		return min(max_neurons_per_area, 10000)

## Check if we're using Rust acceleration
func is_rust_available() -> bool:
	return use_rust_acceleration and ClassDB.class_exists("FeagiDataDeserializer")
