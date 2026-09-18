# Vector Connectivity

A vector rule is a list of integer offsets `[dx, dy, dz]`. For every source
neuron at `(x, y, z)`, FEAGI tries to create a synapse to the destination
neuron at `(x+dx, y+dy, z+dz)` when that voxel exists.

Click the guide icon in the vector editor to return here.

## Editor format

Each row is one offset:

| dx | dy | dz | Result |
|----|----|----|--------|
| 0 | 0 | 0 | Identity: dest voxel equals source voxel |
| 1 | 0 | 0 | One step in +X |
| 0 | 0 | 1 | One step in +Z (next layer) |
| -1 | 0 | 0 | One step in -X |

Add multiple rows to union several regular offsets (for example both +X and -X).

This is **not** a list of source-to-destination coordinate pairs. For filters
such as "only X 1 through 98" use a [pattern rule](pattern_connectivity.md)
with `N..M`, not a vector list.

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

## Related

- [Pattern Connectivity](pattern_connectivity.md) - wildcards, `N..M`, `?+N`
- [Connectivity Rules](connectivity_rules.md) - rule types and manager
- [Mapping Connections](mapping_connections.md) - applying a rule to a mapping
