# Mapping Connections

Mappings are the neural connections between cortical areas. They define how information flows through your genome, using morphologies to specify the exact wiring patterns.

## What is a Mapping?

A mapping is a connection from one cortical area (source) to another (destination) that:
- Uses a **morphology** to define connection structure
- Creates **synapses** between neurons
- Allows **information flow** during processing
- Can **learn and adapt** based on activity

Without mappings, cortical areas are isolated - mappings make them into an integrated neural network.

## Mapping Components

Each mapping consists of:

### Source and Destination
- **Source (Afferent)**: The cortical area sending signals
- **Destination (Efferent)**: The cortical area receiving signals
- Direction matters (A→B is different from B→A)

### Morphology
- Defines which neurons connect to which
- Determines connection density and pattern
- Can be shared across multiple mappings

See [Morphologies](morphologies.md) for details.

### Parameters
- **Postsynaptic Current**: Strength of influence
- **Plasticity**: Whether connections learn
- **Learning Rate**: Speed of adaptation
- **Weight Limits**: Min/max connection strengths

## Creating Mappings

### Method 1: Drag in Circuit Builder

The most intuitive method:

1. Open Circuit Builder
2. Click and hold on **output port** (right side) of source area
3. Drag to **input port** (left side) of destination area
4. Release to open Mapping Editor
5. Configure morphology and parameters
6. Click **Create** or **Apply**

### Method 2: Quick Connect

From context menu:

1. Right-click source cortical area
2. Select **Quick Connect**
3. Choose destination from list
4. Mapping Editor opens
5. Configure and create

### Method 3: Create Multiple

Connect one area to many:

1. Right-click source area
2. Select **Quick Connect**
3. Check multiple destinations
4. Set common morphology
5. Create all mappings at once

### Method 4: Bidirectional

Create two-way connection:

1. Create mapping A → B
2. Create mapping B → A
3. Or use bidirectional option if available
4. Each direction can use different morphology

## Mapping Editor

The Mapping Editor is your detailed interface for configuring connections.

### Editor Sections

**Header:**
- Source area name and type
- Destination area name and type
- Direction indicator (→)

**Morphology Selection:**
- Dropdown of existing morphologies
- Preview of selected morphology
- Button to create new morphology

**Parameters:**
- Postsynaptic current
- Plasticity settings
- Learning parameters
- Weight configuration

**Statistics:**
- Estimated synapse count
- Connection density
- Memory usage estimate

**Actions:**
- Apply/Create button
- Cancel button
- Advanced options

### Selecting Morphology

**Use Existing:**
1. Click morphology dropdown
2. Browse available morphologies
3. Select appropriate pattern
4. Preview updates

**Create New:**
1. Click **+ New Morphology**
2. Configure morphology type and parameters
3. Name the morphology
4. It becomes available in the list

### Configuring Parameters

**Postsynaptic Current (PSC):**
- Strength of synaptic influence
- Higher values = stronger effect
- Can be positive (excitatory) or negative (inhibitory)
- Typical range: 0.1 to 10.0

**Plasticity:**
- **Enabled**: Connections strengthen/weaken based on activity
- **Disabled**: Fixed connection weights
- Enable for learning applications

**Learning Rate:**
- Speed of synaptic adaptation
- Higher = faster learning
- Too high = instability
- Typical range: 0.001 to 0.1

**Weight Limits:**
- **Min Weight**: Minimum synaptic strength
- **Max Weight**: Maximum synaptic strength
- Prevents runaway growth or decay

### Creating the Mapping

Once configured:
1. Review parameters
2. Check synapse count estimate
3. Click **Create** or **Apply**
4. Mapping is created in FEAGI
5. Connection line appears in Circuit Builder
6. Connection is active in Brain Monitor

## Viewing Existing Mappings

### In Circuit Builder

Mappings appear as lines between cortical areas:
- **Line Style**: Indicates connection type
- **Line Color**: May indicate properties
- **Arrows**: Show direction of information flow

**Click a line** to view/edit its properties.

### In Brain Monitor

Hover over cortical area to see:
- Outgoing connections (from this area)
- Incoming connections (to this area)
- Active data flow (if neuron activity present)

**Connection Lines:**
- Highlight when hovering
- Show direction with arrows or flow
- Intensity indicates activity level

### Via Context Menu

Right-click cortical area:
1. Select **Details**
2. Navigate to **Connections** tab
3. View lists:
   - **Afferent** (incoming): Areas sending to this one
   - **Efferent** (outgoing): Areas this one sends to
   - **Recursive**: Connections to itself
4. Click connection to edit

## Editing Mappings

### Modifying Parameters

1. Click connection line in Circuit Builder OR
2. Right-click area → Details → Connections tab
3. Click mapping to edit
4. Mapping Editor opens
5. Modify parameters
6. Click **Apply**

Changes take effect immediately.

### Changing Morphology

1. Open mapping in Mapping Editor
2. Select different morphology from dropdown
3. Connection pattern updates
4. Synapse count may change
5. Click **Apply**

**Caution**: Major morphology changes may dramatically alter behavior.

### Copying Mappings

To replicate a mapping configuration:
1. Note the morphology and parameters
2. Create new mapping
3. Apply same settings
4. Or use batch creation for efficiency

## Deleting Mappings

### Single Mapping

1. Click connection line in Circuit Builder
2. Press **Delete** key OR
3. Right-click line → **Delete**
4. Confirm deletion

OR

1. Right-click cortical area → **Details**
2. Go to **Connections** tab
3. Find mapping in list
4. Click **Delete** button
5. Confirm

### Multiple Mappings

To delete all connections:
1. Select cortical area
2. Right-click → **Reset** (clears state but keeps connections)
3. OR manually delete each mapping

### On Area Deletion

When deleting a cortical area:
- All mappings to/from it are automatically deleted
- You'll see a confirmation showing affected mappings
- This cannot be undone

## Connection Patterns

### Feedforward (Input → Processing → Output)

Typical flow:
```
IPU (Vision) → Custom (Edge Detection) → Custom (Object Recognition) → OPU (Action)
```

**Best Practices:**
- Use appropriate morphologies for each stage
- All-to-All for mixing and integration
- One-to-One for spatial preservation

### Feedback (Higher → Lower)

Top-down modulation:
```
Memory (Context) → Custom (Visual Processing)
```

**Use Cases:**
- Attention and gating
- Expectations and predictions
- Context-dependent processing

### Lateral (Within Layer)

Same-level integration:
```
Custom (Left Visual Field) ↔ Custom (Right Visual Field)
```

**Use Cases:**
- Information sharing
- Lateral inhibition
- Continuous representations

### Recursive (Area to Itself)

Temporal processing:
```
Memory (Short Term) → Memory (Short Term)
```

**Use Cases:**
- Holding state over time
- Temporal integration
- Working memory

## Multiple Mappings

You can create multiple mappings between the same two areas:

**Why Multiple Mappings?**
- Different morphologies for different purposes
- Excitatory and inhibitory connections
- Different learning rates
- Parallel pathways

**Managing Multiple:**
- Each mapping is independent
- Synaptic effects combine
- Can have different parameters
- Visualized as separate lines (or combined)

## Mapping Direction

Direction is critical:

**A → B:**
- Neurons in A send to neurons in B
- Activity in A influences B
- Information flows A to B

**B → A:**
- Separate mapping (does NOT exist automatically)
- Must be created explicitly
- Can have different morphology and parameters

**Bidirectional:**
- Create both A → B and B → A
- Allows information to flow both ways
- Each direction is independent

## Connection Debugging

### No Activity Flowing

If expected activity doesn't appear:

1. **Verify Connection Exists**: Check Circuit Builder for line
2. **Check Source Activity**: Ensure source area is active
3. **Check Morphology**: Verify appropriate pattern
4. **Check PSC**: Ensure postsynaptic current is not too weak
5. **Check Path**: Trace from inputs through all connections

### Unexpected Behavior

If area behaves unexpectedly:

1. **Review Connections**: Check all afferent mappings
2. **Check Morphologies**: Verify connection patterns
3. **Check Parameters**: Look for unusual PSC or learning rates
4. **Check for Loops**: Recursive or feedback loops can cause issues
5. **Isolate**: Temporarily remove connections to identify culprit

### Performance Issues

If too many connections slow the system:

1. **Reduce Density**: Use sparser morphologies
2. **Limit Connections**: Set max connections per neuron
3. **Remove Unused**: Delete unnecessary mappings
4. **Optimize Morphologies**: Use efficient patterns

## Advanced Mapping Techniques

### Gating

Use one area to control another:
```
Context Area (modulation) → Processing Area (modulated)
```
Low PSC or conditional connections act as gates.

### Ensembles

Connect multiple areas to one target for voting/integration:
```
Evidence A → Decision
Evidence B → Decision
Evidence C → Decision
```

### Hierarchical

Build processing hierarchies:
```
Low-Level Features → Mid-Level Features → High-Level Features
```

### Attentional

Use feedback to enhance relevant processing:
```
Task Area (what to attend) → Sensory Area (what's attended)
```

## Synapse Budget

Mappings consume synapses:
- Check current vs max synapse count in top toolbar
- All-to-All mappings use the most
- Sparse patterns conserve synapses
- Plan ahead for large genomes

**Estimating Synapse Count:**
- Small areas, All-to-All: (M × N) synapses
- Large areas, sparse: Much fewer
- Mapping Editor shows estimate

## Best Practices

### Start Simple
1. Create minimal connections first
2. Test functionality
3. Add complexity incrementally
4. Verify each addition

### Use Appropriate Morphologies
- **One-to-One**: Spatial tasks
- **All-to-All**: Integration and mixing
- **Lateral**: Context and smoothing
- **Sparse**: Efficiency

### Name and Document
- Use meaningful cortical area names
- Document connection purposes
- Note unusual parameter choices
- Explain design decisions

### Test Incrementally
- Create one mapping at a time
- Verify expected behavior
- Check activity flow
- Then add next connection

### Monitor Performance
- Watch synapse count
- Check processing speed
- Optimize as needed
- Remove unnecessary connections

## Common Workflows

### Creating a Simple Circuit

1. Create Input (IPU) cortical area
2. Create Processing (Custom) area
3. Create Output (OPU) area
4. Connect IPU → Custom with All-to-All
5. Connect Custom → OPU with All-to-All
6. Test with data

### Building a Vision Pipeline

1. Vision IPU (camera input)
2. Edge Detection Custom (lateral morphology)
3. Feature Extraction Custom (All-to-All)
4. Object Recognition Custom (All-to-All)
5. Motor Control OPU (One-to-One or All-to-All)

### Adding Memory

1. Existing circuit: Input → Processing → Output
2. Create Memory area
3. Connect Processing → Memory (storage)
4. Connect Memory → Processing (recall)
5. Adjust parameters for learning

## Troubleshooting

**"Can't create mapping"**
- Verify both areas exist
- Check you're dragging to input port
- Ensure areas are in same FEAGI instance
- Try Quick Connect instead

**"Synapse count exceeds limit"**
- Use sparser morphology
- Reduce cortical area dimensions
- Limit connections per neuron
- Increase genome synapse limit (if possible)

**"Activity not propagating"**
- Check connection exists and direction is correct
- Verify source area is active
- Check PSC is not too small
- Look for blocking connections (inhibitory)

**"Mapping line disappeared"**
- May be hidden (check visualization settings)
- Might have been deleted accidentally
- Verify in cortical area Details → Connections

**"Too many connections are confusing"**
- Use Split View to focus on sub-regions
- Hover to highlight specific connections
- Hide global connections toggle
- Work on one region at a time

## Related Topics

- [Morphologies](morphologies.md) - Connection structure templates
- [Cortical Areas](cortical_areas.md) - What gets connected
- [Circuit Builder](circuit_builder.md) - Visual connection creation
- [Brain Monitor](brain_monitor.md) - Visualizing active connections
- [Quick Menu](quick_menu.md) - Quick Connect operations

[Back to Overview](index.md)
