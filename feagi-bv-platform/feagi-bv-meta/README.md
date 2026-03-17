# feagi-bv

Python package that bundles **Brain Visualizer** binaries with a simple launcher API.

## Installation

**Most users should install the full FEAGI package instead:**

```bash
pip install feagi  # Includes feagi-core + feagi-bv automatically
```

**Only install feagi-bv directly if:**
- You already have `feagi-core` installed
- You're building custom tooling

```bash
pip install feagi-bv  # Requires feagi-core separately
```

This will automatically install the correct platform-specific package for your system:
- `feagi-bv-linux` on Linux
- `feagi-bv-macos` on macOS
- `feagi-bv-windows` on Windows

## Usage

```python
from feagi_bv import BrainVisualizer

# Create and configure BV launcher
bv = BrainVisualizer()
bv.load_config("feagi_configuration.toml")

# Start BV process
pid = bv.start()
print(f"Brain Visualizer running (PID: {pid})")
```

## Version Mapping

**`feagi-bv` version = BrainVisualizer binary version**

```bash
pip install feagi-bv==2.0.3
# ↑ Installs BrainVisualizer v2.0.3 binaries
```

## Architecture

This is a meta-package that installs platform-specific binaries:
- **feagi-bv-linux**: Linux x86_64 binaries (~50-70 MB)
- **feagi-bv-macos**: macOS universal binaries (~150-200 MB)
- **feagi-bv-windows**: Windows x86_64 binaries (~50-70 MB)

Only the binaries for your platform are downloaded.

## Dependencies

- `feagi-core>=2.1.0` - FEAGI SDK (core package)
- `toml>=0.10.2` - Configuration parsing

## Links

- [Brain Visualizer](https://github.com/feagi/brain-visualizer)
- [FEAGI](https://github.com/Neuraville/FEAGI-2.0)
- [Documentation](https://docs.feagi.org)
