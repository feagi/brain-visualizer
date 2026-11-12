# Vector Connectivity

A vector rule is a list of integer offsets `[dx, dy, dz]`. For every source
neuron at `(x, y, z)`, FEAGI tries to create a synapse to the destination
neuron at `(x+dx, y+dy, z+dz)` when that voxel exists.

Click the guide icon in the vector editor to return here.

## Editor format

Each row is one offset:

- `0, 0, 0` — identity: dest voxel equals source voxel
- `1, 0, 0` — one step in +X
- `0, 0, 1` — one step in +Z (next layer)
- `-1, 0, 0` — one step in -X

Add multiple rows to union several regular offsets (for example both +X and -X).

This is **not** a list of source-to-destination coordinate pairs. For filters
such as "only X 1 through 98" use a [pattern rule](pattern_connectivity.md)
with `N..M`, not a vector list.

## Visual editor

The visual editor shows the rule's offsets as cells on a grid, one Z slice at a time. The cross marks the center `(0, 0)`: a cell two to the right of it is the offset `2, 0`.

- **Click a cell** to add or remove that offset on the current slice.
- **Z < >** moves between slices. Each slice holds its own cells.
- **Grid − / Grid +** shows fewer, larger cells or more, smaller cells. Cells outside the visible grid are kept, and a note counts them.
- **Rotate** turns the current slice 90° around the center.
- **Shrink / Enlarge** halves or doubles each cell's distance from the center. Cells next to the center stay in place when shrinking.
- **Copy slice / Copy all / Paste** copy the current slice or every slice. Paste adds to what is there, so you can paste into another slice or another rule.
- **Clear** empties the current slice.
- **Undo / Redo** step through your changes since the editor opened.

Shortcuts work after you click inside the editor: Ctrl+Z undo, Ctrl+Shift+Z or Ctrl+Y redo, Ctrl+C copy slice, Ctrl+V paste (Cmd on Mac).

**Save** writes every slice back to the rule. **Cancel** discards all changes.

## When to use vectors

- Uniform topographic shift
- Identity (`[0,0,0]`, same as core `block_to_block`)
- A small set of regular neighbor offsets

Do not enumerate hundreds of unique channel offsets that are really one
pattern. Prefer `["1..98", "*", "*"] -> ["?", "?", 0]` for a contiguous
source-X block onto dest Z=0.

## Bounds

If `src + offset` leaves the destination area, that source neuron simply gets
no synapse for that vector. No wrap-around.

## Related Topics

- [Pattern Connectivity](pattern_connectivity.md) - wildcards, `N..M`, `?+N`
- [Connectivity Rules](connectivity_rules.md) - rule types and manager
- [Mapping Connections](mapping_connections.md) - applying a rule to a mapping
