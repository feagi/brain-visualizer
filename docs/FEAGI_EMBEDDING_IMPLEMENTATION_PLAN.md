# FEAGI Embedding Implementation Plan

**Approach:** Hybrid (Option 1)  
**Status:** In Progress  
**Started:** November 5, 2025

---

## Architecture Summary

```
┌────────────────────────────────────────────────────┐
│              BV (Single Process)                   │
│                                                     │
│  ┌──────────────┐         ┌──────────────────┐   │
│  │  GDScript    │         │  FEAGI (Rust)    │   │
│  │              │         │                  │   │
│  │  ❶ Viz      │◄────────┤  Direct Callback │   │
│  │     Data    │  FFI    │  (~1-10μs)       │   │
│  │              │         │                  │   │
│  │  ❷ Hot Path │◄────────┤  15 FFI Methods  │   │
│  │     APIs    │  FFI    │  (~1-5μs)        │   │
│  │              │         │                  │   │
│  │  ❸ Cold     │         │  HTTP Server     │   │
│  │     Path    ├────────►│  :8000           │   │
│  │     APIs    │  HTTP   │  (existing)      │   │
│  └──────────────┘         └──────────────────┘   │
└────────────────────────────────────────────────────┘
```

### Communication Channels

| Channel | Protocol | Latency | Usage |
|---------|----------|---------|-------|
| ❶ Visualization | Direct callback | ~1-10μs | Neuron fire data (every burst) |
| ❂ Hot Path API | FFI | ~1-5μs | Burst control, real-time stats |
| ❸ Cold Path API | HTTP | ~1-5ms | Genome load, analytics, CRUD |

---

## Implementation Phases

### Phase 1: FEAGI Library Crate (2 weeks)

**Goal:** Convert FEAGI from binary-only to hybrid library+binary.

#### 1.1 Update Cargo.toml

**File:** `feagi/Cargo.toml`

**Changes:**
- Add `[lib]` section
- Add `embedded` and `no-network` features
- Make `clap` optional (CLI only)

**Status:** ⏳ Pending

---

#### 1.2 Create lib.rs

**File:** `feagi/src/lib.rs`

**Contents:**
- Public `FeagiInstance` struct
- Initialization methods
- Hot-path API methods (~15 total)
- Visualization callback registration
- Internal component wiring

**Hot-Path Methods to Expose:**
```rust
// Lifecycle
pub fn new(config: FeagiConfig) -> Result<Self>
pub fn initialize(&mut self) -> Result<()>
pub fn shutdown(&self) -> Result<()>

// Burst Engine Control
pub fn start(&self) -> Result<()>
pub fn stop(&self) -> Result<()>
pub fn pause(&self) -> Result<()>
pub fn set_burst_frequency(&self, hz: f64) -> Result<()>

// Real-Time Stats (read-only)
pub fn get_burst_counter(&self) -> u64
pub fn is_running(&self) -> bool
pub fn get_neuron_count(&self) -> Result<usize>
pub fn get_synapse_count(&self) -> Result<usize>
pub fn get_current_timestep(&self) -> f64

// Simple Queries
pub fn get_cortical_area_ids(&self) -> Vec<String>
pub fn is_genome_loaded(&self) -> bool

// HTTP Server Info
pub fn get_api_url(&self) -> String
pub fn is_http_server_running(&self) -> bool

// Visualization Callback
pub fn set_visualization_callback(&self, callback: VisualizationCallback)
```

**Status:** ⏳ Pending

---

#### 1.3 Add Callback Support to PNS

**File:** `feagi-core/crates/feagi-pns/src/lib.rs`

**Changes:**
```rust
pub struct PNS {
    // ... existing fields ...
    viz_callback: Arc<Mutex<Option<VisualizationCallback>>>,
}

impl PNS {
    pub fn set_visualization_callback<F>(&self, callback: F)
    where
        F: Fn(&RawFireQueueSnapshot) + Send + Sync + 'static,
    {
        *self.viz_callback.lock() = Some(Box::new(callback));
    }
    
    pub fn publish_raw_fire_queue(&self, fire_data: RawFireQueueSnapshot) -> Result<()> {
        // Priority 1: Direct callback (embedded mode)
        if let Some(ref callback) = *self.viz_callback.lock() {
            callback(&fire_data);
            return Ok(());
        }
        
        // Priority 2: Network transports (standalone mode)
        // ... existing ZMQ/WebSocket publishing ...
    }
}
```

**Status:** ⏳ Pending

---

#### 1.4 Update main.rs

**File:** `feagi/src/main.rs`

**Changes:**
- Use `feagi::FeagiInstance` instead of internal components
- Keep all CLI logic
- Simplify to ~100 lines

**New structure:**
```rust
use feagi::{FeagiInstance, load_config};

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();
    let config = load_config(args.config.as_deref(), None)?;
    
    let mut feagi = FeagiInstance::new(config)?;
    feagi.initialize()?;
    
    if let Some(genome) = args.genome {
        feagi.load_genome(genome.to_str().unwrap())?;
    }
    
    feagi.start()?;
    
    // Wait for Ctrl+C
    tokio::signal::ctrl_c().await?;
    feagi.shutdown()?;
    
    Ok(())
}
```

**Status:** ⏳ Pending

---

### Phase 2: FEAGI GDExtension (2 weeks)

**Goal:** Create Godot extension that wraps FEAGI library.

#### 2.1 Create Extension Crate

**Location:** `brain-visualizer/rust_extensions/feagi_embedded/`

**Structure:**
```
feagi_embedded/
├── Cargo.toml
├── src/
│   └── lib.rs
├── feagi_embedded.gdextension
└── build.rs
```

**Cargo.toml:**
```toml
[package]
name = "feagi_embedded"
version = "2.0.0"
edition = "2021"

[dependencies]
godot = { git = "https://github.com/godot-rust/gdext", branch = "master" }
feagi = { path = "../../../../feagi", default-features = false, features = ["embedded"] }
feagi-config = { path = "../../../../feagi-core/crates/feagi-config" }
feagi-burst-engine = { path = "../../../../feagi-core/crates/feagi-burst-engine" }
feagi-data-structures = { path = "../../../../feagi-core/crates/feagi-data-structures" }

anyhow = "1.0"
parking_lot = "0.12"

[lib]
crate-type = ["cdylib"]
```

**Status:** ⏳ Pending

---

#### 2.2 Implement GDExtension

**File:** `feagi_embedded/src/lib.rs`

**Key components:**
1. `FeagiEmbedded` class (exposed to Godot)
2. All 15 hot-path methods as `#[func]`
3. `visualization_data` signal
4. Callback handler that emits signal

**Methods to implement:**
```rust
#[godot_api]
impl FeagiEmbedded {
    // Lifecycle
    #[func] fn initialize_default(&mut self) -> bool
    #[func] fn initialize_from_config(&mut self, path: GString) -> bool
    #[func] fn shutdown(&self)
    
    // Burst Control
    #[func] fn start(&self) -> bool
    #[func] fn stop(&self) -> bool
    #[func] fn pause(&self) -> bool
    #[func] fn set_burst_frequency(&self, hz: f64) -> bool
    
    // Real-Time Stats
    #[func] fn get_burst_counter(&self) -> i64
    #[func] fn is_running(&self) -> bool
    #[func] fn get_neuron_count(&self) -> i64
    #[func] fn get_synapse_count(&self) -> i64
    #[func] fn get_current_timestep(&self) -> f64
    
    // Simple Queries
    #[func] fn get_cortical_area_ids(&self) -> PackedStringArray
    #[func] fn is_genome_loaded(&self) -> bool
    
    // HTTP Server Info
    #[func] fn get_api_url(&self) -> GString
    #[func] fn is_http_server_running(&self) -> bool
    
    // Signal
    #[signal]
    fn visualization_data(
        cortical_ids: PackedStringArray,
        x: PackedInt32Array,
        y: PackedInt32Array,
        z: PackedInt32Array,
        powers: PackedFloat32Array,
    );
}
```

**Status:** ⏳ Pending

---

#### 2.3 Update Build Scripts

**File:** `brain-visualizer/rust_extensions/build.py`

**Add:**
```python
def build_feagi_embedded():
    print("\n" + "="*80)
    print("Building FEAGI Embedded Extension")
    print("="*80 + "\n")
    
    os.chdir("feagi_embedded")
    
    # Build release
    result = run_command(["cargo", "build", "--release"])
    
    if result:
        # Copy to Godot
        lib_name = f"libfeagi_embedded{get_library_extension()}"
        src = Path("target/release") / lib_name
        dest = Path("../../godot_source/addons/feagi_embedded") / lib_name
        
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        print(f"✅ Copied {lib_name}")
        
        # Copy .gdextension file
        shutil.copy2("feagi_embedded.gdextension", dest.parent)
    
    os.chdir("..")
    return result

# Add to main()
if __name__ == "__main__":
    # ... existing builds ...
    build_feagi_embedded()
```

**Status:** ⏳ Pending

---

### Phase 3: BV Integration (1 week)

**Goal:** Update Brain Visualizer to use embedded FEAGI.

#### 3.1 Create FEAGI Manager

**File:** `brain-visualizer/godot_source/Utils/FeagiEmbeddedManager.gd`

**Purpose:**
- Detect if embedded FEAGI is available
- Initialize and manage FEAGI lifecycle
- Provide unified API for rest of BV

**Key methods:**
```gdscript
func detect_feagi_mode() # Embedded vs external
func initialize() -> bool
func start() -> bool
func load_genome(path: String) -> bool
func get_api_url() -> String
```

**Status:** ⏳ Pending

---

#### 3.2 Update Main Scene

**File:** `brain-visualizer/godot_source/FEAGI_BrainVisualizer.gd`

**Changes:**
1. Instantiate `FeagiEmbedded`
2. Connect `visualization_data` signal
3. Update UI controls to use FFI methods
4. Keep HTTP for complex operations

**Example:**
```gdscript
var feagi: FeagiEmbedded

func _ready():
    feagi = FeagiEmbedded.new()
    feagi.visualization_data.connect(_on_viz_data)
    feagi.initialize_default()
    feagi.start()

func _process(delta):
    # HOT PATH: Direct FFI (every frame)
    $UI/BurstLabel.text = str(feagi.get_burst_counter())
    $UI/NeuronLabel.text = str(feagi.get_neuron_count())

func _on_viz_data(ids, x, y, z, p):
    # HOT PATH: Direct callback
    $BrainMonitor3D.update_neurons(ids, x, y, z, p)

func _on_load_genome():
    # COLD PATH: HTTP API
    var http = HTTPRequest.new()
    http.request(feagi.get_api_url() + "/v1/genome/load", ...)
```

**Status:** ⏳ Pending

---

#### 3.3 Wire Visualization

**File:** `brain-visualizer/godot_source/BrainMonitor3D.gd`

**No changes needed!** The existing `update_neurons()` method already accepts arrays.

**Status:** ⏳ Pending

---

#### 3.4 Update UI Controls

**Files:**
- `godot_source/UI/ControlPanel.gd`
- `godot_source/UI/StatsPanel.gd`

**Changes:**
- Replace `HTTPRequest` calls with direct FFI for:
  - Start/stop/pause
  - Burst frequency
  - Real-time stats
- Keep HTTP for:
  - Genome loading
  - Analytics queries
  - Settings

**Status:** ⏳ Pending

---

## Testing Strategy

### Unit Tests
- [ ] Test `FeagiInstance` initialization
- [ ] Test hot-path methods return correct values
- [ ] Test visualization callback fires

### Integration Tests
- [ ] Test FEAGI + Godot lifecycle
- [ ] Test visualization data flow
- [ ] Test HTTP server still works
- [ ] Test simultaneous FFI + HTTP calls

### Performance Tests
- [ ] Measure visualization callback latency
- [ ] Measure FFI method call latency
- [ ] Compare vs current WebSocket implementation
- [ ] Verify zero-copy where possible

### Platform Tests
- [ ] macOS (Intel + Apple Silicon)
- [ ] Windows x86_64
- [ ] Linux x86_64

---

## Milestones

| Milestone | ETA | Deliverables |
|-----------|-----|--------------|
| **M1: FEAGI Library** | Week 2 | `feagi` crate with public API, tests pass |
| **M2: GDExtension** | Week 4 | `feagi_embedded` builds, basic Godot test works |
| **M3: BV Integration** | Week 5 | BV connects to embedded FEAGI, visualization works |
| **M4: Polish & Test** | Week 6 | All platforms tested, performance validated |

---

## Success Criteria

- ✅ BV launches with embedded FEAGI (single process)
- ✅ Visualization data flows via direct callback (<10μs latency)
- ✅ Hot-path FFI methods work (<5μs latency)
- ✅ HTTP API still works for complex operations
- ✅ All existing BV features work
- ✅ Single-binary distribution for macOS/Windows/Linux
- ✅ Performance 50-100x better than WebSocket for hot paths

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| GDExtension threading issues | High | Use proper Arc/Mutex, test thoroughly |
| FEAGI crashes crash BV | High | Add error boundaries, graceful degradation |
| Memory leaks | Medium | Profile with Valgrind, fix leaks |
| Platform-specific bugs | Medium | CI/CD for all platforms |
| Performance regression | Low | Benchmark suite, compare to baseline |

---

## Next Steps

1. ✅ **Phase 1.1:** Update `feagi/Cargo.toml` (add lib config)
2. ⏳ **Phase 1.2:** Create `feagi/src/lib.rs` (basic structure)
3. ⏳ **Phase 1.3:** Add callback support to PNS
4. ⏳ **Phase 1.4:** Update `main.rs` to use library

**Current Status:** Ready to begin Phase 1.1

---

**Last Updated:** November 5, 2025  
**Next Review:** After Phase 1 completion

