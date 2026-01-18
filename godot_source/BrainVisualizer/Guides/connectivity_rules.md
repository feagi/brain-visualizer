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
