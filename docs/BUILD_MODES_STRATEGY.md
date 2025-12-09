# Brain Visualizer Build Modes Strategy

**Goal:** Support 3 distinct deployment modes with minimal code duplication

---

## Three Target Modes

### Mode 1: Desktop + Embedded FEAGI
```
Single Binary Distribution
┌─────────────────────────────────┐
│  BrainVisualizer.app (macOS)    │
│  ├── Godot Engine + BV          │
│  └── libfeagi_embedded.dylib    │
└─────────────────────────────────┘

- Size: ~200MB
- Requires: Desktop OS (macOS/Windows/Linux)
- FEAGI: In-process (microsecond latency)
- Network: HTTP localhost only (for complex ops)
- Distribution: .dmg, .msi, .AppImage
```

### Mode 2: Desktop + Remote FEAGI
```
Two Separate Processes
┌──────────────┐      Network      ┌────────────┐
│ BrainViz.app │◄────WebSocket────►│ FEAGI      │
│ (50MB)       │    (LAN/Cloud)    │ (Docker)   │
└──────────────┘                   └────────────┘

- Size: ~50MB (no FEAGI embedded)
- Requires: Desktop OS + FEAGI server
- FEAGI: Remote server (network latency)
- Network: WebSocket + HTTP
- Distribution: .dmg, .msi, .AppImage (lightweight)
```

### Mode 3: Web + Remote FEAGI
```
Browser Application
┌──────────────┐      Internet     ┌────────────┐
│ BV (HTML5)   │◄────WebSocket────►│ FEAGI      │
│ (20MB WASM)  │                   │ (Cloud)    │
└──────────────┘                   └────────────┘

- Size: ~20MB (WASM)
- Requires: Modern browser
- FEAGI: Cloud server (internet latency)
- Network: WebSocket + HTTP
- Distribution: Web hosting
```

---

## Build Strategy

### Approach: Godot Export Presets + Runtime Detection

We'll use **Godot export presets** to define different builds, combined with **runtime detection** for intelligent mode selection.

---

## Implementation Plan

### 1. Godot Export Presets

**File:** `godot_source/export_presets.cfg`

```ini
[preset.0]
name="Desktop-Embedded (macOS)"
platform="macOS"
export_filter="all_resources"
include_filter="*.dylib"  # Include FEAGI embedded library
script_export_mode=2      # Compiled GDScript (faster)

[preset.1]
name="Desktop-Remote (macOS)"
platform="macOS"
export_filter="all_resources"
exclude_filter="addons/feagi_embedded/*"  # Exclude embedded FEAGI (saves 13MB)
script_export_mode=2

[preset.2]
name="Web (HTML5)"
platform="Web"
export_filter="all_resources"
exclude_filter="addons/feagi_embedded/*,addons/feagi_rust_deserializer/*"  # No native extensions
script_export_mode=1      # Text scripts (WASM compatibility)
```

**Key differences:**
- **Mode 1:** Includes `feagi_embedded` extension
- **Mode 2:** Excludes `feagi_embedded` extension (smaller download)
- **Mode 3:** Excludes ALL native extensions (web doesn't support them)

---

### 2. Runtime Mode Detection

**File:** `godot_source/Autoload/FeagiModeDetector.gd` (NEW)

```gdscript
extends Node
## Auto-detects and configures FEAGI connection mode
##
## This script runs FIRST (before FeagiCore) and determines:
## 1. Which FEAGI mode to use (embedded vs remote)
## 2. Configuration for that mode
## 3. Feature availability

enum FEAGI_MODE {
    EMBEDDED,        ## Desktop + embedded FEAGI (in-process)
    REMOTE_DESKTOP,  ## Desktop + remote FEAGI (network)
    REMOTE_WEB       ## Web + remote FEAGI (network)
}

var detected_mode: FEAGI_MODE = FEAGI_MODE.REMOTE_WEB
var feagi_embedded_available: bool = false
var config: Dictionary = {}

func _enter_tree():
    # This runs BEFORE _ready() - critical for early detection
    detect_mode()
    apply_configuration()

func detect_mode():
    print("\n🔍 [MODE-DETECTOR] Detecting FEAGI mode...")
    
    # Step 1: Platform detection
    var platform = _detect_platform()
    print("   Platform: ", platform)
    
    # Step 2: Extension availability
    feagi_embedded_available = ClassDB.class_exists("FeagiEmbedded")
    print("   FEAGI Embedded extension: ", "✅ Available" if feagi_embedded_available else "❌ Not available")
    
    # Step 3: User preference (environment override)
    var env_mode = OS.get_environment("FEAGI_MODE")
    
    # Determine mode
    if platform == "web":
        # Web builds CANNOT use embedded
        detected_mode = FEAGI_MODE.REMOTE_WEB
        print("   → Mode: REMOTE_WEB (web builds require remote FEAGI)")
    
    elif platform == "desktop":
        if env_mode == "remote" or env_mode == "external":
            # User forced remote mode
            detected_mode = FEAGI_MODE.REMOTE_DESKTOP
            print("   → Mode: REMOTE_DESKTOP (environment override: FEAGI_MODE=%s)" % env_mode)
        
        elif feagi_embedded_available:
            # Desktop with embedded extension available
            detected_mode = FEAGI_MODE.EMBEDDED
            print("   → Mode: EMBEDDED (in-process, optimal performance)")
        
        else:
            # Desktop without embedded extension
            detected_mode = FEAGI_MODE.REMOTE_DESKTOP
            print("   → Mode: REMOTE_DESKTOP (embedded extension not available)")
    
    else:
        # Mobile or unknown
        detected_mode = FEAGI_MODE.REMOTE_DESKTOP
        print("   → Mode: REMOTE_DESKTOP (fallback)")

func apply_configuration():
    """Apply mode-specific configuration"""
    match detected_mode:
        FEAGI_MODE.EMBEDDED:
            config = {
                "use_embedded": true,
                "api_url": "http://127.0.0.1:8000",
                "ws_host": "127.0.0.1",
                "ws_viz_port": 9050,
                "transport": "embedded_hybrid",  # FFI for hot-path, HTTP for cold-path
                "description": "In-process FEAGI (microsecond latency)"
            }
        
        FEAGI_MODE.REMOTE_DESKTOP:
            # Read from environment or use defaults
            var api_url = OS.get_environment("FEAGI_API_URL")
            if api_url.is_empty():
                api_url = "http://127.0.0.1:8000"
            
            var ws_host = OS.get_environment("FEAGI_WS_HOST")
            if ws_host.is_empty():
                ws_host = "127.0.0.1"
            
            config = {
                "use_embedded": false,
                "api_url": api_url,
                "ws_host": ws_host,
                "ws_viz_port": 9050,
                "transport": "websocket",
                "description": "Remote FEAGI (network, flexible deployment)"
            }
        
        FEAGI_MODE.REMOTE_WEB:
            # Web builds - read from JavaScript URL params
            config = {
                "use_embedded": false,
                "api_url": "",  # Will be populated from URL params
                "ws_host": "",  # Will be populated from URL params
                "ws_viz_port": 9050,
                "transport": "websocket",
                "description": "Remote FEAGI (cloud/server)"
            }
    
    print("\n📋 [MODE-DETECTOR] Configuration:")
    for key in config:
        print("   %s: %s" % [key, config[key]])

func _detect_platform() -> String:
    if OS.has_feature("web"):
        return "web"
    elif OS.has_feature("desktop"):
        return "desktop"
    elif OS.has_feature("mobile"):
        return "mobile"
    else:
        return "unknown"

func get_mode() -> FEAGI_MODE:
    return detected_mode

func is_embedded() -> bool:
    return detected_mode == FEAGI_MODE.EMBEDDED

func is_remote() -> bool:
    return detected_mode != FEAGI_MODE.EMBEDDED

func get_api_url() -> String:
    return config.get("api_url", "http://127.0.0.1:8000")

func get_ws_viz_port() -> int:
    return config.get("ws_viz_port", 9050)
```

---

### 3. Update FeagiCore to Use Mode Detector

**File:** `godot_source/addons/FeagiCoreIntegration/FeagiCore/FeagiCore.gd`

**Changes:**

```gdscript
# At the top of _enter_tree() or _ready()
func _enter_tree():
    # Check mode detector
    var mode = FeagiModeDetector.get_mode()
    
    if mode == FeagiModeDetector.FEAGI_MODE.EMBEDDED:
        # Initialize embedded FEAGI
        _init_embedded_mode()
    else:
        # Use existing network-based connection
        _init_network_mode()
    
    # ... rest of existing initialization ...

func _init_embedded_mode():
    print("🦀 [FEAGICORE] Initializing EMBEDDED mode...")
    
    if not ClassDB.class_exists("FeagiEmbedded"):
        push_error("Embedded mode selected but extension not available!")
        # Fallback to network mode
        _init_network_mode()
        return
    
    # Create embedded FEAGI instance
    var feagi_embedded = ClassDB.instantiate("FeagiEmbedded")
    add_child(feagi_embedded)
    feagi_embedded.name = "FeagiEmbedded"
    
    # Initialize
    if feagi_embedded.initialize_default():
        print("   ✅ Embedded FEAGI initialized")
        print("   HTTP API: ", feagi_embedded.get_api_url())
        
        # Start burst engine
        feagi_embedded.start()
        
        # Store reference
        network._feagi_embedded = feagi_embedded
        
        # Use HTTP API for complex operations (existing BV code works!)
        var api_url = feagi_embedded.get_api_url()
        # Continue with existing connection flow using this URL
    else:
        push_error("Failed to initialize embedded FEAGI")
        # Fallback to network mode
        _init_network_mode()

func _init_network_mode():
    print("🌐 [FEAGICORE] Initializing NETWORK mode...")
    # Existing BV connection code - unchanged!
    # ... existing network initialization ...
```

---

### 4. Update Project Autoloads

**File:** `godot_source/project.godot`

**Add before FeagiCore:**

```ini
[autoload]

FeagiModeDetector="*res://Autoload/FeagiModeDetector.gd"  # NEW - runs first
FeagiCore="*res://addons/FeagiCoreIntegration/FeagiCore/FeagiCore.gd"
BV="*res://BrainVisualizer/BV.gd"
```

**Order matters:** `FeagiModeDetector` must load before `FeagiCore`

---

### 5. Build Configurations

**Three build workflows:**

#### Build 1: Desktop Embedded

```bash
# Step 1: Build FEAGI embedded extension
cd brain-visualizer/rust_extensions
./build_feagi_embedded.sh

# Step 2: Export Godot project
cd ../godot_source
godot --headless --export-release "Desktop-Embedded (macOS)" ../exports/BrainVisualizer-Embedded.app

# Result: ~200MB .app with embedded FEAGI
```

**Files included:**
- ✅ `addons/feagi_embedded/libfeagi_embedded.dylib` (13MB)
- ✅ `addons/feagi_rust_deserializer/libfeagi_data_deserializer.dylib` (3MB)
- ✅ All Godot assets
- ✅ `Autoload/FeagiModeDetector.gd`

**Runtime behavior:**
- Detects embedded extension → Mode 1 (EMBEDDED)
- Starts FEAGI in-process
- Uses FFI for hot-path, HTTP localhost for cold-path
- No external FEAGI required

---

#### Build 2: Desktop Remote

```bash
# Step 1: Skip Rust embedded build (save time)
# (Only build data deserializer if needed)

# Step 2: Export Godot project (exclude feagi_embedded)
cd godot_source
godot --headless --export-release "Desktop-Remote (macOS)" ../exports/BrainVisualizer-Remote.app

# Result: ~50MB .app without embedded FEAGI
```

**Files included:**
- ❌ `addons/feagi_embedded/` (excluded)
- ✅ `addons/feagi_rust_deserializer/libfeagi_data_deserializer.dylib` (3MB)
- ✅ All Godot assets
- ✅ `Autoload/FeagiModeDetector.gd`

**Runtime behavior:**
- No embedded extension found → Mode 2 (REMOTE_DESKTOP)
- Connects to external FEAGI via WebSocket
- User must run FEAGI separately (Docker/binary)
- Existing BV code path (unchanged)

**User workflow:**
```bash
# Terminal 1: Start FEAGI
docker run -p 8000:8000 -p 9050:9050 feagi:latest

# Terminal 2: Launch BV
./BrainVisualizer-Remote.app
# Auto-connects to localhost:8000
```

---

#### Build 3: Web

```bash
# Step 1: Skip ALL Rust native builds
# (Only build WASM deserializer if needed)

# Step 2: Export Godot project for web
cd godot_source
godot --headless --export-release "Web" ../exports/web/

# Result: ~20MB WASM + HTML
```

**Files included:**
- ❌ `addons/feagi_embedded/` (excluded - no native libs in WASM)
- ❌ `addons/feagi_rust_deserializer/` (excluded unless we have WASM version)
- ✅ All Godot assets (compiled to WASM)
- ✅ `Autoload/FeagiModeDetector.gd`

**Runtime behavior:**
- Web platform detected → Mode 3 (REMOTE_WEB)
- Reads FEAGI URL from JavaScript/URL params
- Connects via WebSocket only
- Existing BV web code (unchanged)

**User workflow:**
```bash
# Host the web build
cd exports/web
python -m http.server 8080

# Browser
http://localhost:8080?feagi_url=ws://my-feagi-server.com:9050
```

---

## File Structure

```
brain-visualizer/
├── godot_source/
│   ├── Autoload/
│   │   └── FeagiModeDetector.gd         # NEW - Mode detection (all builds)
│   ├── Utils/
│   │   └── FeagiEmbeddedManager.gd      # NEW - Embedded mode wrapper (Mode 1 only)
│   ├── addons/
│   │   ├── feagi_embedded/              # Mode 1 only (desktop embedded)
│   │   │   ├── libfeagi_embedded.dylib
│   │   │   └── feagi_embedded.gdextension
│   │   ├── feagi_rust_deserializer/     # Modes 1 & 2 (desktop)
│   │   │   └── libfeagi_data_deserializer.dylib
│   │   └── FeagiCoreIntegration/        # All modes
│   │       └── FeagiCore/
│   │           ├── FeagiCore.gd         # Updated with mode support
│   │           └── Networking/
│   │               └── FEAGINetworking.gd  # Existing network code
│   └── export_presets.cfg               # NEW - Defines 3 export configurations
├── rust_extensions/
│   ├── feagi_embedded/                  # Mode 1 only
│   │   └── ... (built conditionally)
│   └── feagi_data_deserializer/         # Modes 1 & 2
│       └── ... (always built for desktop)
└── exports/                             # Build outputs
    ├── BrainVisualizer-Embedded.app     # Mode 1 (~200MB)
    ├── BrainVisualizer-Remote.app       # Mode 2 (~50MB)
    └── web/                             # Mode 3 (~20MB)
        ├── index.html
        └── BrainVisualizer.wasm
```

---

## Code Architecture

### Conditional Features (Compile-Time)

**NO** - We want runtime detection, not compile-time.

**Reason:** Single codebase, multiple export presets. Godot handles exclusions.

### Runtime Detection (Recommended)

```gdscript
# FeagiModeDetector._enter_tree()
func detect_mode():
    if OS.has_feature("web"):
        # Definitely web mode
        mode = REMOTE_WEB
    
    elif OS.has_feature("desktop"):
        if ClassDB.class_exists("FeagiEmbedded"):
            # Extension present - check user preference
            if prefer_remote():  # Check env var or settings file
                mode = REMOTE_DESKTOP
            else:
                mode = EMBEDDED  # Use embedded if available
        else:
            # No extension - must use remote
            mode = REMOTE_DESKTOP
    
    else:
        # Mobile or unknown - use remote
        mode = REMOTE_DESKTOP
```

---

## Configuration Management

### Mode-Specific Settings

**File:** `godot_source/feagi_modes.json` (NEW)

```json
{
  "embedded": {
    "api_url": "http://127.0.0.1:8000",
    "ws_viz_port": 9050,
    "use_ffi_hot_path": true,
    "description": "In-process FEAGI with microsecond latency"
  },
  "remote_desktop": {
    "api_url": "http://127.0.0.1:8000",
    "ws_viz_port": 9050,
    "use_ffi_hot_path": false,
    "description": "Network connection to local/LAN FEAGI server"
  },
  "remote_web": {
    "api_url": "",
    "ws_viz_port": 9050,
    "use_ffi_hot_path": false,
    "description": "Network connection to cloud FEAGI server"
  }
}
```

### User Overrides

**Desktop:** Environment variables
```bash
# Force remote mode even if embedded is available
export FEAGI_MODE=remote
export FEAGI_API_URL=http://192.168.1.100:8000
export FEAGI_WS_HOST=192.168.1.100
```

**Web:** URL parameters
```
https://bv.example.com/?feagi_url=wss://feagi.example.com:9050&api_url=https://feagi.example.com/api
```

**All platforms:** Settings file
```
user://feagi_connection_settings.json
{
  "mode": "remote",  # "embedded", "remote", or "auto"
  "api_url": "http://custom-server:8000"
}
```

---

## Build Scripts

### Master Build Script

**File:** `brain-visualizer/build_all_modes.sh` (NEW)

```bash
#!/bin/bash
# Build all 3 BV deployment modes

set -e

echo "========================================="
echo "  Building All Brain Visualizer Modes"
echo "========================================="

# Mode 1: Desktop Embedded
echo -e "\n📦 Building Mode 1: Desktop Embedded..."
cd rust_extensions
./build_feagi_embedded.sh
cd ../godot_source
godot --headless --export-release "Desktop-Embedded (macOS)" ../exports/BrainVisualizer-Embedded.app
echo "✅ Mode 1 complete: exports/BrainVisualizer-Embedded.app (~200MB)"

# Mode 2: Desktop Remote
echo -e "\n📦 Building Mode 2: Desktop Remote..."
# No Rust build needed (reuse data deserializer from Mode 1)
godot --headless --export-release "Desktop-Remote (macOS)" ../exports/BrainVisualizer-Remote.app
echo "✅ Mode 2 complete: exports/BrainVisualizer-Remote.app (~50MB)"

# Mode 3: Web
echo -e "\n📦 Building Mode 3: Web (HTML5)..."
godot --headless --export-release "Web" ../exports/web/index.html
echo "✅ Mode 3 complete: exports/web/ (~20MB)"

echo -e "\n========================================="
echo "✅ All modes built successfully!"
echo "========================================="
echo ""
echo "Distribution packages:"
echo "  1. BrainVisualizer-Embedded.app - Desktop with embedded FEAGI"
echo "  2. BrainVisualizer-Remote.app   - Desktop for remote FEAGI"
echo "  3. exports/web/                 - Web build"
```

### Individual Build Scripts

**Mode 1:**
```bash
./build_embedded.sh
# Builds Rust + exports Mode 1
```

**Mode 2:**
```bash
./build_remote_desktop.sh
# Exports Mode 2 only (no Rust)
```

**Mode 3:**
```bash
./build_web.sh
# Exports Mode 3 only (web)
```

---

## Testing Strategy

### Test Each Mode Independently

**Mode 1 Test:**
```bash
# 1. Build
./build_embedded.sh

# 2. Run
./exports/BrainVisualizer-Embedded.app

# 3. Verify
# - Console shows "Mode: EMBEDDED"
# - No external FEAGI needed
# - Stats update in real-time
# - Visualization works
```

**Mode 2 Test:**
```bash
# 1. Build
./build_remote_desktop.sh

# 2. Start FEAGI
docker run -p 8000:8000 -p 9050:9050 feagi:latest

# 3. Run BV
./exports/BrainVisualizer-Remote.app

# 4. Verify
# - Console shows "Mode: REMOTE_DESKTOP"
# - Connects to localhost:8000
# - Visualization works via WebSocket
```

**Mode 3 Test:**
```bash
# 1. Build
./build_web.sh

# 2. Host web build
cd exports/web && python -m http.server 8080

# 3. Start FEAGI (with CORS enabled)
./feagi --genome brain.json

# 4. Open browser
http://localhost:8080?feagi_url=ws://localhost:9050

# 5. Verify
# - Console shows "Mode: REMOTE_WEB"
# - Connects via WebSocket
# - Visualization works
```

---

## Distribution Strategy

### Mode 1: Premium Desktop App

**Target users:** Non-technical users, demos, offline use

**Distribution:**
- **macOS:** `.dmg` installer (~200MB)
- **Windows:** `.msi` installer (~180MB)
- **Linux:** `.AppImage` (~190MB)

**Value proposition:**
- One-click install
- No Docker, no Python, no setup
- Works offline
- Fastest performance

**Pricing:** Premium (includes embedded FEAGI)

---

### Mode 2: Lightweight Desktop Client

**Target users:** Developers, power users, multi-agent setups

**Distribution:**
- **macOS:** `.dmg` installer (~50MB)
- **Windows:** `.msi` installer (~45MB)
- **Linux:** `.AppImage` (~50MB)

**Value proposition:**
- Small download
- Connect to shared FEAGI
- Multiple BV instances can connect to one FEAGI
- Flexible deployment

**Pricing:** Standard (free or lower tier)

---

### Mode 3: Web Application

**Target users:** Cloud users, demos, accessibility

**Distribution:**
- **Hosting:** Static web hosting
- **CDN:** CloudFlare, AWS S3
- **Size:** ~20MB WASM + assets

**Value proposition:**
- No installation
- Works on any modern browser
- Cloud FEAGI integration
- Easy sharing/demos

**Pricing:** Free tier or subscription

---

## Code Changes Required

### Minimal Changes to Existing BV Code

The beauty of this approach: **Existing BV code works for all 3 modes!**

**Changes needed:**
1. ✅ Create `FeagiModeDetector.gd` (new, 100 lines)
2. ✅ Create `FeagiEmbeddedManager.gd` (already done, 210 lines)
3. 📝 Update `FeagiCore.gd` (add mode initialization, ~50 lines)
4. 📝 Update `project.godot` (add autoload)
5. 📝 Create export presets (new file)
6. 📝 Create build scripts (new files)

**No changes needed:**
- ❌ `FEAGINetworking.gd` - Works for all modes
- ❌ `FEAGIRequests.gd` - HTTP works for all modes
- ❌ UI scripts - Work for all modes
- ❌ BrainMonitor3D - Works for all modes

---

## Feature Matrix

| Feature | Mode 1 (Embedded) | Mode 2 (Remote Desktop) | Mode 3 (Web) |
|---------|------------------|------------------------|--------------|
| **Platform** | Desktop only | Desktop only | Any (browser) |
| **FEAGI Location** | In-process | Separate server | Cloud server |
| **Install Size** | ~200MB | ~50MB | ~20MB |
| **Network Required** | No | LAN/Local | Yes (internet) |
| **Setup** | None | Start FEAGI separately | FEAGI hosted |
| **Performance (hot-path)** | ⚡ ~1μs | 🔷 ~100μs | 🌐 ~10-100ms |
| **Offline Capable** | ✅ Yes | ⚠️ Requires local FEAGI | ❌ No |
| **Multi-Client** | ❌ Single BV | ✅ Multiple BVs | ✅ Multiple BVs |
| **GPU Acceleration** | ✅ Direct | ✅ Via FEAGI | ✅ Via FEAGI |
| **Rust Extensions** | ✅ All | ✅ Data deserializer | ❌ None (WASM) |

---

## Build Matrix (CI/CD)

### GitHub Actions Workflow

```yaml
name: Build All Modes

on:
  push:
    branches: [main, develop]

jobs:
  build-mode1-macos:
    name: Mode 1 - Desktop Embedded (macOS)
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Rust
        uses: actions-rust-lang/setup-rust-toolchain@v1
      - name: Build FEAGI embedded
        run: cd rust_extensions && ./build_feagi_embedded.sh
      - name: Export Godot
        run: godot --export-release "Desktop-Embedded (macOS)" BV-Embedded.app
      - name: Create DMG
        run: ./scripts/create_dmg.sh
      - name: Upload
        uses: actions/upload-artifact@v3
        with:
          name: BrainVisualizer-Embedded-macOS
          path: BrainVisualizer-Embedded.dmg

  build-mode2-macos:
    name: Mode 2 - Desktop Remote (macOS)
    runs-on: macos-latest
    steps:
      # Similar but skip feagi_embedded build

  build-mode3-web:
    name: Mode 3 - Web (HTML5)
    runs-on: ubuntu-latest
    steps:
      # Web export only, no Rust

  # Repeat for Windows and Linux
```

---

## Configuration Files

### Export Presets

**File:** `godot_source/export_presets.cfg`

```ini
[preset.0]
name="Desktop-Embedded (macOS)"
platform="macOS"
runnable=true
export_filter="resources"
include_filter="*.dylib,*.gdextension"
exclude_filter=""
custom_features=""

[preset.0.options]
application/icon=""
application/bundle_identifier="com.neuraville.brainvisualizer.embedded"

[preset.1]
name="Desktop-Remote (macOS)"
platform="macOS"
runnable=true
export_filter="resources"
include_filter="*.dylib,*.gdextension"
exclude_filter="addons/feagi_embedded/*"  # Exclude embedded FEAGI

[preset.1.options]
application/bundle_identifier="com.neuraville.brainvisualizer"

[preset.2]
name="Web"
platform="Web"
runnable=true
export_filter="resources"
exclude_filter="addons/feagi_embedded/*,addons/feagi_rust_deserializer/*"  # No native libs

[preset.2.options]
vram_texture_compression/for_desktop=true
html/export_icon=true
```

---

## User Experience

### Mode 1: Embedded (Premium UX)

```
User downloads: BrainVisualizer-Embedded.dmg (200MB)
User installs: Drag to Applications
User launches: Double-click icon

BV launches:
  → Detects embedded extension
  → Starts FEAGI in-process
  → Shows "FEAGI Embedded Mode - Ready!"
  → User clicks "Load Genome"
  → Brain visualizes immediately
  
No setup, no configuration, just works!
```

### Mode 2: Remote Desktop (Developer UX)

```
User downloads: BrainVisualizer-Remote.dmg (50MB)
User installs: Drag to Applications

Terminal 1:
  $ docker run -p 8000:8000 -p 9050:9050 feagi:latest

Terminal 2:
  User launches: Double-click BV icon
  
BV launches:
  → No embedded extension found
  → Shows "Connecting to FEAGI..."
  → Connects to localhost:8000
  → Shows "Connected to Remote FEAGI"
  → User clicks "Load Genome"
  → Brain visualizes
```

### Mode 3: Web (Cloud UX)

```
User visits: https://brainvisualizer.neuraville.com
Browser loads: WASM (~20MB)

BV launches:
  → Detects web platform
  → Reads FEAGI URL from page config
  → Shows "Connecting to FEAGI Cloud..."
  → Connects via WebSocket
  → Shows "Connected"
  → User selects genome from library
  → Brain visualizes
```

---

## Next Steps

### Implementation Order

1. **Create `FeagiModeDetector.gd`** (100 lines)
2. **Update `project.godot`** (add autoload)
3. **Update `FeagiCore.gd`** (add mode initialization, ~50 lines)
4. **Create export presets** (`export_presets.cfg`)
5. **Create build scripts** (3 scripts)
6. **Test each mode** (verify all work)
7. **Documentation** (user guides for each mode)

### Testing Checklist

- [ ] Mode 1: Build and test embedded
- [ ] Mode 2: Build and test remote desktop
- [ ] Mode 3: Build and test web
- [ ] Mode switching: Test env var overrides
- [ ] Fallback: Test embedded → remote fallback

---

## Summary

**Strategy:** Runtime detection + Godot export presets

**Benefits:**
- ✅ Single codebase
- ✅ Minimal code changes
- ✅ All 3 modes supported
- ✅ Existing BV code works unchanged
- ✅ User can choose mode via settings/env
- ✅ Automatic fallback (embedded → remote)
- ✅ Optimized builds (exclude unused components)

**Distribution:**
- **Mode 1:** ~200MB (premium, embedded)
- **Mode 2:** ~50MB (lightweight, remote)
- **Mode 3:** ~20MB (web, cloud)

**Code Changes:** < 200 lines total (mostly new files)

---

**Ready to implement?** I can start with `FeagiModeDetector.gd` and export presets! 🚀

