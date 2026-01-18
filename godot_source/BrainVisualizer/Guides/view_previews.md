# View Previews

View Previews is an advanced feature that allows Brain Visualizer to display raw video feeds from your embodiment's cameras using shared memory. This enables real-time video preview directly within Brain Visualizer without going through FEAGI's processing pipeline.

## What is View Previews?

View Previews displays raw video data from external sources (like camera feeds) using a cross-platform shared memory system. This provides:

- **Real-time Preview**: See what your agent's cameras see
- **Low Latency**: Direct memory access, bypassing network
- **Independent of FEAGI**: Works even when FEAGI processing is paused
- **Debugging Tool**: Verify camera feeds are working correctly
- **Multiple Sources**: Support for multiple video feeds

## How It Works

### Architecture

**Video Agent (Producer):**
- Captures video from camera or file
- Writes raw RGB frames to shared memory file
- Updates frame metadata (sequence number, dimensions)

**Brain Visualizer (Consumer):**
- Reads from shared memory file
- Displays frames in View Previews window
- Updates in real-time

**Shared Memory File:**
- Memory-mapped file on disk
- Contains header + raw frame data
- Cross-platform compatible

### Benefits

- **No Network Overhead**: Direct memory access
- **No FEAGI Processing Needed**: See raw input
- **Fast Updates**: Minimal latency
- **Easy Testing**: Verify camera setup independently

## Opening View Previews

**From Top Toolbar:**
1. Click **View Previews** button (if visible)
2. View Previews window opens

**Initial State:**
- Window shows placeholder or instructions
- No video until shared memory is opened
- Path field ready for input

## Using View Previews

### Step 1: Start Video Agent

First, run a video agent that writes to shared memory:

**Example with File Input:**
```bash
cd video_agent
source venv/bin/activate  # Activate virtual environment
python agent.py path/to/video.mp4 --shared-mem --shared-mem-path /tmp/feagi_video_shm.bin
```

**Example with Webcam:**
```bash
python agent.py --webcam --shared-mem --shared-mem-path /tmp/feagi_video_shm.bin
```

**Note:** The shared memory path can be anywhere, but must match what you enter in Brain Visualizer.

### Step 2: Open Shared Memory in Brain Visualizer

1. Copy the shared memory path (e.g., `/tmp/feagi_video_shm.bin`)
2. Open View Previews window
3. Paste path into the **Shared Memory Path** field
4. Click **Open SHM** button

### Step 3: Verify Connection

**Success Indicators:**
- Status label shows `SHM: opened`
- Then shows `SHM: tick <frame_number>`
- Frame displays in preview area
- Frame number increments as new frames arrive

**If Not Working:**
- Check video agent is running
- Verify path is exactly correct
- Check file exists at that path
- See Troubleshooting section below

## View Previews Interface

### Components

**Path Field:**
- Enter or paste shared memory file path
- Must be absolute path
- Platform-specific (Unix: `/tmp/...`, Windows: `C:\Temp\...`)

**Open SHM Button:**
- Connects to shared memory file
- Opens file for reading
- Starts frame updates

**Close SHM Button:**
- Disconnects from shared memory
- Stops frame updates
- Releases file handle

**Status Label:**
- Shows connection state
- Displays frame sequence number
- Error messages if problems occur

**Preview Area:**
- Displays video frames
- Auto-scales to fit window
- Updates at video source rate

**Frame Info:**
- Resolution (width × height)
- Frame sequence number
- Update rate (if shown)

### Shared Memory Path

The path depends on your operating system and configuration:

**Linux/macOS:**
- Typical: `/tmp/feagi_video_shm.bin`
- Or: `/dev/shm/feagi_video_shm.bin` (Linux tmpfs)
- Must be readable by Brain Visualizer process

**Windows:**
- Typical: `C:\Temp\feagi_video_shm.bin`
- Or user temp directory
- Check video agent output for actual path

**Custom Paths:**
- Can specify any path with `--shared-mem-path` in video agent
- Ensure directory exists and is writable/readable

## Use Cases

### Camera Verification

Before connecting to FEAGI:
1. Start video agent with shared memory
2. Open View Previews
3. Verify camera feed looks correct
4. Check resolution and quality
5. Confirm frame rate is adequate

Then connect video agent to FEAGI knowing feed is good.

### Debugging Vision Issues

If FEAGI isn't seeing expected input:
1. Check raw feed in View Previews
2. Verify camera is working at source
3. Isolate problem to camera, agent, or FEAGI
4. Fix underlying issue

### Monitoring Without FEAGI

View camera feeds without running full FEAGI:
- Useful for testing embodiment only
- Quick verification of hardware
- No neural processing overhead

### Multi-Camera Setup

Preview multiple camera feeds:
1. Run multiple video agents with different shared memory paths
2. Open View Previews window for each
3. Position windows to see all feeds
4. Verify all cameras working correctly

(Feature may require multiple View Previews windows, if supported)

## Performance Considerations

### Frame Rate

- View Previews updates as fast as video agent writes
- No built-in frame rate limiting (shows what's written)
- Higher rates may affect UI responsiveness

### Memory Usage

- Shared memory file size depends on frame resolution
- Typical: Width × Height × 3 bytes (RGB) + header
- Example: 640×480 = ~900 KB per frame

### Cleanup

- Shared memory file deleted when video agent stops (normal operation)
- May persist if agent crashes
- Can manually delete if needed

## Video Agent Configuration

When running video agent with shared memory:

**Required Arguments:**
- `--shared-mem`: Enable shared memory mode
- `--shared-mem-path PATH`: Specify file location (optional, uses default if omitted)

**Optional Arguments:**
- `--webcam`: Use webcam instead of file
- `FILE`: Path to video file (if not using webcam)
- Other agent-specific options

**Example Configurations:**

**File Loop:**
```bash
python agent.py video.mp4 --shared-mem --shared-mem-path /tmp/feed.bin
```

**Webcam Live:**
```bash
python agent.py --webcam --shared-mem --shared-mem-path /tmp/cam.bin
```

**Custom Resolution:**
```bash
python agent.py --webcam --width 1280 --height 720 --shared-mem
```

See video agent documentation for complete options.

## Troubleshooting

### "SHM: opened" but no frame

**Possible Causes:**
- Video agent not writing frames yet
- Video file ended (if looping disabled)
- Frame size mismatch
- Corrupted shared memory

**Solutions:**
- Wait a few seconds for first frame
- Check video agent console for errors
- Verify video agent is actually running
- Restart video agent

### "Can't open shared memory file"

**Possible Causes:**
- File doesn't exist at that path
- Path is incorrect
- Permission denied
- File is locked by another process

**Solutions:**
- Verify path is exactly correct
- Ensure video agent started successfully
- Check file exists: `ls -l /tmp/feagi_video_shm.bin` (Unix)
- Check file permissions
- Try different path

### "Header shows zeros"

**Possible Causes:**
- Video agent hasn't written header yet
- Shared memory file corrupted
- File opened before agent started

**Solutions:**
- Wait a moment and check again
- Restart video agent
- Close and reopen SHM in Brain Visualizer
- Delete file and recreate

### No logs or status updates

**Possible Causes:**
- Shared memory extension not loaded
- GDExtension library missing or incompatible
- Build issue with extension

**Solutions:**
- Verify GDExtension library exists at correct path
- Check library is compatible with your platform
- Run Brain Visualizer from terminal to see logs:
  - macOS: `open -a Godot --args --path /path/to/brain-visualizer --verbose`
  - Linux: `godot --path /path/to/brain-visualizer --verbose`
  - Windows: `godot.exe --path C:\path\to\brain-visualizer --verbose`
- Check for error messages about library loading

### Performance is poor

**Possible Causes:**
- Frame rate too high
- Resolution too large
- System resources limited

**Solutions:**
- Reduce video agent frame rate
- Lower video resolution
- Close unnecessary windows
- Use smaller preview window

### Frame is distorted or wrong colors

**Possible Causes:**
- Resolution mismatch in shared memory header
- RGB/BGR color order mismatch
- Corrupted frame data

**Solutions:**
- Verify video agent and Brain Visualizer agree on format
- Restart both video agent and Brain Visualizer
- Check video agent configuration

## Advanced Usage

### Multiple Video Feeds

To preview multiple cameras simultaneously:

1. Run multiple video agents on different shared memory files:
```bash
python agent.py --webcam --camera-id 0 --shared-mem --shared-mem-path /tmp/cam0.bin
python agent.py --webcam --camera-id 1 --shared-mem --shared-mem-path /tmp/cam1.bin
```

2. Open multiple View Previews windows (if supported)
3. Connect each to different shared memory path
4. Arrange windows to see all feeds

### Recording from Preview

Some versions may support:
- Screenshot of current frame
- Recording preview to file
- Frame export

Check View Previews window for available options.

### Integration with FEAGI

Video agent typically:
1. Writes to shared memory (for preview)
2. Sends to FEAGI (for processing)
3. Both happen simultaneously

This allows you to:
- See raw input (shared memory preview)
- Watch FEAGI processing (Brain Monitor)
- Compare input vs neural activity

## Platform-Specific Notes

### macOS

- Default path: `/tmp/feagi_video_shm.bin`
- May need to grant camera permissions to video agent
- Universal binary support for M1/Intel

### Linux

- Can use `/dev/shm` for true RAM-backed shared memory
- Better performance than `/tmp` on some systems
- Check permissions if access denied

### Windows

- Uses memory-mapped files
- Path typically in `%TEMP%` directory
- Backslashes in paths: `C:\Temp\file.bin`

## Best Practices

1. **Start Video Agent First**: Before opening SHM in Brain Visualizer
2. **Use Absolute Paths**: Avoid relative paths for shared memory
3. **Clean Up Files**: Delete old shared memory files if agent crashed
4. **Test Independently**: Verify camera works in preview before connecting to FEAGI
5. **Monitor Resources**: Large resolutions or high frame rates use memory
6. **Close When Done**: Release shared memory when not actively using

## Related Topics

- [Getting Started](getting_started.md) - Initial setup
- [Brain Monitor](brain_monitor.md) - Neural activity visualization
- [UI Controls](ui_controls.md) - Interface customization

## External Resources

- Video Agent Documentation: See `video_agent/README.md` in FEAGI project
- Shared Memory Video Extension: See `brain-visualizer/rust_extensions/feagi_shared_video/`
- Build Instructions: See `brain-visualizer/README.md` for building the extension

[Back to Overview](index.md)
