# Circuit Schematic View: Design

Status: proposal (2026-10-21). Nothing implemented yet.

## 1. Why

The Circuit Builder (CB) shows one brain region per tab. A child region shows up as one closed
node, and the only way into it is a double-click that opens another tab. Nobody can see a whole
circuit at once, so people don't use CB.

The **Circuit Schematic** is a second 2D view that shows the **whole genome in one zoomable
scene**:

- Every brain region is drawn as a box around its contents, and boxes nest inside boxes.
- Zoomed out, regions are solid blocks, and grouped lines between them show how many connections
  each line stands for.
- Zooming in opens the regions under the cursor, so their areas and child regions appear. Zooming
  out closes them again.
- Nodes are created only for what is on screen at a useful size (lazy loading), so a large genome
  doesn't slow the Brain Visualizer down.

Version 1 is **read-only**. Editing stays in CB, and you can get there from the schematic with
"Open in Circuit Builder".

## 2. What exists today (facts this design builds on)

| Fact | Where |
|---|---|
| CB is a `GraphEdit` bound to a single `BrainRegion`. `setup()` adds only that region's direct areas, child regions and classifiers. | `BrainVisualizer/UI/CircuitBuilder/CircuitBuilder.gd:134` |
| A child region is one `CBNodeRegion` with input/output ports, and its insides are never drawn. Double-click sends `user_request_viewing_subregion`, which opens a new tab. | `CBNodeBrainRegion/CBNodeRegion.gd`, `CircuitBuilder.gd:608` |
| The whole region tree, every area and every mapping is already in memory in the local cache. Nothing has to be fetched from FEAGI to draw the full schematic. | `FeagiCore/LocalCache/BrainRegions/BrainRegion.gd` (`contained_*`, `get_all_subregions_recursive`), `Mappings/MappingsCache.gd` (`established_mappings`) |
| Every mapping is a `ConnectionChain` with `source`, `destination` and `total_chain_path`: the full list of regions it passes through. That is what we need to find which visible object a line should end at. | `Mappings/ConnectionChain.gd` |
| Each connection in CB costs a lot of nodes: one `CBLineInterTerminal` (a `GraphElement` with a 20-point `Line2D`, its own copy of the shader material, and a `Button`), plus one terminal node on each end. This is the main reason a "draw everything in CB" approach would be slow. | `CBLine/CBLine.gd`, `CBLine/CBLineInterTerminal.gd`, `CircuitBuilder.gd:365-412` |
| CB's auto-layout (rank by direction, Tarjan cycle grouping, barycenter ordering, input/middle/output columns) is solid, but it works on CB node instances, not on data. | `CircuitBuilder.gd:954-1400` (`_compute_relayout_positions` and helpers) |
| A region whose insides are hidden (classifier circuits) must stay closed. | `GenomeClassifier.region_hides_interior` |
| Selection is shared across views through `BV.UI.selection_system` (`add_to_highlighted`, `highlighted_*` signals). | `BrainVisualizer/UI/SelectionSystem.gd` |
| Tabs are created by `UITabContainer.spawn_CB_of_region` / `show_CB_of_region`. | `UI/UIView/UITabContainer/UITabContainer.gd:74-93` |
| Area type colours (IPU, OPU, memory, custom, core). | `CBNodeCorticalArea/CBNodeCorticalArea.gd:71-75` |
| Line colours (excitatory, inhibitory, episodic, partial). | `CBLine/CBLineInterTerminal.gd:5-9` |

## 3. What the user sees

```
 Zoomed out (whole genome)            Zoom into "Locomotion"              Zoom further into "Gait"
 ┌────────────┐   12   ┌──────────┐   ┌─ Locomotion ───────────────┐     ┌─ Locomotion ───────────────┐
 │ Vision     │───────▶│Locomotion│   │ ┌──────┐  ┌─────────────┐  │     │ ┌──────┐  ┌─ Gait ──────┐  │
 │ 9 areas    │        │ 3 regions│   │ │ cpg  │─▶│ Gait        │  │     │ │ cpg  │─▶│ [phase] [L] │  │
 └────────────┘        └──────────┘   │ └──────┘  │ 6 areas     │  │     │ └──────┘  │ [R] [stance]│  │
        3 │                           │           └─────────────┘  │     │           └─────────────┘  │
          ▼                           └────────────────────────────┘     └────────────────────────────┘
 ┌────────────┐
 │ Motor out  │
 └────────────┘
```

**Opening.** A "Schematic" button in the top bar, plus a "View whole circuit" item on CB's
right-click menu, opens one Schematic tab, using the same tab system as CB and the Brain Monitor.
It starts zoomed to fit the whole genome.

**Detail levels.** Each region on screen is in one of these states:

| State | Shown when | Drawn as |
|---|---|---|
| Closed block | the region is less than about 250 px wide on screen, or off screen | a filled box with the name, area and region counts, and a badge for connections inside it |
| Open, coarse | open, and the areas inside are less than about 60 px wide | a frame with a header; areas as small coloured boxes with no labels; child regions as closed blocks |
| Open, full | open, and the areas inside are 60 px wide or more | a frame; areas show name and type; child regions open or closed by the same rule |

The root region is always open. A region whose insides are hidden (classifier circuit) never opens,
the same as in CB.

**Lines.**

- Every mapping is drawn from the object you can currently see at each of its ends. That is the
  area itself if its region is open, otherwise the outermost closed region that contains it.
- Mappings with the same two visible ends are merged into one line, with a count label and a width
  that grows with the count.
- Lines are coloured as in CB. A merged line with mixed types is neutral grey, and its tooltip
  lists the mix.
- A mapping whose two ends are inside the same closed region isn't drawn. It is counted in that
  block's badge.
- Partial mappings ("hints" from an imported region) are drawn at reduced opacity, as in CB.

**Interaction (v1).**

- Panning and zooming work as in CB. `F` fits the whole genome, and the minimap is on.
- Click an area or region to select it. This goes through `selection_system`, so the Brain Monitor
  and any open CB tabs highlight it too.
- Hovering shows a tooltip: an area's name, type, dimensions and neuron count; a region's
  description and counts; a line's mapping count and rules.
- Double-click a region (block or frame header) to animate the zoom so that region fills the view.
  It opens as a side effect of the zoom.
- Right-click a region and choose "Open in Circuit Builder" to open the existing CB tab for that
  region, which is where editing happens.
- The search box (`BrainObjectsCombo`) flies to the object found and opens every region on its path.
- A breadcrumb in the corner shows the region path at the centre of the view.
- Pinning: right-click a region and choose "Keep open" or "Keep closed" to override the automatic
  rule for that region.

## 4. Architecture

```
UI/CircuitSchematic/
  CircuitSchematic.gd / .tscn   GraphEdit host: zoom/scroll handling, input, tab integration
  SchematicTree.gd              pure data: one SchematicItem per region/area/classifier
  SchematicLayout.gd            nested layout: computes every item's rectangle, no nodes
  SchematicLOD.gd               decides which regions are open; adds and removes nodes in batches
  SchematicEdges.gd             merges mappings into visible lines (pure data)
  SchematicEdgeLayer.gd         draws all lines in one _draw(), plus hit testing
  nodes/CSRegionBlock.*         closed region (GraphElement)
  nodes/CSRegionFrame.*         open region frame + header (GraphElement)
  nodes/CSAreaNode.*            area box, coarse and full looks (GraphElement)
UI/Shared/LayeredGraphLayout.gd pulled out of CircuitBuilder.gd so CB and the schematic share it
```

### 4.1 Data first, nodes second

The key idea is to **work out everything as plain data first, and create nodes only for what is
visible**.

1. `SchematicTree` mirrors the `BrainRegion` tree as plain data objects:
   `{object, parent, children, local_rect, global_rect, depth, state, pinned}`. Building it is a
   walk over data already in memory, with no nodes, so even large genomes take a few milliseconds.
2. `SchematicLayout` gives every item its size and position up front. Because a closed block uses
   exactly the size its open frame will have, **nothing moves when a region opens**. Without that,
   lazy loading would make the picture jump.
3. `SchematicLOD` creates and frees `GraphElement`s to match the view.

### 4.2 Nested layout (computed bottom-up)

For each region, children before parents:

1. Size each child: an area is a fixed box (for example 160 × 56; the coarse look draws smaller
   inside the same space). A child region uses the content size already computed for it, because
   children are done first.
2. Place the children with `LayeredGraphLayout`, the CB algorithm moved out into its own file. Its
   inputs are item ids, item sizes and directed edges between siblings, taken from that region's
   `bridge_chain_links` plus input/output links. It returns positions inside the region.
3. Content size = bounding box of the children + padding + header height. That becomes the
   region's size inside its parent.
4. When the root is done, a top-down pass turns positions inside each region into one set of
   canvas coordinates: `global = parent.global_origin + header_offset + local`.

**Decision: v1 uses auto-layout, not CB's saved 2D positions.** The saved positions assume CB's
small closed region nodes. Once a region is drawn at its real size, it overlaps its neighbours.
Auto-layout is predictable and never overlaps. A later option ("Use Circuit Builder positions") can
place children at their saved positions and push them apart to remove overlaps.

Pulling `LayeredGraphLayout` out of `CircuitBuilder.gd` is a pure refactor: CB passes in its nodes'
ids and sizes and applies the positions it gets back. CB's existing layout behaviour must not change
(checked by a before/after positions test on a fixture genome).

### 4.3 Deciding what is open (lazy loading)

**When it runs.** On `scroll_offset_changed`, and when `zoom` changes (checked once per frame in
`_process`, which is cheap). It runs about 100 ms after the view stops moving, plus once
immediately when a zoom gesture ends.

**Each pass:**

```
visible = view rectangle in canvas coordinates, grown by half a screen on each side
walk(item):
  px = item.global_rect.size.x * zoom
  want_open = pinned_open
           or (px >= OPEN_PX and item.global_rect.intersects(visible) and not hides_interior)
  if item.open and not pinned_open and (px < CLOSE_PX or far outside visible): want_open = false
  set state; if open: walk(children)
```

- `OPEN_PX = 400` and `CLOSE_PX = 250`. Opening and closing at different sizes stops a region
  flickering at the boundary.
- "Far outside" means more than one screen away, so a region you pan just past stays open.
- Area look: full if the area is 60 px or wider on screen, otherwise coarse. **Coarse areas are
  drawn as filled rectangles by the line layer, not as nodes.** Phase 0 showed box count is what
  drives draw calls (2 per box). An area gets a node only when it shows its full look, and only
  about 400 of those fit on a 1080p screen, so the node cap holds without effort.

**Applying the result.** The pass produces a list of items to add and items to remove. Removals
happen at once. Additions are queued, **nearest the view centre first, at most 25 new nodes per
frame**, so opening a large region fills in over a few frames instead of freezing. In Phase 0,
40 per frame peaked at a 24 ms frame; one box costs about 0.06 ms of CPU to create.

**Frames must not jump to the front.** Pressing on any GraphElement emits `raise_request`, and
GraphEdit answers by moving it to the front. Phase 0 confirmed a clicked frame then covers its own
areas. Region frames disconnect GraphEdit from their `raise_request` (or the schematic restores
the frame → line layer → area order right after a raise).

**Reusing nodes.** Freed `CSAreaNode`s and `CSRegionBlock`s go back to a pool and are reused
instead of being freed and created again.

**Node cap.** At most 1,500 live nodes. If opening more would go over the cap, the deepest
candidates stay closed and a small "zoom in for more detail" hint is shown.

### 4.4 Lines

**Line data (`SchematicEdges`).** For each mapping in `mapping_data.established_mappings` and each
partial mapping set:

```
visible_end(obj) = obj if all its ancestor regions are open, else the outermost closed ancestor
key = (visible_end(src), visible_end(dst))
if key.src == key.dst: badge_count[key.src] += 1 ; continue
groups[key].count += 1 ; groups[key].types.add(mapping kind)
```

Finding the outermost closed ancestor walks up the `parent` chain in the tree, which is short.
Lines are rebuilt only after a pass that changed something. A genome with thousands of mappings is
still a sub-millisecond loop.

**Drawing lines (`SchematicEdgeLayer`).** One full-canvas `GraphElement` draws every merged line in
a single `_draw()`. It is not selectable or draggable and ignores the mouse. It sits **above every
region frame and below every area**: child order is frames, then the line layer, then areas. Frames
are opaque, so a layer behind everything hides every line inside a region (found in Phase 0).
New frames are inserted before the layer, and new areas after it.

- Each line is a precomputed Bézier curve. Curves are batched into **one `draw_multiline` per
  colour**; one `draw_polyline` per line was 3× slower in Phase 0.
- Panning and zooming only change the layer's transform, so the points aren't recomputed. Keeping
  line width constant on screen needs a redraw on each zoom change. That CPU work is small
  (0.5–1.5 ms), but at 3,000 lines the zoom sweep dropped from 192 to 69 fps compared with no
  lines. During a zoom gesture, keep the last width and redraw once the gesture settles.
- Count labels are drawn with `draw_string`, only when the line is longer than 80 px on screen.
- Hit testing for hover and click finds the nearest curve within 6 px of the cursor, using a simple
  spatial grid of line bounding boxes.

There are no per-line nodes, buttons or terminals. Line ends attach to the side of the target box
(right edge for outputs, left edge for inputs), so no ports are needed.

### 4.5 Keeping up with the genome

`CircuitSchematic` listens to the same signals CB does on each region:
`cortical_area_added_to_region`, `cortical_area_removed_from_region`, `subregion_added/removed`,
`classifier_added/removed` and `friendly_name_updated`. It also listens to
`mapping_data.mapping_created/updated` and to genome reload.

- A change marks that region as stale.
- At most once per 200 ms, every stale region is laid out again. Size changes are passed up the
  parent chain to the root, then the canvas coordinates are recomputed and live nodes are
  repositioned.
- A genome reload rebuilds everything and keeps the current zoom and centre object where it still
  exists.

## 5. Visual spec

- **Region frames:** rounded rectangles, with a background tint that alternates between two theme
  shades by depth so nesting reads clearly. The border gets thicker for selected or hovered regions.
  The header has the name, an "areas · regions" count and the internal-connection badge.
- **Closed blocks:** the same colours as the open frame, with the name centred.
- **Areas:** filled with the CB type colours (`CBNodeCorticalArea.gd:71-75`). The full look adds
  the name and type; the coarse look is colour only.
- **Text:** hidden when it would be smaller than 8 px on screen. Names are shortened with an
  ellipsis.
- Everything uses the active BV theme, so light and dark both work.
- **Zoom range:** `min_zoom` must go much lower than CB's default so the root of a deep genome fits.
  Set it per view from the fit-all zoom × 0.5, and keep `max_zoom` at 2.0.

## 6. Performance targets (acceptance)

Measured on the synthetic stress genome (see §8: 60 regions, 5 levels deep, 600 areas, 3,000
mappings), on the team's baseline laptop:

| Measure | Target |
|---|---|
| Open schematic to first frame | ≤ 300 ms |
| Full layout of the tree | ≤ 50 ms |
| One open/close pass (decide + build line data) | ≤ 4 ms |
| Pan and zoom frame rate with ≤ 1,500 live nodes and ≤ 2,000 visible lines | ≥ 50 fps |
| Worst single-frame stall while opening a region | ≤ 16 ms beyond normal frame time |
| Memory for the tree + line data | ≤ 20 MB |

Correctness checks:

- Merged-line counts across all visible lines plus all badges equal the total mapping count.
- No two sibling boxes overlap after layout.
- Opening a region doesn't move anything outside it by more than 0 px.

## 7. Delivery phases

| Phase | Scope | Done when |
|---|---|---|
| 0. Spike (2-3 days) | Stress-genome generator. Prove the single-`_draw()` line layer sits under GraphElements and stays smooth. Test 1,500 GraphElements in a GraphEdit at the fps target. | Spike numbers written into this doc. Go or no-go on GraphEdit (fallback in §9). |
| 1. Tree + layout | `SchematicTree`, `SchematicLayout`, pull out `LayeredGraphLayout` (CB layout unchanged). Static view of everything open, for testing only. | Layout tests pass. CB before/after positions identical. |
| 2. Lazy loading | `SchematicLOD`, batched adds, node pool, node cap, coarse/full area looks. | §6 performance targets met on the stress genome. |
| 3. Lines | `SchematicEdges` + `SchematicEdgeLayer`, merged counts, badges, hover tooltips. | Count check passes. Hover hit test works within 6 px. |
| 4. Interaction | Shared selection, double-click zoom, Open in CB, search fly-to, breadcrumb, pinning, top-bar button. | Manual walkthrough on a real genome. Selecting in the schematic highlights in the Brain Monitor. |
| 5. Live updates | Signal hookup, stale-region relayout, reload keeps position. | Adding/removing an area or mapping through FEAGI updates the open schematic within 500 ms. |

**Later (not v1):**

- Editing in the schematic (drag to move, which needs a saved-position strategy; drag to connect).
- The "Use Circuit Builder positions" layout option.
- Live firing activity on area boxes.
- A feagi-mcp tool that returns the whole hierarchy in one call, so agents can reason about the
  same picture.

## 8. Tests

Headless GDScript tests in the existing style (`extends SceneTree`, run with
`godot --headless --path godot_source -s res://...`):

- **`test_schematic_layout.gd`:** sizes are computed bottom-up, no sibling overlaps, canvas
  coordinates are correct, and opening a region leaves outside rectangles unchanged.
- **`test_schematic_lod.gd`:** opening and closing happen at different sizes (no flicker), pinned
  regions override the rule, hidden-interior regions never open, the node cap holds, and nodes are
  added in batches.
- **`test_schematic_edges.gd`:** the visible end is chosen correctly, merged counts are right, the
  conservation check holds (lines + badges = all mappings), and partial mappings are flagged.
- **`test_layered_graph_layout.gd`:** the extracted layout gives the same positions as the current
  CB code on a fixture.
- **`tools/make_stress_genome.gd`:** generates the stress genome used in §6. It is also useful for
  CB regression testing.

## 9. Risks and open questions

| Risk | Mitigation |
|---|---|
| GraphEdit gets slow with about 1,500 GraphElements | **Confirmed in Phase 0** (48 fps at fit zoom with all 1,500 boxes). Coarse areas are now drawn by the layer (§4.3), so few nodes are live at any zoom. |
| A custom `_draw()` layer may not stay under GraphElements, or may not follow GraphEdit's transform | **Resolved in Phase 0.** A full-canvas GraphElement follows pan and zoom, and child order puts it between frames and areas. |
| A clicked frame jumps in front of its own areas | **Confirmed in Phase 0.** Frames don't raise (§4.3). |
| Using `GraphFrame` for nested frames | Not needed. Frames are plain GraphElements at positions we compute, drawn in depth order, so we don't depend on GraphFrame's auto-resize or nesting support. |
| Auto-layout looks different from what users arranged in CB | Make it clear in the UI that this is an overview. The "Use CB positions" option comes later. |
| Very deep genomes make the canvas huge | Canvas coordinates are floats, and the zoom range is set per view (§5). Precision is fine up to about 10⁶ px. |
| Merged lines hide which area inside a block is connected | The tooltip lists the top 5 area pairs. Double-click to open the block. |

**Open questions for the team:**

1. Is read-only v1 acceptable, or is drag-to-move needed at launch?
2. Should the schematic replace the root CB tab as the default 2D view once it's stable?
3. What is the largest real genome we must support (region count, depth, mapping count)? That sets
   the §6 targets.

## 10. Gaps found while designing

| Gap | Where | Status | Smallest fix |
|---|---|---|---|
| No view shows more than one region level at a time | BV Circuit Builder | verified | This design |
| CB auto-layout is tied to CB node instances, so it can't be reused on data | BV `CircuitBuilder.gd:1020+` | verified | Pull out `LayeredGraphLayout` (Phase 1) |
| Each CB connection creates a GraphElement + `Line2D` + its own shader material + `Button` + 2 terminals, which is heavy for large regions even in CB | BV `CBLine*`, `CircuitBuilder.gd:365-412` | verified (code); cost not measured | Reuse `SchematicEdgeLayer` in CB later |
| No MCP tool returns the whole region hierarchy with its connections in one call | feagi-mcp | suspected | Add an all-levels option to the region circuit tool |
| CB's fit/focus zoom clamp reads `min_zoom` / `max_zoom`, which don't exist in Godot 4 (`zoom_min` / `zoom_max`), so it always uses hard-coded 0.2–2.0 | BV `CircuitBuilder.gd:1672-1675` | verified | Rename to `zoom_min` / `zoom_max` |
| Each CB connection measured: 3,000 CB-style lines = 29,000 nodes, 3.4 s to build, 20 fps at fit zoom (vs. 87 fps for the single layer) | BV `CBLine*` | verified (Phase 0 replica) | Reuse `SchematicEdgeLayer` in CB later |

## 11. Phase 0 results (2026-10-21)

Spike: `spikes/circuit_schematic/` (README has the commands). Every region open, every area and
frame a GraphElement (Panel + Label), all mappings drawn, built 40 boxes per frame, then 4–6 s of
scripted pan and zoom with vsync off.

Machine: Apple M4 Pro, `gl_compatibility` renderer (same as BV), 1920×1080 window.
- This is a fast machine. Targets on the team's baseline laptop are still unmeasured.
- The compatibility renderer doesn't report GPU time, so the timings below are frame time and
  render CPU only.

**View (fps = mean over the phase; p99 frame ms in brackets)**

| Run | Boxes | Lines | Nodes | Fit-zoom pan | Zoom sweep | Close pan | Build |
|---|---|---|---|---|---|---|---|
| Stress, single layer (`draw_multiline`) | 661 | 3,000 | 2,007 | 87 (16) | 69 (21) | 146 (11) | 0.28 s |
| Stress, one `draw_polyline` per line | 661 | 3,000 | 2,007 | 51 (25) | 31 (39) | 67 (23) | 0.28 s |
| Stress, no lines | 661 | — | 2,006 | 109 (13) | 192 (11) | 249 (8) | 0.27 s |
| Stress, CB-style lines | 661 | 3,000 | 29,006 | 20 (57) | 35 (53) | 44 (29) | 3.4 s |
| 1,500 boxes, single layer | 1,500 | 4,000 | 4,524 | 48 (28) | 48 (30) | 109 (14) | 0.65 s |
| 1,500 boxes, no lines | 1,500 | — | 4,523 | 53 (24) | 119 (20) | 150 (11) | 0.63 s |
| 1,500 boxes, CB-style lines | 1,500 | 4,000 | 40,523 | 13 (82) | 26 (79) | 32 (37) | 7.5 s, 519 MB |
| 3,000 boxes, single layer | 3,000 | 8,000 | 9,024 | 26 (46) | 25 (62) | 60 (21) | 1.7 s |

- Line layer `_draw()` CPU: mean 0.54 ms at 3,000 lines, 0.71 ms at 4,000, 1.46 ms at 8,000
  (max 3.8 ms).
- Draw calls at fit zoom are about 2 per box (1,351 at 661 boxes, 3,031 at 1,500). Lines add only
  4 with batching, against about 3,000 with one call per line.
- Box creation: 0.06 ms CPU per box. 40 per frame peaked at 24 ms (stress) to 40 ms (3,000 boxes)
  per frame.

**Data side (no nodes)**

| Measure | Stress (3,000 mappings) | 1,500 boxes (4,000) | 3,000 boxes (8,000) | Target |
|---|---|---|---|---|
| Generate synthetic brain | 17 ms | 40 ms | 143 ms | — |
| Build tree | 2.6 ms | 5.7 ms | 10.6 ms | — |
| Nested layout (shelf packing) | 1.1 ms | 1.8 ms | 5.7 ms | ≤ 50 ms ✅ |
| Open/close decision | 0.08–0.16 ms | 0.03–0.20 ms | 0.04–0.38 ms | — |
| Merge lines (one pass) | 1.2–2.7 ms | 1.5–3.4 ms | 3.0–7.6 ms | ≤ 4 ms ✅ up to 4,000 mappings |
| Model memory | 3.4 MB | 5.8 MB | 11.4 MB | ≤ 20 MB ✅ |
| Line + badge count = mapping count | ✅ all cases | ✅ | ✅ | must hold |

What the open/close rule actually opens on the stress brain:

| Zoom | Regions open | Lines drawn |
|---|---|---|
| Fit | 5 | 489 |
| Mid | 19 | 1,395 |
| 1.0 | 17 | 1,293 |

In every case it is well under the everything-open worst case of 3,000.

**Verdict: go on GraphEdit**, with four changes already folded into §4:
1. The line layer sits between frames and areas.
2. Coarse areas are drawn by the layer instead of nodes, since at 1,500 boxes the boxes alone
   drop fit zoom to 53 fps.
3. Frames don't raise when clicked.
4. Boxes are added 25 per frame instead of 40.

The single layer is 4–7× faster than CB-style lines and uses about 1/10 of the nodes. Merging
lines must be made cheaper (cache visible ends per region, or update incrementally) before genomes
reach about 8,000 mappings, where one pass takes 5–7.6 ms.
