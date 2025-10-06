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

func _init():
	# Defaults are set via @export annotations above
	pass

## Get warning threshold - there are NO hard limits!
## This just returns when to warn the user about potential performance impacts
func get_warning_threshold() -> int:
	return performance_warning_threshold
