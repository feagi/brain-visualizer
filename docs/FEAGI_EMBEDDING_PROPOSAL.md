# FEAGI Embedding Proposal: Native Integration with Brain Visualizer

## Executive Summary

This proposal outlines a strategy to embed the FEAGI Rust neural processing engine directly into the Brain Visualizer Godot application, enabling single-binary desktop distributions for macOS and Windows without requiring Docker, Python bridges, or separate FEAGI processes.

## Current Architecture

```
┌─────────────────────┐     WebSocket/ZMQ      ┌──────────────────┐
│  Brain Visualizer   │ ◄─────────────────────► │  FEAGI Server    │
│  (Godot + GDScript) │                         │  (Rust Binary)   │
└─────────────────────┘                         └──────────────────┘
         │                                                │
         │ HTTP REST API                                 │
         └───────────────────────────────────────────────┘

- Separate processes
- Docker containerization for distribution
- feagi-bridge for Python agents
- Network communication overhead
```

## Proposed Architecture

```
┌────────────────────────────────────────────────────────────┐
│              Brain Visualizer (Godot Application)          │
│                                                             │
│  ┌──────────────────┐         ┌────────────────────────┐  │
│  │  GDScript UI     │         │  FEAGI GDExtension     │  │
│  │  - 3D Rendering  │ ◄─────► │  (Embedded Rust)       │  │
│  │  - User Controls │         │  - NPU                 │  │
│  │  - Settings      │         │  - Burst Engine        │  │
│  └──────────────────┘         │  - PNS (Internal)      │  │
│                                │  - REST API (Internal) │  │
│                                │  - Connectome Mgr      │  │
│                                └────────────────────────┘  │
└────────────────────────────────────────────────────────────┘

- Single process/binary
- In-memory communication (zero network overhead)
- Native performance
- Simplified distribution
```

## Technical Strategy

### Phase 1: Create FEAGI Library Crate

**Goal:** Convert FEAGI from a binary (`src/main.rs`) to a library (`lib.rs`) with public API.

#### 1.1 Restructure `feagi` Crate

**Location:** `/Users/nadji/code/FEAGI-2.0/feagi/`

**Current:** Binary-only crate with `main.rs`
**Target:** Hybrid crate with both library and binary

**Changes to `Cargo.toml`:**
```toml
[package]
name = "feagi"
version = "2.0.0"
edition = "2021"

[lib]
name = "feagi"
path = "src/lib.rs"
crate-type = ["lib", "cdylib", "staticlib"]  # Support all embedding modes

[[bin]]
name = "feagi"
path = "src/main.rs"
required-features = ["cli"]  # Only build CLI if requested

[features]
default = ["cli"]
cli = ["dep:clap"]
embedded = []  # For library usage (no CLI, no signal handlers)
```

#### 1.2 Create Public API in `src/lib.rs`

```rust
//! # FEAGI Embedded Library
//! 
//! Provides a programmatic interface to FEAGI for embedding in applications.
//! Designed for use with Godot via GDExtension but can be used in any Rust application.

use std::sync::Arc;
use parking_lot::{Mutex, RwLock};
use anyhow::Result;

pub mod config;
pub mod components;
pub mod lifecycle;

pub use feagi_config::{FeagiConfig, load_config};

/// Main FEAGI instance handle
/// 
/// This is the primary interface for embedded FEAGI.
/// All operations are thread-safe.
pub struct FeagiInstance {
    components: Arc<Mutex<Option<FeagiComponents>>>,
    config: FeagiConfig,
    runtime: tokio::runtime::Runtime,
}

impl FeagiInstance {
    /// Create a new FEAGI instance with the given configuration
    /// 
    /// # Arguments
    /// * `config` - FEAGI configuration (from TOML or built programmatically)
    /// 
    /// # Returns
    /// A new FEAGI instance ready to be initialized
    pub fn new(config: FeagiConfig) -> Result<Self> {
        // Create dedicated tokio runtime for FEAGI
        // This ensures FEAGI doesn't interfere with Godot's main thread
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(4)
            .thread_name("feagi-worker")
            .enable_all()
            .build()?;
        
        Ok(Self {
            components: Arc::new(Mutex::new(None)),
            config,
            runtime,
        })
    }
    
    /// Initialize FEAGI components (NPU, PNS, Burst Engine, etc.)
    /// 
    /// This is a heavy operation and should be called once during app startup.
    /// Non-blocking - runs initialization on FEAGI's async runtime.
    pub fn initialize(&self) -> Result<()> {
        let config = self.config.clone();
        let components = self.components.clone();
        
        self.runtime.block_on(async move {
            let initialized = initialize_components(&config, &Default::default()).await?;
            *components.lock() = Some(initialized);
            Ok(())
        })
    }
    
    /// Start FEAGI services (HTTP API, PNS streams, Burst Engine)
    /// 
    /// Non-blocking - services run in background on FEAGI's runtime.
    /// Returns immediately after spawning services.
    pub fn start(&self) -> Result<()> {
        let components = self.components.lock();
        let components = components.as_ref()
            .ok_or_else(|| anyhow::anyhow!("FEAGI not initialized. Call initialize() first."))?;
        
        // Start services on FEAGI's runtime
        self.runtime.spawn(start_services_internal(
            components.clone(),
            self.config.clone(),
        ));
        
        Ok(())
    }
    
    /// Load a genome from a file path
    /// 
    /// # Arguments
    /// * `genome_path` - Path to .brain.json genome file
    /// 
    /// # Returns
    /// Ok(()) if genome loaded successfully
    pub fn load_genome(&self, genome_path: &str) -> Result<()> {
        let components = self.components.lock();
        let components = components.as_ref()
            .ok_or_else(|| anyhow::anyhow!("FEAGI not initialized"))?;
        
        let path = std::path::PathBuf::from(genome_path);
        
        self.runtime.block_on(async {
            load_genome_with_pns(
                &components.connectome_manager,
                &components.pns,
                &path,
            ).await?;
            Ok(())
        })
    }
    
    /// Get the HTTP API base URL
    /// 
    /// This is where the REST API is accessible (e.g., "http://127.0.0.1:8000")
    pub fn get_api_url(&self) -> String {
        format!("http://{}:{}", self.config.api.host, self.config.api.port)
    }
    
    /// Get the WebSocket visualization port
    pub fn get_websocket_viz_port(&self) -> u16 {
        self.config.websocket.visualization_port
    }
    
    /// Check if burst engine is running
    pub fn is_running(&self) -> bool {
        let components = self.components.lock();
        if let Some(ref components) = *components {
            components.burst_runner.read().is_running()
        } else {
            false
        }
    }
    
    /// Shutdown FEAGI gracefully
    /// 
    /// Stops burst engine, closes streams, saves state.
    /// Blocks until shutdown is complete.
    pub fn shutdown(&self) -> Result<()> {
        let components = self.components.lock();
        if let Some(ref components) = *components {
            // Stop burst engine
            components.burst_runner.write().stop();
            
            // Stop PNS streams
            components.pns.stop_all_streams()?;
            
            info!("FEAGI shutdown complete");
        }
        Ok(())
    }
}

// Reuse existing component initialization from main.rs
// These become internal module functions
use crate::components::FeagiComponents;
async fn initialize_components(config: &FeagiConfig, args: &Args) -> Result<FeagiComponents> {
    // ... existing code from main.rs ...
}

async fn start_services_internal(components: FeagiComponents, config: FeagiConfig) -> Result<()> {
    // ... existing code from main.rs without signal handlers ...
}

async fn load_genome_with_pns(...) -> Result<Option<f64>> {
    // ... existing code from main.rs ...
}
```

#### 1.3 Update `src/main.rs` to Use Library

```rust
use feagi::{FeagiInstance, load_config};
use clap::Parser;

#[derive(Parser)]
struct Args {
    // ... existing args ...
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();
    
    // Load configuration
    let config = load_config(args.config.as_deref(), None)?;
    
    // Create and initialize FEAGI instance
    let feagi = FeagiInstance::new(config)?;
    feagi.initialize()?;
    
    // Load genome if provided
    if let Some(genome_path) = args.genome {
        feagi.load_genome(genome_path.to_str().unwrap())?;
    }
    
    // Start services
    feagi.start()?;
    
    // Wait for Ctrl+C
    tokio::signal::ctrl_c().await?;
    
    // Shutdown
    feagi.shutdown()?;
    
    Ok(())
}
```

**Result:** FEAGI can now be used both as a standalone binary and as a library.

---

### Phase 2: Create FEAGI GDExtension

**Goal:** Expose FEAGI library to Godot via GDExtension (similar to existing `feagi_data_deserializer`).

#### 2.1 Create New Crate

**Location:** `/Users/nadji/code/FEAGI-2.0/brain-visualizer/rust_extensions/feagi_embedded/`

**Structure:**
```
feagi_embedded/
├── Cargo.toml
├── src/
│   └── lib.rs
├── feagi_embedded.gdextension
└── build.rs  # For bundling config
```

#### 2.2 `Cargo.toml` Configuration

```toml
[package]
name = "feagi_embedded"
version = "2.0.0"
edition = "2021"

[dependencies]
# Godot Rust bindings
godot = { git = "https://github.com/godot-rust/gdext", branch = "master" }

# FEAGI library (local path during development)
feagi = { path = "../../../../feagi", default-features = false, features = ["embedded"] }

# Required FEAGI core crates
feagi-config = { path = "../../../../feagi-core/crates/feagi-config" }
feagi-types = { path = "../../../../feagi-core/crates/feagi-types" }

# Async runtime (already included by FEAGI, but specify for clarity)
tokio = { version = "1.40", features = ["sync"] }

# Error handling
anyhow = "1.0"

# Logging (bridge to Godot's print)
tracing = "0.1"
tracing-subscriber = "0.3"

[lib]
crate-type = ["cdylib"]

[profile.release]
opt-level = 3
lto = "fat"
codegen-units = 1
strip = true
```

#### 2.3 GDExtension Implementation (`src/lib.rs`)

```rust
use godot::prelude::*;
use godot::classes::{RefCounted, IRefCounted};
use feagi::{FeagiInstance, FeagiConfig, load_config};
use std::sync::{Arc, Mutex};

struct FeagiEmbeddedLib;

#[gdextension]
unsafe impl ExtensionLibrary for FeagiEmbeddedLib {}

/// FEAGI Embedded - Native neural processing engine for Godot
/// 
/// Provides a complete FEAGI instance running inside the Godot application.
/// Suitable for desktop builds (macOS, Windows, Linux).
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct FeagiEmbedded {
    #[base]
    base: Base<RefCounted>,
    
    instance: Arc<Mutex<Option<FeagiInstance>>>,
}

#[godot_api]
impl IRefCounted for FeagiEmbedded {
    fn init(base: Base<RefCounted>) -> Self {
        godot_print!("🦀 FEAGI Embedded v2.0.0 initialized!");
        Self {
            base,
            instance: Arc::new(Mutex::new(None)),
        }
    }
}

#[godot_api]
impl FeagiEmbedded {
    /// Initialize FEAGI with a configuration file
    /// 
    /// # Arguments
    /// * `config_path` - Path to feagi_configuration.toml
    /// 
    /// # Returns
    /// true if initialization succeeded, false otherwise
    #[func]
    fn initialize_from_config(&mut self, config_path: GString) -> bool {
        let path = config_path.to_string();
        godot_print!("📝 Loading FEAGI configuration from: {}", path);
        
        match Self::initialize_internal(&path) {
            Ok(feagi) => {
                godot_print!("✅ FEAGI initialized successfully");
                *self.instance.lock().unwrap() = Some(feagi);
                true
            }
            Err(e) => {
                godot_error!("❌ FEAGI initialization failed: {}", e);
                false
            }
        }
    }
    
    /// Initialize FEAGI with default embedded configuration
    /// 
    /// Uses sensible defaults for desktop mode:
    /// - API: http://127.0.0.1:8765
    /// - WebSocket: ws://127.0.0.1:9050
    /// - No external networking
    #[func]
    fn initialize_default(&mut self) -> bool {
        godot_print!("📝 Initializing FEAGI with embedded defaults");
        
        let config = Self::create_embedded_config();
        
        match FeagiInstance::new(config) {
            Ok(mut feagi) => {
                match feagi.initialize() {
                    Ok(_) => {
                        godot_print!("✅ FEAGI initialized with embedded config");
                        *self.instance.lock().unwrap() = Some(feagi);
                        true
                    }
                    Err(e) => {
                        godot_error!("❌ FEAGI initialization failed: {}", e);
                        false
                    }
                }
            }
            Err(e) => {
                godot_error!("❌ Failed to create FEAGI instance: {}", e);
                false
            }
        }
    }
    
    /// Start FEAGI services (HTTP API, PNS, Burst Engine)
    /// 
    /// # Returns
    /// true if services started successfully, false otherwise
    #[func]
    fn start(&self) -> bool {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            match feagi.start() {
                Ok(_) => {
                    godot_print!("🚀 FEAGI services started");
                    true
                }
                Err(e) => {
                    godot_error!("❌ Failed to start FEAGI: {}", e);
                    false
                }
            }
        } else {
            godot_error!("❌ FEAGI not initialized. Call initialize() first.");
            false
        }
    }
    
    /// Load a genome from a file
    /// 
    /// # Arguments
    /// * `genome_path` - Path to .brain.json file
    /// 
    /// # Returns
    /// true if genome loaded successfully, false otherwise
    #[func]
    fn load_genome(&self, genome_path: GString) -> bool {
        let path = genome_path.to_string();
        godot_print!("🧠 Loading genome from: {}", path);
        
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            match feagi.load_genome(&path) {
                Ok(_) => {
                    godot_print!("✅ Genome loaded successfully");
                    true
                }
                Err(e) => {
                    godot_error!("❌ Genome load failed: {}", e);
                    false
                }
            }
        } else {
            godot_error!("❌ FEAGI not initialized");
            false
        }
    }
    
    /// Get the HTTP API base URL
    /// 
    /// # Returns
    /// URL string (e.g., "http://127.0.0.1:8765")
    #[func]
    fn get_api_url(&self) -> GString {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            GString::from(feagi.get_api_url())
        } else {
            GString::from("http://127.0.0.1:8765")
        }
    }
    
    /// Get the WebSocket visualization port
    /// 
    /// # Returns
    /// Port number (e.g., 9050)
    #[func]
    fn get_websocket_viz_port(&self) -> i32 {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            feagi.get_websocket_viz_port() as i32
        } else {
            9050
        }
    }
    
    /// Check if FEAGI is running
    /// 
    /// # Returns
    /// true if burst engine is active, false otherwise
    #[func]
    fn is_running(&self) -> bool {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            feagi.is_running()
        } else {
            false
        }
    }
    
    /// Shutdown FEAGI gracefully
    /// 
    /// Stops all services and releases resources.
    /// Call this before exiting the application.
    #[func]
    fn shutdown(&self) {
        godot_print!("🛑 Shutting down FEAGI...");
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            if let Err(e) = feagi.shutdown() {
                godot_error!("❌ FEAGI shutdown error: {}", e);
            } else {
                godot_print!("✅ FEAGI shutdown complete");
            }
        }
    }
    
    // Internal helper functions
    
    fn initialize_internal(config_path: &str) -> anyhow::Result<FeagiInstance> {
        // Load config from file
        let config = load_config(Some(std::path::Path::new(config_path)), None)?;
        
        // Create and initialize FEAGI instance
        let mut feagi = FeagiInstance::new(config)?;
        feagi.initialize()?;
        
        Ok(feagi)
    }
    
    fn create_embedded_config() -> FeagiConfig {
        use feagi_config::*;
        
        FeagiConfig {
            api: ApiConfig {
                host: "127.0.0.1".to_string(),
                port: 8765,
                ..Default::default()
            },
            websocket: WebSocketConfig {
                enabled: true,
                host: "127.0.0.1".to_string(),
                visualization_port: 9050,
                sensory_port: 9051,
                motor_port: 9052,
                registration_port: 9053,
                ..Default::default()
            },
            neural: NeuralConfig {
                burst_engine_timestep: 0.01,  // 100Hz
                ..Default::default()
            },
            resources: ResourceConfig {
                use_gpu: false,  // Conservative default for embedded
                ..Default::default()
            },
            ..Default::default()
        }
    }
}

// Implement Drop to ensure cleanup
impl Drop for FeagiEmbedded {
    fn drop(&mut self) {
        self.shutdown();
    }
}
```

#### 2.4 GDExtension Configuration File

**File:** `feagi_embedded.gdextension`

```ini
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = 4.1
reloadable = false

[libraries]
# Desktop platforms (embedded FEAGI only works on desktop)
macos.debug = "target/debug/libfeagi_embedded.dylib"
macos.release = "target/release/libfeagi_embedded.dylib"

windows.debug.x86_64 = "target/x86_64-pc-windows-msvc/debug/feagi_embedded.dll"
windows.release.x86_64 = "target/x86_64-pc-windows-msvc/release/feagi_embedded.dll"

linux.debug.x86_64 = "target/x86_64-unknown-linux-gnu/debug/libfeagi_embedded.so"
linux.release.x86_64 = "target/x86_64-unknown-linux-gnu/release/libfeagi_embedded.so"

# Web builds not supported for embedded FEAGI (too heavy for WASM)
```

---

### Phase 3: Integrate with Brain Visualizer

**Goal:** Update BV to use embedded FEAGI when running in desktop mode.

#### 3.1 Create FEAGI Manager Script

**Location:** `/Users/nadji/code/FEAGI-2.0/brain-visualizer/godot_source/Utils/FeagiEmbeddedManager.gd`

```gdscript
extends Node
class_name FeagiEmbeddedManager

## Manages embedded FEAGI instance for desktop builds
## Provides automatic fallback to external FEAGI if embedded is unavailable

signal feagi_initialized(success: bool)
signal feagi_started(success: bool)
signal genome_loaded(success: bool)

enum FeagiMode {
    EMBEDDED,    # Using native Rust extension
    EXTERNAL,    # Using separate FEAGI process/container
    DISABLED     # No FEAGI available
}

var feagi_mode: FeagiMode = FeagiMode.DISABLED
var feagi_instance: FeagiEmbedded = null
var api_url: String = ""
var ws_viz_port: int = 9050

func _ready():
    # Detect platform and available FEAGI options
    detect_feagi_mode()

func detect_feagi_mode():
    # Check if running on desktop (embedded FEAGI only works on desktop)
    if not OS.has_feature("desktop"):
        print("𒓉 [FEAGI-MGR] Non-desktop platform, embedded FEAGI not available")
        feagi_mode = FeagiMode.EXTERNAL
        return
    
    # Try to load embedded FEAGI extension
    if ClassDB.class_exists("FeagiEmbedded"):
        print("𒓉 [FEAGI-MGR] ✅ Embedded FEAGI extension available")
        feagi_mode = FeagiMode.EMBEDDED
    else:
        print("𒓉 [FEAGI-MGR] ⚠️ Embedded FEAGI not found, will use external mode")
        feagi_mode = FeagiMode.EXTERNAL

func initialize_feagi(config_path: String = "") -> bool:
    """Initialize FEAGI instance"""
    match feagi_mode:
        FeagiMode.EMBEDDED:
            return _initialize_embedded(config_path)
        FeagiMode.EXTERNAL:
            return _initialize_external()
        _:
            push_error("No FEAGI mode available")
            return false

func _initialize_embedded(config_path: String) -> bool:
    """Initialize embedded FEAGI (native Rust)"""
    print("𒓉 [FEAGI-MGR] 🚀 Initializing embedded FEAGI...")
    
    feagi_instance = ClassDB.instantiate("FeagiEmbedded")
    
    var success: bool = false
    if config_path.is_empty():
        # Use embedded defaults
        success = feagi_instance.initialize_default()
    else:
        # Load from config file
        success = feagi_instance.initialize_from_config(config_path)
    
    if success:
        api_url = feagi_instance.get_api_url()
        ws_viz_port = feagi_instance.get_websocket_viz_port()
        print("𒓉 [FEAGI-MGR] ✅ Embedded FEAGI initialized")
        print("𒓉 [FEAGI-MGR]    API: ", api_url)
        print("𒓉 [FEAGI-MGR]    WebSocket Viz: ws://127.0.0.1:%d" % ws_viz_port)
    else:
        push_error("Failed to initialize embedded FEAGI")
    
    feagi_initialized.emit(success)
    return success

func _initialize_external() -> bool:
    """Configure for external FEAGI connection"""
    print("𒓉 [FEAGI-MGR] 🔗 Configuring external FEAGI connection...")
    
    # Read from environment or use defaults
    api_url = OS.get_environment("FEAGI_API_URL")
    if api_url.is_empty():
        api_url = "http://127.0.0.1:8765"
    
    var ws_host = OS.get_environment("FEAGI_WS_HOST")
    if ws_host.is_empty():
        ws_viz_port = 9050
    else:
        # Parse port from host string if provided
        ws_viz_port = int(ws_host.get_slice(":", 1)) if ":" in ws_host else 9050
    
    print("𒓉 [FEAGI-MGR] ✅ External FEAGI configured")
    print("𒓉 [FEAGI-MGR]    API: ", api_url)
    print("𒓉 [FEAGI-MGR]    WebSocket Viz: ws://%s:%d" % ["127.0.0.1", ws_viz_port])
    
    feagi_initialized.emit(true)
    return true

func start_feagi() -> bool:
    """Start FEAGI services"""
    if feagi_mode == FeagiMode.EMBEDDED:
        if feagi_instance == null:
            push_error("FEAGI instance not initialized")
            return false
        
        var success = feagi_instance.start()
        feagi_started.emit(success)
        return success
    else:
        # External mode - assume already running
        feagi_started.emit(true)
        return true

func load_genome(genome_path: String) -> bool:
    """Load a genome file"""
    if feagi_mode == FeagiMode.EMBEDDED:
        if feagi_instance == null:
            push_error("FEAGI instance not initialized")
            return false
        
        var success = feagi_instance.load_genome(genome_path)
        genome_loaded.emit(success)
        return success
    else:
        # External mode - use REST API to load genome
        return _load_genome_via_api(genome_path)

func _load_genome_via_api(genome_path: String) -> bool:
    """Load genome via REST API (for external FEAGI)"""
    # Implementation using HTTPRequest to POST to /v1/genome/load
    # (existing BV code can be reused here)
    print("𒓉 [FEAGI-MGR] Loading genome via REST API: ", genome_path)
    # ... API call implementation ...
    return true

func is_running() -> bool:
    """Check if FEAGI burst engine is running"""
    if feagi_mode == FeagiMode.EMBEDDED and feagi_instance:
        return feagi_instance.is_running()
    else:
        # For external, check via health API
        return true  # Simplified

func shutdown():
    """Shutdown FEAGI gracefully"""
    if feagi_mode == FeagiMode.EMBEDDED and feagi_instance:
        print("𒓉 [FEAGI-MGR] 🛑 Shutting down embedded FEAGI...")
        feagi_instance.shutdown()
        feagi_instance = null

func get_api_url() -> String:
    return api_url

func get_websocket_viz_port() -> int:
    return ws_viz_port

# Cleanup on exit
func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        shutdown()
```

#### 3.2 Update Main BV Scene

**Location:** Modify `brain-visualizer/godot_source/FEAGI_BrainVisualizer.gd` (or equivalent main script)

```gdscript
extends Control

# Add FEAGI manager
var feagi_manager: FeagiEmbeddedManager

func _ready():
    # Create FEAGI manager
    feagi_manager = FeagiEmbeddedManager.new()
    add_child(feagi_manager)
    
    # Connect signals
    feagi_manager.feagi_initialized.connect(_on_feagi_initialized)
    feagi_manager.feagi_started.connect(_on_feagi_started)
    feagi_manager.genome_loaded.connect(_on_genome_loaded)
    
    # Initialize FEAGI
    feagi_manager.initialize_feagi()

func _on_feagi_initialized(success: bool):
    if success:
        print("✅ FEAGI initialized, starting services...")
        feagi_manager.start_feagi()
    else:
        push_error("Failed to initialize FEAGI")

func _on_feagi_started(success: bool):
    if success:
        print("✅ FEAGI services started")
        # Update FEAGINetworking to use correct API URL and WebSocket port
        var api_url = feagi_manager.get_api_url()
        var ws_port = feagi_manager.get_websocket_viz_port()
        
        # Configure FEAGINetworking
        # (existing BV code)
    else:
        push_error("Failed to start FEAGI")

func _on_genome_loaded(success: bool):
    if success:
        print("✅ Genome loaded in FEAGI")
    else:
        push_error("Failed to load genome")

func _notification(what):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        # Ensure FEAGI shuts down gracefully
        if feagi_manager:
            feagi_manager.shutdown()
        get_tree().quit()
```

---

### Phase 4: Build System Integration

**Goal:** Automate building of FEAGI GDExtension for all desktop platforms.

#### 4.1 Extend Existing Build Script

**Location:** `/Users/nadji/code/FEAGI-2.0/brain-visualizer/rust_extensions/build.py`

**Add FEAGI embedded build:**

```python
def build_feagi_embedded():
    """Build the embedded FEAGI GDExtension"""
    print("\n" + "="*80)
    print("Building FEAGI Embedded Extension")
    print("="*80 + "\n")
    
    feagi_dir = Path("feagi_embedded")
    if not feagi_dir.exists():
        print(f"❌ Directory not found: {feagi_dir}")
        return False
    
    os.chdir(feagi_dir)
    
    # Build for current platform
    print("🔨 Building FEAGI embedded for current platform...")
    result = run_command(["cargo", "build", "--release"])
    
    if result:
        # Copy to Godot addons directory
        lib_name = f"libfeagi_embedded{get_library_extension()}"
        src = Path("target/release") / lib_name
        dest = Path("../../godot_source/addons/feagi_embedded") / lib_name
        
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        print(f"✅ Copied {lib_name} to {dest}")
        
        # Copy .gdextension file
        shutil.copy2("feagi_embedded.gdextension", dest.parent)
        print("✅ FEAGI embedded build complete")
    else:
        print("❌ FEAGI embedded build failed")
    
    os.chdir("..")
    return result

def main():
    # ... existing builds ...
    
    # Add FEAGI embedded build
    if platform.system() == "Darwin" or platform.system() == "Linux" or platform.system() == "Windows":
        build_feagi_embedded()
```

#### 4.2 CI/CD GitHub Actions

**Location:** `/Users/nadji/code/FEAGI-2.0/brain-visualizer/.github/workflows/build-desktop.yml`

```yaml
name: Build Desktop with Embedded FEAGI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
      
      - name: Setup Rust
        uses: actions-rust-lang/setup-rust-toolchain@v1
        with:
          toolchain: stable
          target: aarch64-apple-darwin,x86_64-apple-darwin
      
      - name: Build Rust Extensions
        run: |
          cd rust_extensions
          python3 build.py
      
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.2.1
      
      - name: Export macOS Build
        run: |
          godot --headless --export-release "macOS" ./exports/BrainVisualizer.app
      
      - name: Create DMG
        run: |
          # Bundle FEAGI library into .app
          # Create DMG installer
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v3
        with:
          name: BrainVisualizer-macOS
          path: exports/BrainVisualizer.dmg

  build-windows:
    runs-on: windows-latest
    steps:
      # Similar for Windows .exe
      # ...

  build-linux:
    runs-on: ubuntu-latest
    steps:
      # Similar for Linux AppImage
      # ...
```

---

## Technical Considerations

### 1. Memory and Performance

**Embedded FEAGI Memory Footprint:**
- **Base:** ~50-100MB (NPU structures, connectome)
- **With Genome:** +50-200MB (depends on brain size)
- **During Burst:** +10-50MB (temporary allocations)

**Total:** 100-350MB for typical genome

**Comparison:**
- Docker FEAGI: 200-500MB (includes OS overhead)
- Godot alone: 100-200MB
- **Combined embedded:** 200-550MB (very reasonable for desktop)

### 2. Threading Model

**FEAGI uses:**
- Tokio async runtime (4 worker threads)
- Burst engine thread
- ZMQ/WebSocket I/O threads

**Godot uses:**
- Main thread (GDScript)
- Render thread (GPU)
- Physics thread

**Isolation strategy:**
- FEAGI runs on dedicated tokio runtime (separate thread pool)
- Communication via thread-safe channels (Arc<Mutex<>>)
- No GIL contention (Rust doesn't have GIL)
- Godot interacts via GDExtension FFI boundary

### 3. Configuration Management

**Embedded mode configuration sources:**

1. **Bundled `feagi_configuration.toml`** (shipped with app)
   - Location: `res://config/feagi_configuration.toml`
   - Read-only, default settings
   
2. **User config** (overrides)
   - Location: `user://feagi_config_override.toml`
   - Writable, persistent across sessions
   
3. **Programmatic** (runtime overrides)
   - Set via GDScript: `feagi_instance.set_burst_hz(120)`

### 4. Genome Loading

**Options:**

1. **Embedded in app bundle**
   - Location: `res://genomes/default.brain.json`
   - Shipped with application
   - Good for demos/standalone experiences

2. **User-selected**
   - File dialog: "Open genome..."
   - Stored in `user://` for persistence

3. **Downloaded**
   - Fetch from genome library API
   - Cache locally

### 5. Platform Support

| Platform | Embedded FEAGI | Notes |
|----------|----------------|-------|
| **macOS** | ✅ Full support | Universal binary (x86_64 + ARM64) |
| **Windows** | ✅ Full support | x86_64 only (ARM64 future) |
| **Linux** | ✅ Full support | x86_64, easy AppImage distribution |
| **Web** | ❌ Not suitable | WASM limitations (threading, file I/O) |
| **Mobile** | ⚠️ Possible but not recommended | Memory/battery constraints |

**Web builds:**
- Continue using external FEAGI (Docker/cloud)
- BV web connects via WebSocket
- No change to current architecture

### 6. GPU Acceleration

**Embedded mode GPU support:**

- **macOS:** Metal (via `wgpu`)
- **Windows:** DirectX 12 or Vulkan (via `wgpu`)
- **Linux:** Vulkan (via `wgpu`)

**Configuration:**
```toml
[resources]
use_gpu = true
gpu_memory_fraction = 0.3
```

**Fallback:** CPU-only mode if GPU unavailable

---

## Distribution Strategy

### Single-Binary Desktop App

**macOS:**
```
BrainVisualizer.app/
├── Contents/
│   ├── MacOS/
│   │   └── BrainVisualizer          # Godot engine + BV
│   ├── Resources/
│   │   ├── feagi_embedded.dylib     # FEAGI extension (universal)
│   │   ├── feagi_configuration.toml # Default config
│   │   ├── genomes/
│   │   │   └── default.brain.json   # Default genome
│   │   └── ... (Godot assets)
│   └── Info.plist
```

**Distribution:** Single `.dmg` file (~150-250MB)

**Windows:**
```
BrainVisualizer/
├── BrainVisualizer.exe              # Godot engine + BV
├── feagi_embedded.dll               # FEAGI extension
├── feagi_configuration.toml         # Default config
├── genomes/
│   └── default.brain.json           # Default genome
└── ... (Godot assets)
```

**Distribution:** Installer (`.msi`) or portable `.zip` (~150-250MB)

**Linux:**
```
BrainVisualizer.AppImage             # Self-contained (includes all above)
```

**Distribution:** Single AppImage file (~150-250MB)

---

## Migration Path

### Phase 1: Parallel Development (2-4 weeks)
- ✅ Create FEAGI library crate
- ✅ Create FEAGI GDExtension
- ✅ Test embedded FEAGI independently
- ✅ No changes to existing BV

### Phase 2: Integration (1-2 weeks)
- Add `FeagiEmbeddedManager` to BV
- Implement auto-detection (embedded vs external)
- Update build scripts
- Test desktop builds

### Phase 3: Refinement (1-2 weeks)
- Polish UX (loading screens, error handling)
- Optimize memory usage
- Add user configuration UI
- Create distribution packages

### Phase 4: Deployment (1 week)
- Release beta builds
- Gather user feedback
- Fix platform-specific issues
- Official release

**Total timeline:** 5-9 weeks

---

## Benefits

### For Users

1. **Single Download:** No Docker, no separate FEAGI installation
2. **Instant Launch:** Click and run, FEAGI starts automatically
3. **Offline Capable:** No network dependency
4. **Native Performance:** No containerization overhead
5. **Simplified Troubleshooting:** One app, one process

### For Developers

1. **Unified Codebase:** FEAGI and BV in sync
2. **Easier Testing:** No multi-process debugging
3. **Faster Iteration:** Build once, test immediately
4. **Better Profiling:** Single process to profile
5. **Cross-Platform:** Same code runs on all desktops

### For Distribution

1. **Smaller Package:** ~200MB vs 500MB+ (Docker image)
2. **App Store Ready:** Can publish to Mac App Store, Microsoft Store
3. **Auto-Updates:** Use Godot/Steamworks update systems
4. **License Management:** Easier to enforce commercial licenses

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **FEAGI binary size** | Large app downloads | Strip symbols, LTO, compression |
| **Memory usage** | App crashes on low-end hardware | Add system requirements check, RAM warning |
| **Compilation time** | Slower development | Use `sccache`, parallel builds |
| **Platform bugs** | Crashes on specific OS versions | Extensive testing, telemetry, auto-reporting |
| **Version mismatch** | BV/FEAGI incompatibility | Lock FEAGI version, automated compatibility tests |

---

## Proof of Concept

### Minimal PoC Steps (4-8 hours)

1. **Create `feagi/src/lib.rs`** with basic `FeagiInstance::new()` and `start()`
2. **Create `feagi_embedded` GDExtension** with `initialize()` and `get_api_url()`
3. **Update BV main scene** to instantiate `FeagiEmbedded`
4. **Build and test** on macOS

**Success criteria:**
- BV launches with embedded FEAGI
- REST API accessible at `http://127.0.0.1:8765`
- Can load a genome
- Burst engine runs
- BV connects via WebSocket

---

## Recommendation

**Proceed with implementation** for the following reasons:

1. ✅ **Technically Feasible:** All pieces exist, just need integration
2. ✅ **Already Using Rust:** BV has GDExtension infrastructure
3. ✅ **Significant UX Improvement:** Eliminates Docker dependency
4. ✅ **Manageable Scope:** 5-9 weeks of focused work
5. ✅ **Backward Compatible:** External FEAGI still works
6. ✅ **Market Advantage:** Standalone desktop app vs cloud-dependent tools

**Start with macOS PoC** (most developer machines), then expand to Windows and Linux.

---

## Next Steps

1. **Review this proposal** with team
2. **Create GitHub project** for tracking
3. **Implement Phase 1** (FEAGI library crate)
4. **Weekly demos** to show progress
5. **Beta release** for internal testing

---

## References

- **GDExtension Docs:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/what_is_gdextension.html
- **godot-rust (gdext):** https://github.com/godot-rust/gdext
- **Tokio Docs:** https://tokio.rs/
- **FEAGI Architecture:** `/Users/nadji/code/FEAGI-2.0/feagi/README.md`
- **Existing BV Rust Integration:** `/Users/nadji/code/FEAGI-2.0/brain-visualizer/RUST_INTEGRATION_SUMMARY.md`

---

**Prepared by:** Cursor AI Assistant  
**Date:** November 5, 2025  
**Version:** 1.0

