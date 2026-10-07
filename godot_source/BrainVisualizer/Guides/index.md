# Brain Visualizer User Guide

Brain Visualizer is the editor and live monitor for a brain running in FEAGI (Framework for Evolutionary Artificial General Intelligence). FEAGI executes the brain. This guide covers how to inspect that brain, change its structure, and read its activity.

## What is Brain Visualizer?

A FEAGI brain is stored as a genome: the specification of its cortical areas, the circuits that group those areas, and the connections among them. Brain Visualizer loads the genome from a running FEAGI instance and edits it in place.

From here you add and arrange cortical areas, connect them, organize them into circuits, and observe neurons firing while FEAGI is running.

## What It Does Not Do

Brain Visualizer requires FEAGI to be running and a genome to be loaded. It does not retrieve published models, define an experiment, produce or inspect sensory data, train the network, or attach the brain to a robot or a simulator.

Those steps belong to [Neurorobotics Studio](https://brainsforrobots.com/nrs), the desktop environment that runs Brain Visualizer together with the rest of the workflow:

- **My Experiments**: Bind a genome to an embodiment, the robot or simulation it controls, and manage those pairings
- **Embodiment Explorer**: Select a physical or simulated body, including robots, simulators, and microcontrollers
- **Brain Hub**: Retrieve a published genome and load it
- **FEAGI Academy**: Structured tutorials for the platform
- **Hey FEAGI**: Query and direct a running brain in natural language
- **FEAGI Trainer**: Train from tabular data, images, or video
- **Sensory Generator**: Inject sensory streams, including camera, screen, video, and audio
- **Perception Inspector**: Examine the sensory patterns the brain is emitting
- **Vision Lab**: Segmentation, detection, pose estimation, and depth

Edit and monitor the genome here. Use Neurorobotics Studio for a published model, an embodiment, sensory input, or a training run. Visit [BrainsForRobots.com](https://brainsforrobots.com) to learn more.

## Quick Start

1. **Connect to FEAGI**: Brain Visualizer connects to a running FEAGI instance via WebSocket
2. **Explore the Interface**: Use the Circuit Builder (2D view) and Brain Monitor (3D view) to navigate your genome
3. **Create Neural Structures**: Add cortical areas, connect them, and organize them into regions
4. **Visualize Activity**: Watch neurons fire in real-time in the 3D Brain Monitor

## Core Concepts

- **Cortical Areas**: The building blocks of your genome. These are volumes of neurons that process information
- **Brain Circuits**: Organizational containers that group related cortical areas and sub-circuits
- **Integrated Circuits**: Custom circuits you configure, such as a classifier. Packaged tiles on Add Circuit are genomes or connectomes.
- **Connectivity Rules**: Define the shape and properties of neural connections
- **Modulators**: Change neuron or synapse behavior while a driver neuron is firing. See [Modulators](cortical_areas.md)
- **Mappings**: Connections between cortical areas that use specific connectivity rules
- **IPU/OPU**: Input and Output Processing Units - how your genome interacts with the world

## Feature Overview

### Interface & Navigation
- [Getting Started](getting_started.md) - First steps with Brain Visualizer
- [Navigation Basics](navigation.md) - Moving around in 2D and 3D views
- [Navigation Action Reference](navigation_actions_reference.md) - Action-to-input quick lookup table
- [Camera Controls](camera_controls.md) - Advanced camera navigation
- [Camera Animations](camera_animations.md) - Recording and playing camera paths
- [Split View](split_view.md) - Working with side-by-side views
- [UI Controls](ui_controls.md) - Scaling, themes, and interface customization

### Working with Cortical Areas
- [Cortical Areas](cortical_areas.md) - Creating and managing cortical areas
- [Cortical Area Details](cortical_area_details.md) - Complete guide to the Details window and all parameters

### Building Neural Circuits
- [Circuit Builder](circuit_builder.md) - The 2D graph editor for neural circuits
- [Brain Circuits](brain_circuits.md) - Organizing cortical areas into hierarchies
- [Integrated Circuits](integrated_circuits.md) - Custom circuits you configure, including the classifier
- [Mapping Connections](mapping_connections.md) - Connecting cortical areas together
- [Connectivity Rules](connectivity_rules.md) - Defining connection shapes and properties
- [Pattern Connectivity](pattern_connectivity.md) - Pattern tokens including `N..M`
- [Vector Connectivity](vector_connectivity.md) - Offset lists `[dx, dy, dz]`

### Visualization & Monitoring
- [Brain Monitor](brain_monitor.md) - The 3D visualization system

### Advanced Features
- [Quick Menu](quick_menu.md) - Context-sensitive right-click operations

### Reference
- [Glossary](glossary.md) - Complete reference of FEAGI and Brain Visualizer terminology

## Getting Help

- Use the **Search bar** at the top of the guide to quickly find topics
- Click topic buttons on the left to browse by category
- Follow links within guides to jump between related topics
- Access this guide anytime by clicking the guide icon in the top toolbar

![Guide Icon](../UI/GenericResources/ButtonIcons/guide_C.jpg)

## Tips for Success

1. **Start Simple**: Create a few cortical areas and connect them before building complex circuits
2. **Use Split View**: Open Circuit Builder and Brain Monitor side-by-side for the best workflow
3. **Name Things Clearly**: Give your cortical areas and regions descriptive names
4. **Save Camera Positions**: Use camera animations to save important viewpoints
5. **Explore the Quick Menu**: Right-click objects to discover context-sensitive operations

Ready to begin? Start with [Getting Started](getting_started.md) or jump to any topic using the sidebar.
