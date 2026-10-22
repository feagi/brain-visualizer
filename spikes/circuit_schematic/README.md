# Circuit Schematic: Phase 0 spike

Throwaway benchmark for [docs/CIRCUIT_SCHEMATIC_VIEW_DESIGN.md](../../docs/CIRCUIT_SCHEMATIC_VIEW_DESIGN.md).
It is a standalone Godot project so BV autoloads don't run, and it uses BV's renderer
(`gl_compatibility`). Results are recorded in §11 of the design doc.

| File | What it does |
|---|---|
| `make_stress_genome.gd` | Seeded synthetic brain: region tree, areas, mappings (JSON, not a FEAGI genome) |
| `schematic_model.gd` | Plain-data tree, nested shelf layout, open/close rule, line grouping |
| `box_node.gd` | Area box / region frame as a GraphElement (Panel + Label) |
| `edge_layer.gd` | All lines in one `_draw()` (`multiline` or `polyline`) |
| `cb_style_line.gd` | Today's CB cost per connection, for comparison |
| `spike.gd`, `spike_runner.gd` | Opens every region, builds boxes 40 per frame, pans/zooms, writes JSON + screenshots |

Generate a description file:

```bash
"/Applications/Godot 4.7.app/Contents/MacOS/Godot" --headless --path spikes/circuit_schematic -s res://make_stress_genome.gd -- --regions 60 --depth 5 --areas 600 --mappings 3000 --out /tmp/stress.json
```

Run one benchmark (opens a 1920×1080 window for about 25 s; vsync is off):

```bash
"/Applications/Godot 4.7.app/Contents/MacOS/Godot" --path spikes/circuit_schematic -s res://spike.gd -- --regions 60 --depth 5 --areas 600 --mappings 3000 --lines multiline --label stress --out /tmp/spike
```

`--lines` takes `multiline` (one draw call per colour), `polyline` (one per line), `cb` (CB-style
nodes per line) or `none`.
