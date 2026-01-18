# Morphologies

Morphologies define the shape and structure of neural connections between cortical areas. They determine how neurons in one area connect to neurons in another, creating the pathways for information flow.

## What is a Morphology?

A morphology is a template that specifies:
- **Connection Pattern**: Which neurons connect to which
- **Spatial Arrangement**: How connections are organized in 3D space
- **Density**: How many connections are created
- **Plasticity**: How connections change over time

Think of morphologies as the "wiring diagrams" that define how cortical areas communicate.

## Why Morphologies Matter

Different connection patterns serve different purposes:
- **One-to-One**: Direct correspondence (e.g., pixel to neuron)
- **Divergent**: One source neuron to many targets (broadcasting)
- **Convergent**: Many sources to one target (integration)
- **Lateral**: Neighborhood connections (spatial relationships)
- **All-to-All**: Fully connected (complete mixing)

Choosing the right morphology is crucial for your genome's function.

## Types of Morphologies

### Composite Morphology
**Purpose**: Combines multiple simpler morphologies

**Characteristics:**
- Contains multiple sub-morphologies
- Can create complex connection patterns
- Most flexible type

**Use Cases:**
- Combining feedforward and lateral connections
- Multiple connection types in one mapping
- Hierarchical connection structures

### Function Morphology
**Purpose**: Connections defined by mathematical functions

**Characteristics:**
- Formula-based connection rules
- Parametric control
- Precise spatial relationships

**Use Cases:**
- Gaussian receptive fields
- Distance-based connectivity
- Custom mathematical patterns

### Vectors Morphology
**Purpose**: Explicitly defined connection vectors

**Characteristics:**
- Manual specification of connections
- Exact control
- Can represent any pattern

**Use Cases:**
- Specific wiring requirements
- Unusual connection patterns
- Precise custom connectivity

### Patterns Morphology
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

## Viewing Morphologies

### Morphology Manager

Access via top toolbar:

1. Click **Morphologies** button (gear icon)
2. View list of all morphologies
3. See details:
   - Name
   - Type
   - Usage count (how many mappings use it)
   - Parameters

### Morphology Details

Click a morphology to view:
- **Type**: Composite, Function, Vectors, Patterns
- **Parameters**: Specific configuration
- **Usage**: Which mappings use this morphology
- **Preview**: Visual representation (if available)

## Creating Morphologies

### Method 1: Via Morphology Manager

1. Click **Morphologies** in top toolbar
2. Click **+ Create New** button
3. Choose morphology type
4. Configure parameters
5. Name the morphology
6. Click **Create**

### Method 2: During Mapping Creation

When connecting cortical areas:
1. Open Mapping Editor
2. Click **Create New Morphology**
3. Configure and create inline
4. Apply to the mapping

### Method 3: Clone Existing

Duplicate and modify:
1. Open Morphology Manager
2. Right-click morphology
3. Select **Clone**
4. Modify parameters
5. Save with new name

## Configuring Morphologies

### Composite Morphology

**Sub-Morphologies:**
- Add multiple component morphologies
- Each contributes to overall pattern
- Order and composition matters

**Combining Modes:**
- Additive: Combine all connections
- Override: Later morphologies override earlier
- Blend: Weighted combination

### Function Morphology

**Formula Definition:**
- Mathematical expression for connectivity
- Variables: source position, target position, distance
- Output: Connection strength or boolean

**Parameters:**
- Function-specific parameters
- Ranges and scales
- Threshold values

### Patterns Morphology

**Pattern Selection:**
- Choose from library of patterns
- Configure pattern-specific options
- Adjust density and spacing

**Common Patterns:**

**All-to-All:**
- Every source connects to every target
- Dense connectivity
- High synapse count

**One-to-One:**
- Direct correspondence between positions
- Preserves spatial relationships
- Requires matching dimensions

**Block-to-Block:**
- Regions connect to regions
- Reduced connection count
- Structured connectivity

**Lateral Connections:**
- Connections within neighborhood
- Spatial proximity matters
- Local integration

### Vectors Morphology

**Connection Specification:**
- Define source → target pairs
- Explicit connection list
- Full manual control

**Format:**
- Source coordinates (X, Y, Z)
- Target coordinates (X, Y, Z)
- Connection weight (optional)

## Editing Morphologies

### Modifying Existing Morphology

**Caution**: Changes affect all mappings using this morphology.

1. Open Morphology Manager
2. Click morphology to edit
3. Click **Edit** button
4. Modify parameters
5. Click **Save**
6. All mappings using it will update

### Safe Editing (Clone First)

To avoid affecting existing mappings:
1. Clone the morphology
2. Edit the clone
3. Manually update specific mappings to use the clone

## Morphology Parameters

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

Each morphology type has unique parameters. Consult the parameter descriptions in the creation/editing interface for details.

## Using Morphologies in Mappings

When creating a connection between cortical areas:

1. Source area → Target area
2. Select morphology from list OR create new
3. Morphology defines connection structure
4. Multiple mappings can share one morphology

See [Mapping Connections](mapping_connections.md) for complete details.

## Morphology Best Practices

### Naming

Use descriptive names:
- **Good**: "Gaussian_5x5_Receptive_Field"
- **Good**: "Lateral_Inhibition_3_Neighbor"
- **Avoid**: "Morphology_001", "Test"

### Reusability

Create general-purpose morphologies:
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

When creating custom morphologies:
1. Start with small cortical areas
2. Verify connection pattern is correct
3. Check synapse count is reasonable
4. Scale up once confirmed

## Visualizing Morphologies

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

## Common Morphology Patterns

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

## Managing Many Morphologies

### Organization

For large genomes:
- **Naming Conventions**: Prefix by type or purpose
- **Documentation**: Describe in detail
- **Cleanup**: Delete unused morphologies

### Finding Usage

To find where a morphology is used:
1. Open Morphology Manager
2. Click morphology
3. View "Usage" section
4. Lists all mappings

### Updating

To update morphology across all uses:
1. Edit the morphology directly
2. Changes propagate to all mappings
3. Or clone and manually update specific mappings

## Morphology and Performance

### Synapse Count

Morphologies determine synapse count:
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

More complex morphologies:
- Use more memory
- Take longer to compute
- May slow visualization

Optimize for efficiency.

## Advanced Topics

### Dynamic Morphologies

Some morphologies adapt over time:
- Plasticity rules modify connections
- Learning strengthens/weakens synapses
- Structural changes possible

### Conditional Morphologies

Connections based on neuron properties:
- Activity-dependent wiring
- Type-specific connections
- State-dependent patterns

### Multi-Scale Morphologies

Combine patterns at different scales:
- Local + Global connections
- Short-range + Long-range
- Different patterns per layer

## Troubleshooting

**"Too many synapses"**
- Reduce connection density
- Use sparser morphology patterns
- Limit max connections per neuron
- Check cortical area dimensions

**"Connections don't appear"**
- Verify morphology is applied to mapping
- Check connection parameters aren't zero
- Ensure source and target dimensions are compatible
- View in Mapping Editor for details

**"Wrong connection pattern"**
- Review morphology parameters
- Check offset and scale settings
- Verify pattern type is correct
- Test with smaller areas first

**"Performance is slow"**
- Reduce synapse count
- Simplify morphologies
- Use optimized patterns
- Consider dimension reduction

**"Can't delete morphology"**
- Check if it's in use by mappings
- Remove from all mappings first
- Or force delete (breaks mappings)

## Related Topics

- [Mapping Connections](mapping_connections.md) - Applying morphologies
- [Cortical Areas](cortical_areas.md) - What morphologies connect
- [Circuit Builder](circuit_builder.md) - Visual connection creation
- [Brain Monitor](brain_monitor.md) - Visualizing connections

[Back to Overview](index.md)
