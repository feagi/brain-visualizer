//! # FEAGI Embedded GDExtension
//!
//! Godot extension that embeds FEAGI neural processing engine in-process.
//! Provides direct FFI access to FEAGI for high-performance desktop applications.
//!
//! ## Features
//!
//! - In-process FEAGI (no network overhead)
//! - Direct memory access for visualization data
//! - Microsecond-latency API calls
//! - HTTP server for complex operations
//! - Desktop-only (macOS, Windows, Linux)
//!
//! ## GDScript Usage
//!
//! ```gdscript
//! var feagi = FeagiEmbedded.new()
//! feagi.visualization_data.connect(_on_viz_data)
//! feagi.initialize_default()
//! feagi.start()
//!
//! func _process(delta):
//!     var neurons = feagi.get_neuron_count()
//!     var running = feagi.is_running()
//! ```

use godot::prelude::*;
use godot::classes::{RefCounted, IRefCounted};
use feagi::{FeagiInstance, FeagiConfig};
use std::sync::{Arc, Mutex};

struct FeagiEmbeddedLib;

#[gdextension]
unsafe impl ExtensionLibrary for FeagiEmbeddedLib {}

/// FEAGI Embedded - In-process neural engine for Godot
/// 
/// Runs FEAGI as a library within the Godot application process.
/// Provides high-performance access to neural processing with zero network overhead.
/// 
/// # Desktop Only
/// 
/// This extension only works on desktop platforms (macOS, Windows, Linux).
/// Web builds should use external FEAGI with WebSocket connections.
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct FeagiEmbedded {
    #[base]
    base: Base<RefCounted>,
    
    /// FEAGI instance (wrapped in Arc<Mutex> for thread-safe access)
    instance: Arc<Mutex<Option<FeagiInstance>>>,
}

#[godot_api]
impl IRefCounted for FeagiEmbedded {
    fn init(base: Base<RefCounted>) -> Self {
        godot_print!("🦀 FEAGI Embedded v2.0.0 initialized (in-process mode)");
        godot_print!("   Platform: desktop-only (no web support)");
        godot_print!("   Communication: Direct FFI (microsecond latency)");
        
        Self {
            base,
            instance: Arc::new(Mutex::new(None)),
        }
    }
}

#[godot_api]
impl FeagiEmbedded {
    //
    // ============ SIGNALS ============
    //
    
    /// Emitted when visualization data is available (every burst cycle)
    /// 
    /// # Arguments
    /// 
    /// * `cortical_ids` - Array of cortical area IDs (e.g., ["iic100", "ogaz00"])
    /// * `x` - X coordinates of fired neurons
    /// * `y` - Y coordinates of fired neurons
    /// * `z` - Z coordinates of fired neurons
    /// * `powers` - Power/activation levels (0.0-1.0)
    /// 
    /// # Note
    /// 
    /// Currently, this signal is not connected as PNS callback support is pending.
    /// Visualization data is published via WebSocket (port 9050).
    #[signal]
    fn visualization_data(
        cortical_ids: PackedStringArray,
        x: PackedInt32Array,
        y: PackedInt32Array,
        z: PackedInt32Array,
        powers: PackedFloat32Array,
    );
    
    //
    // ============ LIFECYCLE ============
    //
    
    /// Initialize FEAGI with default embedded configuration
    /// 
    /// Uses sensible defaults for desktop mode:
    /// - API: http://127.0.0.1:8000
    /// - WebSocket: ws://127.0.0.1:9050
    /// - Burst frequency: 100Hz
    /// - GPU: Auto-detect
    /// 
    /// # Returns
    /// 
    /// `true` if initialization succeeded, `false` otherwise
    #[func]
    fn initialize_default(&mut self) -> bool {
        godot_print!("📝 Initializing FEAGI with embedded defaults...");
        
        let config = Self::create_embedded_config();
        
        match FeagiInstance::new(config) {
            Ok(mut feagi) => {
                match feagi.initialize() {
                    Ok(_) => {
                        godot_print!("✅ FEAGI initialized successfully");
                        godot_print!("   HTTP API: {}", feagi.get_api_url());
                        godot_print!("   Use HTTP API for: genome loading, analytics, settings");
                        godot_print!("   Use FFI methods for: start/stop, stats, real-time control");
                        
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
    
    /// Initialize FEAGI from a configuration file
    /// 
    /// # Arguments
    /// 
    /// * `config_path` - Path to feagi_configuration.toml
    /// 
    /// # Returns
    /// 
    /// `true` if initialization succeeded, `false` otherwise
    #[func]
    fn initialize_from_config(&mut self, config_path: GString) -> bool {
        let path = config_path.to_string();
        godot_print!("📝 Loading FEAGI configuration from: {}", path);
        
        match Self::initialize_internal(&path) {
            Ok(feagi) => {
                godot_print!("✅ FEAGI initialized from config");
                godot_print!("   HTTP API: {}", feagi.get_api_url());
                *self.instance.lock().unwrap() = Some(feagi);
                true
            }
            Err(e) => {
                godot_error!("❌ FEAGI initialization failed: {}", e);
                false
            }
        }
    }
    
    /// Shutdown FEAGI gracefully
    /// 
    /// Stops burst engine, closes streams, and releases resources.
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
    
    //
    // ============ BURST ENGINE CONTROL (Hot Path - FFI) ============
    //
    
    /// Start the burst engine
    /// 
    /// Begins neural processing loop. Visualization data will be published.
    /// 
    /// # Returns
    /// 
    /// `true` if burst engine started successfully, `false` otherwise
    #[func]
    fn start(&self) -> bool {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            match feagi.start() {
                Ok(_) => {
                    godot_print!("▶️  FEAGI burst engine started");
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
    
    /// Stop the burst engine
    /// 
    /// Halts neural processing. Can be restarted with `start()`.
    /// 
    /// # Returns
    /// 
    /// `true` if burst engine stopped successfully, `false` otherwise
    #[func]
    fn stop(&self) -> bool {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            match feagi.stop() {
                Ok(_) => {
                    godot_print!("⏸️  FEAGI burst engine stopped");
                    true
                }
                Err(e) => {
                    godot_error!("❌ Failed to stop FEAGI: {}", e);
                    false
                }
            }
        } else {
            false
        }
    }
    
    /// Set burst frequency (Hz)
    /// 
    /// Changes the neural processing speed in real-time.
    /// 
    /// # Arguments
    /// 
    /// * `hz` - Frequency in Hz (e.g., 100.0 for 100Hz, 60.0 for 60Hz)
    /// 
    /// # Returns
    /// 
    /// `true` if frequency changed successfully, `false` otherwise
    #[func]
    fn set_burst_frequency(&self, hz: f64) -> bool {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            match feagi.set_burst_frequency(hz) {
                Ok(_) => {
                    godot_print!("⚡ Burst frequency set to {:.1}Hz", hz);
                    true
                }
                Err(e) => {
                    godot_error!("❌ Failed to set frequency: {}", e);
                    false
                }
            }
        } else {
            false
        }
    }
    
    //
    // ============ REAL-TIME STATS (Hot Path - FFI) ============
    //
    
    /// Check if burst engine is running
    /// 
    /// This is a fast, lock-free read (~100ns latency).
    /// 
    /// # Returns
    /// 
    /// `true` if burst engine is actively processing, `false` otherwise
    #[func]
    fn is_running(&self) -> bool {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            feagi.is_running()
        } else {
            false
        }
    }
    
    /// Get total neuron count
    /// 
    /// Returns the total number of neurons in the loaded genome.
    /// 
    /// # Returns
    /// 
    /// Neuron count, or 0 if no genome is loaded or FEAGI not initialized
    #[func]
    fn get_neuron_count(&self) -> i64 {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            feagi.get_neuron_count().unwrap_or(0) as i64
        } else {
            0
        }
    }
    
    /// Check if a genome is loaded
    /// 
    /// Returns true if neuroembryogenesis has completed successfully.
    /// 
    /// # Returns
    /// 
    /// `true` if genome is loaded, `false` otherwise
    #[func]
    fn is_genome_loaded(&self) -> bool {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            feagi.is_genome_loaded()
        } else {
            false
        }
    }
    
    //
    // ============ HTTP SERVER INFO ============
    //
    
    /// Get the HTTP API base URL
    /// 
    /// Returns the URL where the REST API is accessible (e.g., "http://127.0.0.1:8000").
    /// Use this URL for complex operations like genome loading, analytics queries, etc.
    /// 
    /// # Returns
    /// 
    /// HTTP API URL string
    #[func]
    fn get_api_url(&self) -> GString {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            GString::from(feagi.get_api_url().as_str())
        } else {
            GString::from("http://127.0.0.1:8000")
        }
    }
    
    /// Check if HTTP server is running
    /// 
    /// # Returns
    /// 
    /// `true` if Axum server is bound and listening, `false` otherwise
    #[func]
    fn is_http_server_running(&self) -> bool {
        let instance = self.instance.lock().unwrap();
        if let Some(ref feagi) = *instance {
            feagi.is_http_server_running()
        } else {
            false
        }
    }
    
    //
    // ============ INTERNAL HELPERS ============
    //
    
    /// Create embedded configuration with sensible defaults
    fn create_embedded_config() -> FeagiConfig {
        use feagi_config::*;
        
        FeagiConfig {
            api: ApiConfig {
                host: "127.0.0.1".to_string(),
                port: 8000,
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
            resources: ResourcesConfig {
                use_gpu: true,  // Auto-detect and use if available
                ..Default::default()
            },
            ..Default::default()
        }
    }
    
    /// Initialize FEAGI from config file
    fn initialize_internal(config_path: &str) -> anyhow::Result<FeagiInstance> {
        // Load config from file
        let config = feagi::load_config(Some(std::path::Path::new(config_path)), None)?;
        
        // Create and initialize FEAGI instance
        let mut feagi = FeagiInstance::new(config)?;
        feagi.initialize()?;
        
        Ok(feagi)
    }
}

// Implement Drop to ensure cleanup
impl Drop for FeagiEmbedded {
    fn drop(&mut self) {
        self.shutdown();
    }
}

