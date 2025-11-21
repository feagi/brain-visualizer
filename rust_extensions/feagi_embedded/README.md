# FEAGI Embedded GDExtension

> **Note:** Experimental in-process embedding for development and testing purposes.  
> For production deployments, use the standard standalone configuration.

**Desktop-only Godot extension that embeds FEAGI neural processing engine in-process.**

## Overview

This GDExtension allows FEAGI to run **inside** the Godot application process, eliminating network overhead and enabling microsecond-latency communication between Brain Visualizer and FEAGI.

### Communication Architecture

```
┌──────────────────────────────────────────────┐
│     Brain Visualizer (Godot Process)         │
│                                               │
│  ┌───────────┐         ┌──────────────────┐ │
│  │ GDScript  │◄────FFI─┤ FEAGI Embedded   │ │
│  │           │ (~1μs)  │ (Rust Library)   │ │
│  └───────────┘         └──────────────────┘ │
└──────────────────────────────────────────────┘
```

**No WebSocket, no HTTP for hot-path operations!**

---

## Features

- ⚡ **Microsecond latency** for burst engine control
- 🧠 **Complete FEAGI** - Full neural processing engine embedded
- 🔌 **Zero network overhead** - In-process communication via FFI
- 🖥️ **Desktop-only** - macOS, Windows, Linux (no web support)
- 📊 **Hybrid approach** - HTTP API still available for complex operations

---

## Building

### Prerequisites

- Rust 1.70+ (`rustup install stable`)
- C compiler (Xcode/gcc/MSVC)
- Godot 4.1+

### Quick Build

```bash
cd brain-visualizer/rust_extensions
./build_feagi_embedded.sh
```

**Build time:** 2-5 minutes (compiles entire FEAGI stack)

**Output:**
- `godot_source/addons/feagi_embedded/libfeagi_embedded.dylib` (macOS)
- `godot_source/addons/feagi_embedded/feagi_embedded.dll` (Windows)
- `godot_source/addons/feagi_embedded/libfeagi_embedded.so` (Linux)

---

## GDScript Usage

### Basic Setup

```gdscript
extends Control

var feagi: FeagiEmbedded

func _ready():
    # Check if extension is available
    if not ClassDB.class_exists("FeagiEmbedded"):
        push_error("FEAGI Embedded extension not found!")
        return
    
    # Create instance
    feagi = FeagiEmbedded.new()
    
    # Initialize with defaults
    if feagi.initialize_default():
        print("FEAGI initialized")
        feagi.start()
    else:
        push_error("FEAGI initialization failed")
```

### Hot-Path Operations (FFI - Microsecond Latency)

```gdscript
func _process(delta):
    # Query stats (very fast)
    var running = feagi.is_running()
    var neurons = feagi.get_neuron_count()
    var genome_loaded = feagi.is_genome_loaded()
    
    # Update UI
    $UI/StatusLabel.text = "Running" if running else "Stopped"
    $UI/NeuronLabel.text = str(neurons) + " neurons"

func _on_start_button_pressed():
    feagi.start()  # ~1μs latency

func _on_stop_button_pressed():
    feagi.stop()  # ~1μs latency

func _on_frequency_slider_changed(value: float):
    feagi.set_burst_frequency(value)  # ~1μs latency
```

### Cold-Path Operations (HTTP - Millisecond Latency)

```gdscript
func _on_load_genome_button_pressed():
    # Complex operations use HTTP API
    var api_url = feagi.get_api_url()  # "http://127.0.0.1:8000"
    
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_genome_loaded)
    
    # POST to /v1/genome/load
    var url = api_url + "/v1/genome/load"
    var body = JSON.stringify({"genome_path": selected_file})
    http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

func _on_genome_loaded(result, response_code, headers, body):
    if response_code == 200:
        print("Genome loaded successfully")
    else:
        push_error("Genome load failed")
```

### Cleanup

```gdscript
func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        # Graceful shutdown
        if feagi:
            feagi.shutdown()
        get_tree().quit()
```

---

## API Reference

### Lifecycle Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `initialize_default()` | `bool` | Initialize with embedded defaults |
| `initialize_from_config(path: String)` | `bool` | Initialize from TOML config |
| `shutdown()` | `void` | Graceful shutdown |

### Burst Engine Control (Hot Path)

| Method | Returns | Description |
|--------|---------|-------------|
| `start()` | `bool` | Start burst engine |
| `stop()` | `bool` | Stop burst engine |
| `set_burst_frequency(hz: float)` | `bool` | Set processing frequency |

### Stats (Hot Path)

| Method | Returns | Description |
|--------|---------|-------------|
| `is_running()` | `bool` | Check if burst engine is active |
| `get_neuron_count()` | `int` | Get total neuron count |
| `is_genome_loaded()` | `bool` | Check if genome is loaded |

### HTTP Server Info

| Method | Returns | Description |
|--------|---------|-------------|
| `get_api_url()` | `String` | Get REST API URL |
| `is_http_server_running()` | `bool` | Check if Axum server is active |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `visualization_data` | `(cortical_ids, x, y, z, powers)` | **TODO:** Direct viz data (pending PNS callback) |

---

## Performance

| Operation | Latency | Notes |
|-----------|---------|-------|
| `is_running()` | ~100ns | Lock-free read |
| `start()` / `stop()` | ~1-5μs | FFI call |
| `get_neuron_count()` | ~10μs | Read with lock |
| HTTP API calls | ~1-5ms | For complex ops |

**~1000x faster than WebSocket for hot-path operations!**

---

## Limitations

### Desktop Only
- ❌ **No web export** - WASM can't handle this size/complexity
- ❌ **No mobile** - Memory/battery constraints
- ✅ **macOS, Windows, Linux** - Full support

### Large Binary
- **Size:** ~100-150MB (includes FEAGI + NPU + services)
- **Build time:** 2-5 minutes
- **RAM:** 200-500MB runtime (depends on genome size)

### External Mode Still Available
- BV can **still connect to external FEAGI** (network mode)
- User can choose embedded vs external
- Standalone FEAGI **unaffected**

---

## Troubleshooting

### "FeagiEmbedded class not found"
- Extension not built or not copied to `godot_source/addons/feagi_embedded/`
- Restart Godot after building
- Check `feagi_embedded.gdextension` is in addon directory

### "FEAGI initialization failed"
- Check console for detailed error messages
- Verify `feagi_configuration.toml` if using custom config
- Ensure no port conflicts (default: 8000, 9050-9053)

### Build Errors
- Ensure Rust is up to date: `rustup update`
- Clean and rebuild: `./build_feagi_embedded.sh --clean`
- Check FEAGI library compiles: `cd ../../../feagi && cargo check --lib`

---

## Architecture

### Dependencies

```
feagi_embedded (GDExtension)
└── feagi (Rust library)
    ├── feagi-burst-engine
    ├── feagi-bdu
    ├── feagi-pns
    ├── feagi-services
    ├── feagi-api
    └── 20+ other crates
```

### Standalone vs Embedded

**Standalone Mode (unchanged):**
```bash
./feagi --genome brain.json
# Independent server, remote connections
```

**Embedded Mode (new):**
```gdscript
var feagi = FeagiEmbedded.new()
feagi.initialize_default()
feagi.start()
# In-process, zero network overhead
```

**Both modes coexist!** Existing deployments unaffected.

---

## Documentation

- **Implementation Plan:** `brain-visualizer/docs/FEAGI_EMBEDDING_IMPLEMENTATION_PLAN.md`
- **Architecture Proposal:** `brain-visualizer/docs/FEAGI_EMBEDDED_IN_PROCESS_PROPOSAL.md`
- **FEAGI Library Status:** `feagi/EMBEDDING_STATUS.md`

---

## License

Apache-2.0 (same as FEAGI)

---

**Status:** Phase 2 Complete - GDExtension compiles successfully ✅

**Next:** Phase 3 - Brain Visualizer integration

