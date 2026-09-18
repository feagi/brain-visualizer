# Pattern Connectivity

Pattern rules select **which source neurons** participate and **where each one
connects** in the destination area. Each row is one pair:

```
[src_x, src_y, src_z] -> [dst_x, dst_y, dst_z]
```

Type tokens in the pattern editor, or use Raw edit for JSON. Click the guide
icon in the pattern editor to return here.

## Absolute tokens

These do not depend on the source neuron's position.

| Syntax | Meaning |
|--------|---------|
| `*` | All coordinates on this axis |
| `5` | Only coordinate 5 |
| `N..M` | Coordinates N through M inclusive |

`N..M` is the compact form for a contiguous block. Example sit/motor subset:

```
[["1..98", "*", "*"], ["?", "?", 0]]
```

Source X 1 through 98, any Y/Z. Destination keeps X and Y, command bin Z=0.

Do not write `1-98` or `1:98`. Those are not absolute ranges. Unknown strings
are treated as `*` by FEAGI and will over-connect.

## Source-relative tokens

These resolve from the source neuron's coordinate on the same axis. On the
**source** side they do not filter (`*` / exact / `N..M` do). On the
**destination** side they expand targets.

| Syntax | Meaning |
|--------|---------|
| `?` | Same coordinate as the source neuron |
| `!` | All coordinates except the source's |
| `?+` / `?-` | Strictly greater / less than source |
| `?+=` / `?-=` | Inclusive greater / less than source |
| `?+N` / `?-N` | Single offset from source |
| `?-A:?+B` | Destination span from source-A to source+B |

`?-A:?+B` is **not** an absolute source filter. Use `N..M` for that.

## Common rows

| Intent | Rule |
|--------|------|
| Identity | `["*", "*", "*"] -> ["?", "?", "?"]` |
| All sources to dest origin | `["*", "*", "*"] -> [0, 0, 0]` |
| One voxel fans out | `[0, 0, 0] -> ["*", "*", "*"]` |
| Neighbor +X | `["*", "*", "*"] -> ["?+1", "?", "?"]` |
| Local 3x3 XY | `["*", "*", "*"] -> ["?-1:?+1", "?-1:?+1", "?"]` |
| Contiguous X to dest Z=0 | `["1..98", "*", "*"] -> ["?", "?", 0]` |

Multiple rows are unioned. Combine two direction rules for left-and-right.

## Boundary behavior

Relative expansions clamp to `[0, dimension)`. Neurons at an edge produce fewer
destinations. An inverted absolute range (`98..1`) matches nothing.

## Related

- [Connectivity Rules](connectivity_rules.md) - rule types and manager
- [Vector Connectivity](vector_connectivity.md) - offset lists, not patterns
- [Mapping Connections](mapping_connections.md) - applying a rule to a mapping
