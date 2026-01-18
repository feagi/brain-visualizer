# Brain Regions

Brain regions are organizational containers that help you structure and manage complex genomes. They group related cortical areas and sub-regions into logical hierarchies, making large neural architectures easier to understand and navigate.

## What is a Brain Region?

A brain region is a named container that can hold:
- **Cortical Areas**: The actual neural processing units
- **Sub-Regions**: Other brain regions, creating hierarchical organization
- **Metadata**: Name, description, and organizational properties

Think of brain regions as folders in a file system - they help organize and categorize without affecting the actual neural processing.

## Purpose and Benefits

### Organization
- Group functionally related cortical areas
- Create logical divisions (vision, motor, memory, etc.)
- Build hierarchical structures that reflect your architecture

### Navigation
- Jump directly to specific regions
- View regions in isolation
- Focus on subsystems independently

### Scalability
- Manage genomes with hundreds or thousands of cortical areas
- Hide complexity in sub-regions
- Work on one part without seeing everything

### Collaboration
- Clear structure helps teams understand the genome
- Named regions document the architecture
- Regions can be worked on independently

## The Main Circuit

Every genome has a root region called **Main Circuit**:
- Created automatically by FEAGI
- Contains all top-level cortical areas and regions
- Cannot be deleted
- The starting point for navigation

## Creating Brain Regions

### Method 1: From Selection

Create a region and automatically add selected areas:

1. In Circuit Builder, select cortical areas you want to group
2. Right-click on selection or empty space
3. Select **Create Region**
4. Enter region name and properties:
   - **Name**: Descriptive name (e.g., "Visual Processing")
   - **Description**: Optional notes
   - **Parent Region**: Where to create it (default: current region)
5. Click **Create**

Selected areas move into the new region automatically.

### Method 2: Empty Region

Create an empty region and add areas later:

1. Right-click empty space in Circuit Builder
2. Select **Create Region**
3. Don't select any cortical areas beforehand
4. Configure name and properties
5. Click **Create**

Add areas later using "Add to Region" operation.

### Method 3: From Top Toolbar

Quick access from anywhere:

1. Click **Circuits** in top toolbar
2. Click **+** button
3. Configure region properties
4. Choose parent region
5. Click **Create**

## Navigating Regions

### Opening Regions

**Method 1: Double-Click**
- In Circuit Builder, double-click a region node
- The view switches to show that region's contents

**Method 2: Dropdown Menu**
- Click **Circuits** in top toolbar
- Select region from the list
- Opens in new Circuit Builder tab

**Method 3: Quick Menu**
- Right-click region node
- Select **Open** or **Open 3D Tab**

### Navigating Up/Back

To return to parent region:
- Use the navigation breadcrumbs (if visible)
- Click **Circuits** dropdown and select parent region
- Close the current region tab

### Viewing Hierarchy

The **Circuits** dropdown shows:
- All regions in hierarchical tree structure
- Current region highlighted
- Quick navigation to any region

## Region Structure

### Visual Representation

**In Circuit Builder (2D):**
- Appears as larger rectangular node
- Contains smaller cortical area and region nodes
- Double-click to "enter" and view contents
- Shows name and brief metadata

**In Brain Monitor (3D):**
- Spatial grouping of contained areas
- Optional boundary visualization
- Dedicated 3D tabs for focused viewing

### Contents

Regions can contain:
- **Cortical Areas**: Any number of IPU, OPU, Memory, Custom areas
- **Sub-Regions**: Nested regions for deeper hierarchy
- **Mixed**: Both cortical areas and sub-regions together

### Hierarchy Depth

Regions can nest arbitrarily deep:
```
Main Circuit
├── Visual System
│   ├── Left Eye Processing
│   │   ├── Edge Detection
│   │   └── Color Processing
│   └── Right Eye Processing
├── Motor Control
│   ├── Left Motors
│   └── Right Motors
└── Memory Systems
    ├── Short Term Memory
    └── Long Term Memory
```

## Managing Region Contents

### Adding Areas to Region

**Method 1: At Creation**
- Select areas first
- Create region
- Areas automatically added

**Method 2: Move Existing Area**
1. Right-click cortical area
2. Select **Add to Region**
3. Choose destination region
4. Confirm move

**Method 3: Drag and Drop** (if enabled)
- Drag cortical area onto region node
- Area moves into that region

### Moving Areas Between Regions

1. Right-click cortical area
2. Select **Add to Region**
3. Choose new parent region
4. Click **Move**

The area moves, maintaining all connections.

### Removing Areas from Region

To move an area to the parent region:
1. Right-click area
2. Select **Add to Region**
3. Choose the parent region
4. Confirm

### Nesting Regions

Regions can contain other regions:
1. Right-click a region node
2. Select **Add to Region**
3. Choose a destination region
4. The region moves with all its contents

## Editing Region Properties

### Basic Properties

Right-click region → **Details** to edit:

**General:**
- **Name**: The display name
- **Description**: Optional notes
- **Parent Region**: Where it's located in hierarchy
- **Region ID**: Unique identifier (read-only)

**Statistics:**
- **Total Cortical Areas**: Count of areas in region (recursive)
- **Direct Children**: Immediate child areas and sub-regions
- **Neuron Count**: Total neurons in region
- **Synapse Count**: Total synapses

**Contents:**
- List of contained cortical areas
- List of contained sub-regions
- Quick navigation links

### Renaming Regions

1. Right-click region
2. Select **Details**
3. Edit name field
4. Press Enter or click Apply

Good names describe the function or purpose.

### Moving Regions

**Change Parent:**
1. Right-click region
2. Select **Add to Region**
3. Choose new parent
4. Confirm

**2D Position (in Circuit Builder):**
- Drag the region node to new position
- Position is relative to parent region view

## Cloning Regions

Duplicate an entire region with all contents:

1. Right-click region
2. Select **Clone**
3. Configure:
   - **New Name**: Must be unique
   - **Clone Contents**: Include all cortical areas and sub-regions
   - **Clone Connections**: Include internal connections
   - **Clone External Connections**: Include connections to outside areas
4. Click **Clone**

**Note:** Cloning large regions creates many new neurons. Check capacity first.

## Deleting Regions

Remove a region and optionally its contents:

1. Right-click region
2. Select **Delete**
3. Choose deletion mode:
   - **Delete Region Only**: Move contents to parent region
   - **Delete Region and Contents**: Remove everything
4. Confirm deletion

**Warning:** Deleting region and contents removes all cortical areas inside (recursive). This cannot be undone.

## Working with Region Tabs

### Circuit Builder Tabs

Each region can open in its own Circuit Builder tab:

**Benefits:**
- View multiple regions side-by-side
- Compare structures
- Work on different parts independently
- Maintain context while navigating

**Opening Tabs:**
- Use **Circuits** dropdown
- Each selection opens new tab
- Switch tabs using tab bar

**Closing Tabs:**
- Click **X** on tab
- Right-click tab → **Close**

### 3D Brain Monitor Tabs

View region contents in isolated 3D view:

1. Right-click region in Circuit Builder
2. Select **Open 3D Tab**
3. Split view opens with:
   - Circuit Builder for that region (left/top)
   - Brain Monitor showing region in 3D (right/bottom)

**Benefits:**
- Focus on specific subsystem
- Less visual clutter
- Better performance with large genomes
- Synchronized 2D/3D view of region

See [Split View](split_view.md) for more details.

## Region Organization Strategies

### Functional Grouping

Group by purpose:
```
├── Sensory Input
│   ├── Vision
│   ├── Audio
│   └── Touch
├── Processing
│   ├── Feature Extraction
│   ├── Pattern Recognition
│   └── Decision Making
├── Memory
│   ├── Working Memory
│   └── Long Term Storage
└── Motor Output
    ├── Movement
    └── Speech
```

### Hierarchical Decomposition

Break complex systems into layers:
```
├── Navigation System
│   ├── Perception Layer
│   │   ├── Obstacle Detection
│   │   └── Path Recognition
│   ├── Planning Layer
│   │   ├── Route Planning
│   │   └── Collision Avoidance
│   └── Execution Layer
│       ├── Motor Commands
│       └── Steering Control
```

### Modular Architecture

Create reusable modules:
```
├── Shared Modules
│   ├── Edge Detection (reusable)
│   ├── Pattern Matching (reusable)
│   └── Memory Buffer (reusable)
├── Application A
│   └── (uses shared modules)
└── Application B
    └── (uses shared modules)
```

## Common Patterns

### Sensory Processing Pipeline

```
Vision System
├── Raw Input (IPU)
├── Preprocessing
│   ├── Normalization
│   └── Noise Reduction
├── Feature Extraction
│   ├── Edge Detection
│   ├── Color Analysis
│   └── Motion Detection
└── Pattern Recognition
    └── Object Identification
```

### Motor Control Hierarchy

```
Motor System
├── High-Level Planning
├── Trajectory Generation
├── Motor Commands (OPU)
└── Feedback Processing
```

### Memory System

```
Memory
├── Sensory Buffers
├── Short-Term Memory
├── Long-Term Storage
└── Retrieval Mechanisms
```

## Best Practices

### Naming Conventions

**Good Names:**
- Descriptive: "Visual Processing System"
- Functional: "Object Recognition"
- Hierarchical: "Vision → Left Eye → Edge Detection"

**Avoid:**
- Generic: "Region 1", "New Region"
- Ambiguous: "Stuff", "Misc"
- Technical: "r_0034_v2"

### Depth Guidelines

- **2-4 levels**: Ideal for most genomes
- **5+ levels**: May be over-organized
- **Flat structure**: Hard to navigate with many areas

Balance organization with simplicity.

### Size Guidelines

- **10-30 areas per region**: Comfortable to view
- **50+ areas**: Consider subdividing
- **1-5 areas**: Might be over-organized

Find the right granularity for your needs.

### Documentation

Use region descriptions to document:
- Purpose of the region
- How it connects to other regions
- Design decisions
- References to papers or algorithms

## Inter-Region Connections

Cortical areas can connect across region boundaries:

**Connection Rules:**
- Any area can connect to any other area
- Connections are NOT limited to same region
- Region boundaries are organizational only

**Viewing Cross-Region Connections:**
- In Circuit Builder, lines may cross region boundaries
- In Brain Monitor, hover areas to see all connections
- Use Mapping Editor to view connection details

**Managing Complex Connections:**
- Minimize unnecessary cross-region connections
- Document major inter-region pathways
- Use regions to represent information flow stages

## Performance and Scalability

### Large Genomes

For genomes with 100+ cortical areas:

1. **Use Regions Heavily**: Group into 10-20 regions
2. **Work in Tabs**: Focus on one region at a time
3. **Use 3D Tabs**: Isolate regions for better performance
4. **Close Unused Tabs**: Free up resources

### Navigation Speed

- **Dropdowns**: Fastest way to jump between regions
- **Double-Click**: Fast for nearby regions
- **3D Tabs**: Good for frequently-accessed regions

### Organization Maintenance

- Reorganize as genome grows
- Create sub-regions when regions get large
- Rename regions to reflect current purpose
- Delete empty or obsolete regions

## Troubleshooting

**"Can't find my cortical area"**
- Check which region it's in
- Use global search (if available)
- Navigate through region hierarchy
- Use Circuits dropdown to view all regions

**"Region appears empty"**
- Ensure you've navigated into it (double-click or open)
- Check that areas weren't accidentally moved
- Verify in FEAGI that region exists

**"Can't delete region"**
- Main Circuit cannot be deleted
- Check if region contains areas (delete or move them first)
- Ensure no references elsewhere

**"Lost in hierarchy"**
- Use Circuits dropdown to see structure
- Click on parent regions to go up
- Open Main Circuit to start over

**"Performance is slow"**
- Close unnecessary region tabs
- Use 3D tabs for large regions
- Simplify region hierarchy
- Reduce visible cortical areas

## Related Topics

- [Circuit Builder](circuit_builder.md) - Navigating and editing regions
- [Cortical Areas](cortical_areas.md) - The contents of regions
- [Split View](split_view.md) - Viewing regions in dedicated tabs
- [Brain Monitor](brain_monitor.md) - 3D visualization of regions
- [Navigation Basics](navigation.md) - Moving between regions
- [Quick Menu](quick_menu.md) - Region operations

[Back to Overview](index.md)
