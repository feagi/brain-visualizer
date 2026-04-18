# Camera Animations

Camera Animations lets you capture camera checkpoints, auto-generate animation JSON, and run a compact presentation controller in the bottom-right corner of the screen.

## What It Does

Use Camera Animations to:

- Build camera paths from checkpoints
- Preview timed transitions between checkpoints
- Step through checkpoints manually during a presentation
- Return to your original camera pose when exiting presentation mode
- Keep your animation JSON available when reopening the window in the same session

## Open Camera Animations

1. Click the **Camera Animations** icon on the top toolbar.
2. In the Camera Animations window, configure transition/interpolation settings and add checkpoints.

![Camera Icon](../UI/GenericResources/ButtonIcons/camera_C.jpg)

## Current Window Workflow

### Capture Checkpoints

1. Move the camera to a desired viewpoint.
2. Click **Add Current Position**.
3. Repeat for each checkpoint.

Each checkpoint stores:

- `position` (Vector3)
- `rotation` (Quaternion)
- `time` (seconds to transition to the next checkpoint)

### JSON Is Auto-Populated

- The **Exported Animation JSON** field is automatically regenerated when you add or clear checkpoints.
- There is no separate export button in the current workflow.
- You can still paste/edit JSON manually if needed.

### Launch Presentation Controller

1. Click **Open Animation Controller**.
2. The Camera Animations window hides.
3. A compact controller appears at bottom-right.

## Bottom-Right Presentation Controller

Current button order (left to right):

1. **Reset**
2. **Play / Pause**
3. **Previous**
4. **Next**
5. **Close (X)**

### Reset

- Returns camera to the original pose captured right before presentation started.

### Play / Pause

- **Play** runs timed animation from the current checkpoint forward.
- **Pause** stops timed playback and keeps the exact live/interpolated camera pose (no snapping to checkpoint).

### Previous / Next

- Move manually between checkpoints.
- These controls are for manual stepping mode (non-timed playback).

### Close (X)

- Exits presentation mode.
- Restores the original camera pose from before you clicked **Open Animation Controller**.

## JSON Persistence

During the current app session:

- The JSON field content is cached.
- After closing presentation and reopening Camera Animations, the previous JSON is restored.

For long-term storage across app restarts, copy JSON into an external file.

## Suggested Usage Pattern

1. Set **Transition Time** and interpolation options.
2. Add multiple checkpoints with **Add Current Position**.
3. Confirm JSON looks correct.
4. Click **Open Animation Controller**.
5. Use:
   - **Play** for timed walkthrough
   - **Pause** to stop on exact current camera pose
   - **Previous/Next** for manual checkpoint stepping
   - **Reset** to return to pre-presentation start pose
6. Click **Close (X)** when finished to restore initial camera pose.

## Troubleshooting

**Controller does not appear**

- Ensure JSON is valid and non-empty before clicking **Open Animation Controller**.

**Playback is not as expected**

- Check each checkpoint `time` value.
- Verify movement/rotation interpolation selections.

**Need to continue later**

- Reopen Camera Animations in the same session; JSON should be restored.
- Save JSON externally for restart-safe persistence.

## Related Topics

- [Camera Controls](camera_controls.md) - Manual camera movement
- [Navigation Basics](navigation.md) - General interaction patterns
- [Brain Monitor](brain_monitor.md) - 3D visualization context

[Back to Overview](index.md)
