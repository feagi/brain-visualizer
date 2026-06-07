# Connectivity Rules

Connectivity Rules define the shape and structure of neural connections between cortical areas. They determine how neurons in one area connect to neurons in another, creating the pathways for information flow.

## What is a Connectivity Rule?

A connectivity rule is a template that specifies:
- **Connection Pattern**: Which neurons connect to which
- **Spatial Arrangement**: How connections are organized in 3D space
- **Density**: How many connections are created
- **Plasticity**: How connections change over time

Think of connectivity rules as the "wiring diagrams" that define how cortical areas communicate.

## Why Connectivity Rules Matter

Different connection patterns serve different purposes:
- **One-to-One**: Direct correspondence (e.g., pixel to neuron)
- **Divergent**: One source neuron to many targets (broadcasting)
- **Convergent**: Many sources to one target (integration)
- **Lateral**: Neighborhood connections (spatial relationships)
- **All-to-All**: Fully connected (complete mixing)

Choosing the right connectivity rule is crucial for your genome's function.

## Types of Connectivity Rules

### Composite Rule
**Purpose**: Combines multiple simpler connectivity rules

**Characteristics:**
- Contains multiple sub-connectivity rules
- Can create complex connection patterns
- Most flexible type

**Use Cases:**
- Combining feedforward and lateral connections
- Multiple connection types in one mapping
- Hierarchical connection structures

### Function Connectivity Rule
**Purpose**: Connections defined by mathematical functions

**Characteristics:**
- Formula-based connection rules
- Parametric control
- Precise spatial relationships

**Use Cases:**
- Gaussian receptive fields
- Distance-based connectivity
- Custom mathematical patterns

### Vectors Connectivity Rule
**Purpose**: Explicitly defined connection vectors

**Characteristics:**
- Manual specification of connections
- Exact control
- Can represent any pattern

**Use Cases:**
- Specific wiring requirements
- Unusual connection patterns
- Precise custom connectivity

### Patterns Connectivity Rule
**Purpose**: Pre-defined common patterns

**Characteristics:**
- Built-in templates
- Easy to use
- Optimized implementations

**Common Patterns:**
- All-to-All
- One-to-One
- Grid patterns
- Lateral patterns

## Pattern Connectivity Rule Syntax

Pattern connectivity is the primary mechanism for defining how neurons in a source
cortical area connect to neurons in a destination cortical area. Each rule is a pair
of 3D patterns: one describing **which source neurons** participate, and one describing
**which destination neurons** each qualifying source neuron connects to.

### How Patterns Work

Every neuron occupies a position in a 3D voxel grid: `(x, y, z)`. A pattern
connectivity rule specifies, for each axis independently, which coordinates are selected.

A rule is written as:

```
[src_x, src_y, src_z] -> [dst_x, dst_y, dst_z]
```

The **source pattern** filters which source neurons participate. The **destination
pattern** expands into a set of target coordinates for each participating source neuron.
A synapse is created for every expanded destination where a neuron actually exists.

### Pattern Elements

#### Absolute Patterns

These do not depend on the source neuron's position.

| Syntax | Name | Meaning |
|--------|------|---------|
| `*` | Wildcard | All coordinates on this axis (0 to dimension-1) |
| `5` | Exact | Only coordinate 5 |

#### Source-Relative Patterns

These resolve relative to the source neuron's coordinate on the same axis.

| Syntax | Name | Meaning |
|--------|------|---------|
| `?` | Pass-through | Same coordinate as the source neuron |
| `!` | Exclude | All coordinates except the source's |
| `?+` | Direction positive | All coordinates strictly greater than source |
| `?-` | Direction negative | All coordinates strictly less than source |
| `?+=` | Direction positive inclusive | All coordinates greater than or equal to source |
| `?-=` | Direction negative inclusive | All coordinates less than or equal to source |
| `?+N` | Offset positive | Single coordinate at source + N |
| `?-N` | Offset negative | Single coordinate at source - N |
| `?-A:?+B` | Range | All coordinates from source-A to source+B (inclusive) |

### Pattern Examples

All examples assume a 10x10x10 destination area unless noted otherwise.

#### Every neuron connects to the single neuron at (0,0,0)

```
[["*", "*", "*"], [0, 0, 0]]
```

Source: every neuron qualifies (wildcard on all axes).
Destination: always the fixed point (0,0,0).

#### Neuron at (0,0,0) connects to every neuron

```
[[0, 0, 0], ["*", "*", "*"]]
```

Source: only the neuron at (0,0,0) qualifies.
Destination: every coordinate in the destination area.

#### One-to-one mapping (identity)

```
[["*", "*", "*"], ["?", "?", "?"]]
```

Source: all neurons. Destination: the neuron at the same (x,y,z) coordinate.
This creates a topographic 1:1 map between areas of the same dimensions.

#### Lateral inhibition (connect to all except self)

```
[["*", "*", "*"], ["!", "!", "!"]]
```

Each neuron connects to every other neuron in the destination (all positions
except its own coordinate on each axis).

#### Every neuron connects to all neurons to its right

```
[["*", "*", "*"], ["?+", "?", "?"]]
```

Source: all neurons. Destination: on the X axis, all coordinates greater than
the source's X. Y and Z pass through.

For a source at `(3, 2, 0)`: destinations are `(4,2,0), (5,2,0), ..., (9,2,0)`.

A neuron at the rightmost edge `(9, y, z)` has no destinations (nothing to its right).

#### Every neuron connects to all neurons below it

```
[["*", "*", "*"], ["?", "?-", "?"]]
```

On the Y axis, all coordinates strictly less than the source. X and Z pass through.

#### Every neuron connects to its immediate neighbor one step to the right

```
[["*", "*", "*"], ["?+1", "?", "?"]]
```

Single offset: destination X = source X + 1. Boundary neurons at X=max produce
no connection (offset lands outside the area).

#### Every neuron connects to a 3x3 local patch on XY

```
[["*", "*", "*"], ["?-1:?+1", "?-1:?+1", "?"]]
```

Range: X spans [src_x - 1, src_x + 1], Y spans [src_y - 1, src_y + 1]. Z passes
through. This produces up to 9 connections per neuron (fewer at boundaries where
the range gets clamped to valid coordinates).

#### Every neuron connects to the 5 neighbors ahead on X

```
[["*", "*", "*"], ["?+1:?+5", "?", "?"]]
```

Range from src+1 to src+5. A neuron at X=7 in a 10-wide area would connect to
X=8 and X=9 only (clamped).

#### Column 0 fans out to all positions in the positive X direction

```
[[0, "*", "*"], ["?+", "*", "*"]]
```

Source: only neurons with X=0 qualify. Destination: full fan-out across all Y and Z,
but only X coordinates > 0.

#### Feedforward layer-to-layer (Z layers)

```
[["*", "*", 0], ["?", "?", 1]]
```

Source: only neurons at Z=0. Destination: same X and Y, but at Z=1. Connects one
layer to the next while preserving spatial topology.

#### Connect each neuron to everything to its left AND right (but not self)

Combine two rules:

```
[
  [["*", "*", "*"], ["?+", "?", "?"]],
  [["*", "*", "*"], ["?-", "?", "?"]]
]
```

The pattern system processes all rules and unions the results (duplicates removed).

### Boundary Behavior

All relative patterns are automatically clamped to valid coordinates `[0, dimension)`.
This means:

- A neuron at X=0 with destination `"?-"` produces no connections on the X axis.
- A neuron at X=max with destination `"?+"` produces no connections on the X axis.
- A range `"?-3:?+3"` at X=1 in a 10-wide area produces X values `[0, 1, 2, 3, 4]`
  (the -3 clamps to 0).

Boundary neurons naturally have fewer connections. No special handling is needed.

### Axis Independence

Each axis is expanded independently, then combined via Cartesian product. The
destination pattern `["?+", "?-1:?+1", "*"]` means:

- X: all coordinates > source X
- Y: source Y - 1 to source Y + 1
- Z: all coordinates

The total destinations = (count of X values) x (count of Y values) x (count of Z values).

### Visual Editor: Hover Mode

When using the visual pattern editor, if the source pattern matches multiple neurons
(any axis uses `*` or a non-exact pattern) and the destination uses relative patterns,
the destination grid will be blank initially. Hover your mouse over individual source
cells to preview the destination connections for that specific source position.

## Viewing Connectivity Rules

### Connectivity Rule Manager

Access via top toolbar:

1. Click **Connectivity Rules** button (gear icon)
2. View list of all connectivity rules
3. See details:
   - Name
   - Type
   - Usage count (how many mappings use it)
   - Parameters

### Connectivity Rule Details

Click a connectivity rule to view:
- **Type**: Composite, Function, Vectors, Patterns
- **Parameters**: Specific configuration
- **Usage**: Which mappings use this connectivity rule
- **Preview**: Visual representation (if available)

## Creating Connectivity Rules

### Method 1: Via Connectivity Rule Manager

1. Click **Connectivity Rules** in top toolbar
2. Click **+ Create New** button
3. Choose connectivity rule type
4. Configure parameters
5. Name the connectivity rule
6. Click **Create**

### Method 2: During Mapping Creation

When connecting cortical areas:
1. Open Mapping Editor
2. Click **Create New Connectivity Rule**
3. Configure and create inline
4. Apply to the mapping

### Method 3: Clone Existing

Duplicate and modify:
1. Open Connectivity Rule Manager
2. Right-click connectivity rule
3. Select **Clone**
4. Modify parameters
5. Save with new name

## Configuring Connectivity Rules

### Composite Connectivity Rule

**Sub-Connectivity Rules:**
- Add multiple component connectivity rules
- Each contributes to overall pattern
- Order and composition matters

**Combining Modes:**
- Additive: Combine all connections
- Override: Later connectivity rules override earlier
- Blend: Weighted combination

### Function Connectivity Rule

**Formula Definition:**
- Mathematical expression for connectivity
- Variables: source position, target position, distance
- Output: Connection strength or boolean

**Parameters:**
- Function-specific parameters
- Ranges and scales
- Threshold values

### Patterns Connectivity Rule

**Pattern Selection:**
- Choose from library of patterns
- Configure pattern-specific options
- Adjust density and spacing

**Common Patterns:**

**All-to-All:**

![All-to-All Pattern](../UI/GenericResources/Connectivity RuleIcons/all_to_all.png)

- Every source connects to every target
- Dense connectivity
- High synapse count

**One-to-One:**
- Direct correspondence between positions
- Preserves spatial relationships
- Requires matching dimensions

**Block-to-Block:**

![Block-to-Block Pattern](../UI/GenericResources/Connectivity RuleIcons/block_to_block.png)

- Regions connect to regions
- Reduced connection count
- Structured connectivity

**Lateral Connections:**

![Lateral Pattern](../UI/GenericResources/Connectivity RuleIcons/lateral_+x.png)

- Connections within neighborhood
- Spatial proximity matters
- Local integration

### Vectors Connectivity Rule

**Connection Specification:**
- Define source → target pairs
- Explicit connection list
- Full manual control

**Format:**
- Source coordinates (X, Y, Z)
- Target coordinates (X, Y, Z)
- Connection weight (optional)

## Editing Connectivity Rules

### Modifying Existing Connectivity Rule

**Caution**: Changes affect all mappings using this connectivity rule.

1. Open Connectivity Rule Manager
2. Click connectivity rule to edit
3. Click **Edit** button
4. Modify parameters
5. Click **Save**
6. All mappings using it will update

### Safe Editing (Clone First)

To avoid affecting existing mappings:
1. Clone the connectivity rule
2. Edit the clone
3. Manually update specific mappings to use the clone

## Connectivity Rule Parameters

### Common Parameters

**Spatial Parameters:**
- **Offset**: Shift connection pattern
- **Scale**: Expand or contract pattern
- **Rotation**: Rotate connection pattern

**Density Parameters:**
- **Connection Probability**: Chance of connection
- **Max Connections**: Limit per neuron
- **Min Connections**: Ensure minimum

**Learning Parameters:**
- **Plasticity**: Enable/disable learning
- **Learning Rate**: Speed of adaptation
- **Hebbian Rules**: Strengthen/weaken based on activity

### Type-Specific Parameters

Each connectivity rule type has unique parameters. Consult the parameter descriptions in the creation/editing interface for details.

## Using Connectivity Rules in Mappings

When creating a connection between cortical areas:

1. Source area → Target area
2. Select connectivity rule from list OR create new
3. Connectivity Rule defines connection structure
4. Multiple mappings can share one connectivity rule

See [Mapping Connections](mapping_connections.md) for complete details.

## Connectivity Rule Best Practices

### Naming

Use descriptive names:
- **Good**: "Gaussian_5x5_Receptive_Field"
- **Good**: "Lateral_Inhibition_3_Neighbor"
- **Avoid**: "Connectivity Rule_001", "Test"

### Reusability

Create general-purpose connectivity rules:
- Design for reuse across multiple mappings
- Parameterize instead of hardcoding
- Document the purpose in the name

### Start Simple

Begin with standard patterns:
1. Try built-in patterns first
2. Understand behavior before customizing
3. Gradually introduce complexity
4. Test incremental changes

### Test Incrementally

When creating custom connectivity rules:
1. Start with small cortical areas
2. Verify connection pattern is correct
3. Check synapse count is reasonable
4. Scale up once confirmed

## Visualizing Connectivity Rules

### In Mapping Editor

When viewing a mapping:
- Connection pattern preview (if available)
- Parameter visualization
- Synapse count estimate

### In Brain Monitor

When cortical areas are connected:
- Hover to see connection lines
- Observe activity flow
- Verify expected patterns

### Connection Analysis

Check the mapping to verify:
- Source neurons have appropriate connections
- Target neurons receive expected inputs
- Connection density is reasonable
- Pattern matches intent

## Common Connectivity Rule Patterns

### Feedforward Processing

**All-to-All:**
- Complete mixing of inputs
- Pattern recognition
- Feature extraction

**One-to-One:**
- Spatial preservation
- Topographic mapping
- Direct transformation

### Lateral Integration

**Neighbor Connections:**
- Local context awareness
- Edge detection
- Spatial smoothing

**Distance-Based:**
- Proximity-weighted connections
- Gaussian receptive fields
- Attentional mechanisms

### Feedback and Modulation

**Sparse Long-Range:**
- Top-down modulation
- Attention signals
- Context information

**Divergent Broadcast:**
- Global signals
- Neuromodulation
- State information

## Managing Many Connectivity Rules

### Organization

For large genomes:
- **Naming Conventions**: Prefix by type or purpose
- **Documentation**: Describe in detail
- **Cleanup**: Delete unused connectivity rules

### Finding Usage

To find where a connectivity rule is used:
1. Open Connectivity Rule Manager
2. Click connectivity rule
3. View "Usage" section
4. Lists all mappings

### Updating

To update connectivity rule across all uses:
1. Edit the connectivity rule directly
2. Changes propagate to all mappings
3. Or clone and manually update specific mappings

## Connectivity Rule and Performance

### Synapse Count

Connectivity Rules determine synapse count:
- All-to-All: Highest count (M × N)
- Sparse Patterns: Lower count
- One-to-One: Minimal count (min(M, N))

Check genome synapse limits before creating.

### Connection Density

Balance connectivity with performance:
- Dense connections: More computation
- Sparse connections: Less computation
- Choose appropriate for task

### Memory Usage

More complex connectivity rules:
- Use more memory
- Take longer to compute
- May slow visualization

Optimize for efficiency.

## Advanced Topics

### Dynamic Connectivity Rules

Some connectivity rules adapt over time:
- Plasticity rules modify connections
- Learning strengthens/weakens synapses
- Structural changes possible

### Conditional Connectivity Rules

Connections based on neuron properties:
- Activity-dependent wiring
- Type-specific connections
- State-dependent patterns

### Multi-Scale Connectivity Rules

Combine patterns at different scales:
- Local + Global connections
- Short-range + Long-range
- Different patterns per layer

## Troubleshooting

**"Too many synapses"**
- Reduce connection density
- Use sparser connectivity rule patterns
- Limit max connections per neuron
- Check cortical area dimensions

**"Connections don't appear"**
- Verify connectivity rule is applied to mapping
- Check connection parameters aren't zero
- Ensure source and target dimensions are compatible
- View in Mapping Editor for details

**"Wrong connection pattern"**
- Review connectivity rule parameters
- Check offset and scale settings
- Verify pattern type is correct
- Test with smaller areas first

**"Performance is slow"**
- Reduce synapse count
- Simplify connectivity rules
- Use optimized patterns
- Consider dimension reduction

**"Can't delete connectivity rule"**
- Check if it's in use by mappings
- Remove from all mappings first
- Or force delete (breaks mappings)

## Related Topics

- [Mapping Connections](mapping_connections.md) - Applying connectivity rules
- [Cortical Areas](cortical_areas.md) - What connectivity rules connect
- [Circuit Builder](circuit_builder.md) - Visual connection creation
- [Brain Monitor](brain_monitor.md) - Visualizing connections

[Back to Overview](index.md)
