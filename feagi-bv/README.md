# feagi-bv

Python package that bundles **Brain Visualizer** binaries with a simple launcher API.

## What is this?

`feagi-bv` provides a convenient way to install and run Brain Visualizer from Python code, without manual downloads or setup.

```python
from feagi_bv import BrainVisualizer

# Create and configure BV launcher
bv = BrainVisualizer()
bv.load_config("feagi_configuration.toml")

# Start BV process
pid = bv.start()
print(f"Brain Visualizer running (PID: {pid})")
```

## Installation

```bash
# Install with FEAGI
pip install feagi[bv]

# Or install standalone
pip install feagi-bv
```

## What's Included

### Platform Binaries
- **Linux** (x86_64): `BrainVisualizer`
- **macOS** (Universal): `BrainVisualizer.app`
- **Windows** (x86_64): `BrainVisualizer.exe` + dependencies

### Python API
- `BrainVisualizer` class - Launch and manage BV process
- Automatic config parsing from `feagi_configuration.toml`
- Platform detection and binary resolution

## Version Mapping

**`feagi-bv` version = BrainVisualizer binary version**

```bash
pip install feagi-bv==1.3.5
# ↑ Installs BrainVisualizer v1.3.5 binaries
```

## Usage

### Basic Launch

```python
from feagi_bv import BrainVisualizer

bv = BrainVisualizer()
bv.load_config("path/to/feagi_configuration.toml")
pid = bv.start()
```

### With FEAGI Engine

```python
from feagi.engine import FeagiEngine
from feagi_bv import BrainVisualizer

# Start FEAGI engine
engine = FeagiEngine()
engine.load_genome("genome.json")
engine.start()

# Start Brain Visualizer (connects to FEAGI)
bv = BrainVisualizer()
bv.load_config("feagi_configuration.toml")
bv.start()

# Both now running and communicating
```

## Configuration

BrainVisualizer reads connection settings from the FEAGI config file:

```toml
# feagi_configuration.toml

[api]
host = "127.0.0.1"
port = 8000

[websocket]
host = "127.0.0.1"
visualization_port = 9055
```

The `BrainVisualizer` class automatically extracts these settings and launches BV with the correct environment variables.

## Architecture

This package is **published from the brain-visualizer repository**, not from feagi-python-sdk.

```
brain-visualizer/
├── godot_source/          ← BV source code (Godot + Rust)
├── feagi-bv/              ← This package
│   ├── pyproject.toml
│   ├── feagi_bv/
│   │   ├── runtime.py     ← Python launcher
│   │   └── bin/           ← Binaries (populated by CI/CD)
│   │       ├── linux/
│   │       ├── macos/
│   │       └── windows/
└── .github/workflows/
    └── publish-feagi-bv.yml  ← Auto-publishes on BV release
```

When BrainVisualizer releases a new version (e.g., `v1.4.0`):
1. BV binaries are built for all platforms
2. Binaries are packaged into `feagi-bv`
3. Version is updated to `1.4.0`
4. Published to PyPI as `feagi-bv==1.4.0`

## Dependencies

`feagi-bv` depends on the main `feagi` package:

```toml
dependencies = [
    "feagi>=2.0.0",  # Main FEAGI engine
    "toml>=0.10.2",  # Config parsing
]
```

When you install `feagi-bv`, it automatically installs:
- `feagi` (FEAGI engine)
- `feagi-rust-py-libs` (Rust extensions)
- All transitive dependencies

## Binary Distribution

### Lightweight vs Full
- **`feagi`**: Main SDK (~10 MB) + remote FEAGI binaries (separate)
- **`feagi-bv`**: BV launcher (~50-200 MB depending on platform)

### Mode Support
This package bundles **BrainVisualizer Remote** (Mode 2), which connects to a separate FEAGI instance.

For **BrainVisualizer Embedded** (Mode 1, includes FEAGI in-process), download from [GitHub Releases](https://github.com/feagi/brain-visualizer/releases).

## Platform Support

| Platform        | Architecture | Binary Included |
|-----------------|--------------|-----------------|
| Linux           | x86_64       | ✅               |
| macOS           | Universal    | ✅ (arm64+x86)  |
| Windows         | x86_64       | ✅               |

## Troubleshooting

### Binary Not Found
```python
BrainVisualizerLaunchError: BV binary not found: ...
```

**Solution:** Ensure you installed `feagi-bv` for your platform. Try reinstalling:
```bash
pip install --force-reinstall feagi-bv
```

### Config Not Found
```python
FileNotFoundError: Config file not found: feagi_configuration.toml
```

**Solution:** Provide the full path to your FEAGI config:
```python
bv.load_config("/absolute/path/to/feagi_configuration.toml")
```

### Connection Failed
If BV starts but can't connect to FEAGI, verify:
- FEAGI engine is running
- Ports in config match FEAGI's actual ports
- No firewall blocking connections

## Development

To build from source:

```bash
cd brain-visualizer/feagi-bv
python -m build --wheel
```

## License

Apache 2.0 - See [LICENSE](../LICENSE.txt)

## Related Packages

- **`feagi`** - Main FEAGI SDK and engine
- **`feagi-rust-py-libs`** - High-performance Rust extensions
- **BrainVisualizer** - Desktop application (this is just the launcher)

## Links

- [Brain Visualizer Repository](https://github.com/feagi/brain-visualizer)
- [FEAGI Documentation](https://docs.feagi.org)
- [FEAGI SDK](https://github.com/Neuraville/FEAGI-2.0)
