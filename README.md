# FEAGI Brain Visualizer

**See inside a learning brain in real-time**

[![GitHub Release](https://img.shields.io/github/v/release/feagi/brain-visualizer)](https://github.com/feagi/brain-visualizer/releases) [![PyPI](https://img.shields.io/badge/PyPI-feagi--bv-blue)](https://pypi.org/project/feagi-bv/) [![Discord](https://img.shields.io/discord/1242546683791933480)](https://discord.gg/PTVC8fyGN8) [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

<video autoplay muted src="https://github.com/user-attachments/assets/5578d618-5fee-40f5-8413-c29d2e91c951" width="640" height="480"></video>

---

## What is Brain Visualizer?

Brain Visualizer is a 3D visualization tool for [FEAGI](https://github.com/feagi/feagi) (Framework for Evolutionary Artificial General Intelligence). It lets you:

- **Visualize neural activity** in real-time as your AI learns
- **Edit brain structures** (cortical areas, connections, neurons)
- **Debug agents** by watching information flow through the brain
- **Understand learning** through interactive 3D exploration

**Built with [Godot Engine](https://godotengine.org) and Rust for high performance.**

**Applications:**
- AI development and debugging
- Educational neuroscience demonstrations
- Research in neuromorphic computing
- Real-time monitoring of learning agents

---

## Quick Start

### Install Brain Visualizer

```bash
pip install feagi-bv
```

That's it! Brain Visualizer binaries are now installed.

### Launch Brain Visualizer

```bash
# Make sure FEAGI is running first, then:
feagi bv start --config feagi_configuration.toml
```

Brain Visualizer will open and connect to your FEAGI instance automatically.

### Watch the Tutorial

Learn how to use Brain Visualizer: [Video Tutorial](https://youtu.be/hH1KYexMQsA)

---

## Alternative Deployment Options

### NeuroRobotics Studio (Cloud)

The fastest way to get started - no installation needed!

[Launch NeuroRobotics Studio](https://brainsforrobots.com)

### FEAGI Desktop (All-in-One)

Download the complete FEAGI suite with Brain Visualizer integrated:

[Download FEAGI Desktop](https://feagi.org/download)

---

<details>
<summary><b>Advanced Usage</b></summary>

## Python API

Control Brain Visualizer programmatically:

```python
from feagi_bv import BrainVisualizer

bv = BrainVisualizer()
bv.load_config("feagi_configuration.toml")
pid = bv.start()

# Launch with custom settings
bv.start(fullscreen=True, debug=True)
```

## Platform-Specific Packages

The `feagi-bv` package automatically installs the correct platform-specific binaries:

- **Linux**: `feagi-bv-linux` (x86_64)
- **macOS**: `feagi-bv-macos` (Universal: Intel + Apple Silicon)
- **Windows**: `feagi-bv-windows` (x86_64)

You can also install platform packages directly:

```bash
pip install feagi-bv-macos  # macOS only
pip install feagi-bv-linux  # Linux only
pip install feagi-bv-windows  # Windows only
```

## Development & Building

### Prerequisites

- [Godot 4.2.2](https://godotengine.org/download/archive/4.2.2-stable/)
- Rust toolchain (for Rust extensions)
- Running FEAGI instance

### Open in Godot Editor

```bash
git clone https://github.com/feagi/brain-visualizer.git
cd brain-visualizer

# Open in Godot
godot --path godot_source --editor
```

### Build Distribution Packages

See [DEPLOY.md](DEPLOY.md) for detailed build instructions.

### Architecture

See developer documentation: [Architecture.md](docs/Architecture.md)

## Shared Memory Video Preview (Desktop Only)

Advanced feature for displaying live video feeds inside Brain Visualizer without routing through FEAGI.

### 1. Build the Rust Extension

**macOS (Universal - Apple Silicon + Intel):**

```bash
cd rust_extensions/feagi_shared_video
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo build --target aarch64-apple-darwin
cargo build --target x86_64-apple-darwin
lipo -create -output target/universal_debug.dylib \
  target/aarch64-apple-darwin/debug/libfeagi_shared_video.dylib \
  target/x86_64-apple-darwin/debug/libfeagi_shared_video.dylib
cp target/universal_debug.dylib \
  ../../godot_source/addons/feagi_shared_video/target/debug/libfeagi_shared_video.dylib
```

**Windows:**

```bash
cd rust_extensions\feagi_shared_video
cargo build
copy target\debug\feagi_shared_video.dll ..\..\godot_source\addons\feagi_shared_video\target\debug\
```

**Linux:**

```bash
cd rust_extensions/feagi_shared_video
cargo build
cp target/debug/libfeagi_shared_video.so \
  ../../godot_source/addons/feagi_shared_video/target/debug/
```

### 2. Run Video Agent with Shared Memory

```bash
# From your video agent directory
python agent.py --webcam --shared-mem --shared-mem-path /tmp/feagi_video_shm.bin
```

### 3. View in Brain Visualizer

1. Open Brain Visualizer
2. Top menu: **View Previews**
3. Enter shared memory path: `/tmp/feagi_video_shm.bin`
4. Click **Open SHM**
5. Video feed should appear

**Troubleshooting:**
- Launch Godot from terminal to see logs:
  ```bash
  open -a Godot --args --path /path/to/brain-visualizer/godot_source --verbose
  ```
- Verify the `.gdextension` library paths match your build output
- Ensure the video agent is running and writing to the same path

</details>

---

## Documentation

- [Getting Started](https://docs.feagi.org/brain-visualizer)
- [Video Tutorial](https://youtu.be/hH1KYexMQsA)
- [Developer Guide](docs/Architecture.md)
- [Build Instructions](DEPLOY.md)

---

## Community & Support

Join our community and get help:

- **Discord**: [Join conversation](https://discord.gg/PTVC8fyGN8)
- **YouTube**: [@Neuraville](https://www.youtube.com/@Neuraville)
- **Twitter/X**: [@neuraville](https://x.com/neuraville)
- **LinkedIn**: [FEAGI Group](https://www.linkedin.com/groups/12777894/)
- **Issues**: [Report bugs](https://github.com/feagi/brain-visualizer/issues)

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](https://github.com/feagi/feagi/blob/staging/CONTRIBUTING.md).

For Brain Visualizer development:
1. Download [Godot 4.2.2](https://godotengine.org/download/archive/4.2.2-stable/)
2. Clone this repository
3. Open `godot_source/project.godot` in Godot
4. Ensure you have a running FEAGI instance

See [Architecture.md](docs/Architecture.md) for developer notes.

---

## License

Apache 2.0 - See [LICENSE](https://www.apache.org/licenses/LICENSE-2.0.txt) for details.

**Copyright 2016-2025 Neuraville Inc. All Rights Reserved.**
