# Navigation Action Reference

Use this quick lookup for navigation and camera actions currently implemented in Brain Visualizer.

## Global Navigation Actions

- **Jump to an input area** -> Hover Inputs on the root scene top bar (or on a main-circuit tab) -> choose area
- **Jump to a circuit** -> Hover Circuits -> choose circuit. The current view focuses on it. This does not open a new tab.
- **Jump to an output area** -> Hover Outputs on the root scene top bar (or on a main-circuit tab) -> choose area
- **Jump to an interconnect or memory area** -> Hover that title on a Circuit Builder or Brain Monitor tab bar -> choose area
- **Open one connectivity rule** -> Hover Connectivity Rules on the root scene top bar -> choose rule. The manager opens on that rule.
- **Focus selected region/area in active views** -> Select object, then press F
- **Clear window-level selection or close active popup/window** -> Escape (context dependent; also cancels an in-progress Brain Monitor box select)

## Circuit Builder (2D) Navigation

- **Pan** -> Middle Drag or Shift + Left Drag
- **Zoom** -> Mouse Wheel
- **Fit all objects** -> Right-click empty space -> Fit All
- **Focus on selected cortical area/region** -> Select node, then press F
- **Open region in Brain Monitor** -> Right-click region -> Open 3D Tab

## Brain Monitor (3D) Camera Controls (Tank Mode - default)

- **Pan camera** -> Left Drag
- **Rotate camera** -> Right Drag
- **Zoom camera** -> Mouse Wheel Up/Down
- **Zoom camera at double speed** -> Shift + mouse wheel, or Shift + trackpad scroll
- **Move camera in X/Z plane** -> W/A/S/D or Arrow Keys
- **Move camera faster** -> Hold Shift while moving (speed boost)
- **Reset camera framing** -> R (when mouse is over that Brain Monitor viewport)

## Brain Monitor (3D) Focus and Plane-Oriented Focus

- **Focus clicked cortical area on XY plane** -> Ctrl + 1 + Click
- **Focus clicked cortical area on XZ plane** -> Ctrl + 2 + Click
- **Focus clicked cortical area on YZ plane** -> Ctrl + 3 + Click
- **Focus clicked brain region frame** -> Ctrl + Click on region frame

## Brain Monitor (3D) Selection and Neuron Actions

- **Select cortical area** -> Left Click on cortical volume
- **Select brain region frame** -> Left Click on region frame
- **Add/remove cortical area from multi-selection** -> Ctrl + Click on cortical area (Cmd + Click on macOS)
- **Box-select multiple cortical areas** -> Shift + Left Drag a rectangle in the 3D scene
- **Toggle voxel selection (additive)** -> Hold Shift, then Click voxels
- **Fire selected voxels once** -> Space (release Shift first if you were picking voxels)
- **Start continuous fire of selected voxels** -> Shift + Space
- **Stop continuous fire** -> Space (or Shift + Space)
- **Clear all selected voxels** -> Delete (also stops continuous fire)

## Brain Monitor (3D) Voxel Clipboard Actions

- **Open Voxel Selection Capture panel** -> Select 2+ voxels with Shift + Click
- **Copy selected voxels JSON to clipboard** -> Ctrl + C (Cmd + C on macOS), or Voxel Selection Capture panel -> Copy JSON to clipboard
- **Open Area Firing Recorder panel** -> Ctrl + Click one or more cortical areas
- **Record fired voxels during simulation** -> Area Firing Recorder -> Start Recording
- **Stop recording and copy fired voxels JSON** -> Area Firing Recorder -> Stop + Copy
- **Paste clipboard voxels into hovered cortical area** -> Hover target area, then Ctrl + V (Cmd + V on macOS)
- **Paste clipboard voxels into Quick Connect mapping step** -> Quick Connect Neuron window -> Paste button on source/destination side

## Arrange, Undo, and Redo

- **Align selected areas on X, Y, or Z** -> Multi-select 2 or more areas in one circuit -> Quick Menu -> Arrange -> Align
- **Distribute selected areas on X, Y, or Z** -> Multi-select 3 or more areas in one circuit -> Quick Menu -> Arrange -> Distribute
- **Undo last saved move or area delete** -> Ctrl+Z (Cmd+Z on macOS)
- **Redo that step** -> Shift+Ctrl+Z (Shift+Cmd+Z)

Align snaps the chosen axis to the lowest value in the selection. Distribute keeps the outermost areas fixed. Reserved core areas cannot be arranged. Text fields keep their own undo. History clears when another genome loads. See [Navigation Basics](navigation.md).

## Manipulation Session Shortcuts (when gizmo manipulation is active)

- **Confirm manipulation** -> Enter
- **Cancel manipulation** -> Escape

## Notes

- **Home** behavior can vary by context and window; for Brain Monitor camera reset, use **R**.
- Some controls are only active when the relevant panel/viewport has focus or hover.
- **Ctrl + C** voxel copy requires at least one selected voxel and does not run while a text field is focused.
- **Ctrl + V** voxel paste requires a cortical area under the mouse in Brain Monitor and does not run while a text field is focused.
- Clipboard paste into a hovered area unions voxels from all areas in the JSON and additively selects them (Shift+click behavior).

For additional behavior details, see [Navigation Basics](navigation.md), [Camera Controls](camera_controls.md), and [Brain Monitor](brain_monitor.md).

[Back to Overview](index.md)
