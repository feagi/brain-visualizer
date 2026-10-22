extends SceneTree
## Phase 0 benchmark: every region open, every box a GraphElement, all lines drawn.
## Run (windowed, vsync off):
##   godot --path spikes/circuit_schematic -s res://spike.gd -- --regions 60 --depth 5 --areas 600 --mappings 3000 --lines multiline --label stress --out /tmp/spike
## --lines: multiline | polyline | cb | none

const Runner = preload("res://spike_runner.gd")


func _initialize() -> void:
	root.add_child(Runner.new())
