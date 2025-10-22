# FEAGI Brain Visualizer

[![GitHub Release](https://img.shields.io/github/v/release/feagi/brain-visualizer)](https://github.com/feagi/brain-visualizer/releases) [![Discord](https://img.shields.io/discord/1242546683791933480)](https://discord.gg/PTVC8fyGN8) [![GitHub License](https://img.shields.io/github/license/feagi/brain-visualizer)](https://www.apache.org/licenses/LICENSE-2.0.txt)


The Brain Visualizer is an open-source [Godot](https://github.com/godotengine/godot) based client of [FEAGI](https://github.com/feagi/feagi) that lets users interact with Genomes. It can both to modify various neural structures, and visualize the neuronal activity happening within.

<video autoplay muted src="https://github.com/user-attachments/assets/5578d618-5fee-40f5-8413-c29d2e91c951" width="320" height="240"></video>


# Using Brain Visualizer
Please see our tutorial for how to use Brain Visualizer [here](https://youtu.be/hH1KYexMQsA).

## Launching Brain Visualizer
###  ☁️ NeuroRobotics Sudio

[Neurorobotics Studio](https://www.neurorobotics.com/neurorobotics-studio) is our cloud-based solution for the fastest and easiest way to load FEAGI services within the FEAGI playground, including the brain visualizer!

### 🛠️Local Deployment
Brain Visualizer can be deployed locally as part of FEAGI Playground.

### To run Brain Visualizer as a standalone
Please see here: [DEPLOY.md](DEPLOY.md)

# Shared Memory Video Preview (Desktop)

This optional feature shows a live raw video feed (from `video_agent`) inside Brain Visualizer without going through FEAGI. It uses a cross‑platform memory‑mapped file.

Workflow:
- Python `video_agent`: publishes raw RGB frames to a memory‑mapped file
- Godot: `SharedMemVideo` GDExtension reads the file and displays it in View Previews

## 1) Build the Godot extension

macOS (Apple Silicon or Intel):
- From `brain-visualizer/rust_extensions/feagi_shared_video`:
  - Debug build: `cargo build`
  - Universal debug (arm64 + x86_64):
    - `rustup target add aarch64-apple-darwin x86_64-apple-darwin`
    - `cargo build --target aarch64-apple-darwin && cargo build --target x86_64-apple-darwin`
    - `lipo -create -output target/universal_debug.dylib target/aarch64-apple-darwin/debug/libfeagi_shared_video.dylib target/x86_64-apple-darwin/debug/libfeagi_shared_video.dylib`
    - Copy to Godot addon path:
      - `cp target/universal_debug.dylib ../../godot_source/addons/feagi_shared_video/target/debug/libfeagi_shared_video.dylib`

Windows:
- `cargo build` to produce `target\debug\feagi_shared_video.dll`
- Place it under `godot_source\addons\feagi_shared_video\target\debug\feagi_shared_video.dll`
- Update `feagi_shared_video.gdextension` windows entries if needed

Linux:
- `cargo build` to produce `target/debug/libfeagi_shared_video.so`
- Place it under `godot_source/addons/feagi_shared_video/target/debug/libfeagi_shared_video.so`
- Update `feagi_shared_video.gdextension` linux entries if needed

Ensure `godot_source/addons/feagi_shared_video/feagi_shared_video.gdextension` points to your platform paths.

## 2) Run the video agent (producer)

- Activate the `video_agent` venv and run:
  - File input example:
    - `python agent.py path/to/video.mp4 --shared-mem --shared-mem-path /tmp/feagi_video_shm.bin`
  - Webcam example (preview‑only requires FEAGI disabled, see note below):
    - `python agent.py --webcam --shared-mem --shared-mem-path /tmp/feagi_video_shm.bin`

Notes:
- The file is removed when the agent stops.
- Default path if not provided: OS temp dir with name `feagi_video_shm--temp.bin`.

## 3) View inside Brain Visualizer (consumer)

- Open the project: `brain-visualizer/godot_source/project.godot`
- Top‑bar → “View Previews”
- In the window:
  - Paste the shared memory path (e.g., `/tmp/feagi_video_shm.bin`) into the path field
  - Click “Open SHM”
  - The label should show `SHM: opened`, then `SHM: tick <frame_seq>`
  - The frame should render

Troubleshooting:
- If no logs: the extension may not be loading; verify the `.gdextension` library paths and the built library exists at those paths.
- If header shows zeros or no ticks: ensure the agent is running and writing to the same path.
- Launch Godot from a terminal to see logs (macOS example):
  - `open -a Godot --args --path /Users/…/brain-visualizer/godot_source --verbose`

# Community
Feel free to reach out to us on one of our various platforms!
- [Discord](https://discord.gg/PTVC8fyGN8)
- [Twitter (also known as X)](https://x.com/neuraville)
- [YouTube](https://www.youtube.com/@Neuraville)
- [LinkedIn](https://www.linkedin.com/groups/12777894/)

# Contributing
Please see our general contribution guide [here](https://github.com/feagi/feagi/blob/staging/CONTRIBUTING.md).

For Brain Visualizer specifically, please download the appropriate Godot editor version [here](https://godotengine.org/download/archive/4.2.2-stable) and open a cloned copy of this repository with it. Keep in mind you will require an instance of FEAGI running.

See our developer notes for Brain Visualizer [here](https://github.com/feagi/brain-visualizer/blob/staging/docs/Architecture.md).

# License
Brain Visualizer is distributed under the terms of the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0.txt).
