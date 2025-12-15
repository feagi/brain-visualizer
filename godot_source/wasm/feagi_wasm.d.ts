/* tslint:disable */
/* eslint-disable */

export class FeagiEngine {
  free(): void;
  [Symbol.dispose](): void;
  /**
   * Get the current configuration as JSON
   */
  getConfig(): any;
  /**
   * Update configuration from JSON
   */
  setConfig(config: any): void;
  /**
   * Load a genome from JSON data
   *
   * # Arguments
   *
   * * `genome_json` - Genome JSON as string
   *
   * # Returns
   *
   * Result indicating success or error
   */
  loadGenome(genome_json: string): void;
  /**
   * Save the currently loaded genome to IndexedDB storage
   *
   * # Arguments
   *
   * * `genome_id` - Unique identifier for the genome
   *
   * # Returns
   *
   * Result indicating success or error
   */
  saveGenome(genome_id: string): Promise<void>;
  /**
   * Initialize IndexedDB storage
   *
   * This must be called before using storage operations.
   * Storage is initialized lazily on first use if not explicitly initialized.
   */
  initStorage(): Promise<void>;
  /**
   * List all genome IDs stored in IndexedDB
   *
   * # Returns
   *
   * Array of genome IDs as JSON string
   */
  listGenomes(): Promise<string>;
  /**
   * Delete a genome from IndexedDB storage
   *
   * # Arguments
   *
   * * `genome_id` - Unique identifier for the genome to delete
   *
   * # Returns
   *
   * Result indicating success or error
   */
  deleteGenome(genome_id: string): Promise<void>;
  /**
   * Process a single neural burst
   *
   * # Arguments
   *
   * * `input_data` - Input sensory data as JavaScript object (optional)
   *   Format: `{ "cortical_id": [[x, y, z, potential], ...], ... }`
   *   Example: `{ "iput00": [[0, 0, 0, 100.0], [1, 0, 0, 150.0]] }`
   *
   * # Returns
   *
   * Burst result with fired neurons and motor outputs as JSON string
   */
  processBurst(_input_data: any): string;
  /**
   * Download the currently loaded genome as a JSON file
   *
   * Returns the genome JSON string. JavaScript code should handle the actual download.
   *
   * # Returns
   *
   * Genome JSON string
   */
  downloadGenome(): string;
  /**
   * Get the number of bursts processed
   */
  getBurstCount(): bigint;
  /**
   * Check if a genome is currently loaded
   */
  isGenomeLoaded(): boolean;
  /**
   * Process a single neural burst (fast path with TypedArray)
   *
   * This method returns fired neuron data as a TypedArray for zero-copy transfer.
   * Format: [id, x, y, z, power, id, x, y, z, power, ...]
   *
   * # Arguments
   *
   * * `input_data` - Input sensory data as JavaScript object (optional)
   *
   * # Returns
   *
   * Float32Array containing fired neuron data (5 floats per neuron: id, x, y, z, power)
   */
  processBurstFast(_input_data: any): Float32Array;
  /**
   * Load a genome from IndexedDB storage
   *
   * # Arguments
   *
   * * `genome_id` - Unique identifier for the genome to load
   *
   * # Returns
   *
   * Result indicating success or error
   */
  loadGenomeFromStorage(genome_id: string): Promise<void>;
  /**
   * Create a new FEAGI engine instance
   */
  constructor();
  /**
   * Reset the engine state
   */
  reset(): void;
  /**
   * Get engine statistics as JSON
   */
  getStats(): string;
}

/**
 * Decode FEAGI Type 11 neuron payload
 *
 * Type 11 format:
 * - Global header: [structure_type(u8), version(u8), num_areas(u16)]
 * - Area headers: For each area [cortical_id(6 bytes), offset(u32), length(u32)]
 * - Area data: For each area [x_array(i32[]), y_array(i32[]), z_array(i32[]), power(f32[])]
 *
 * # Arguments
 *
 * * `buffer` - Raw byte buffer containing Type 11 data
 *
 * # Returns
 *
 * JSON string with decoded data or error information
 */
export function decode_type_11(buffer: Uint8Array): string;

/**
 * Initialize the WASM module
 *
 * This should be called once when your application starts.
 * It sets up panic hooks for better error messages in the browser console.
 */
export function init(): void;

/**
 * Get the version of the FEAGI WASM module
 */
export function version(): string;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
  readonly memory: WebAssembly.Memory;
  readonly __wbg_feagiengine_free: (a: number, b: number) => void;
  readonly decode_type_11: (a: number, b: number, c: number) => void;
  readonly feagiengine_deleteGenome: (a: number, b: number, c: number) => number;
  readonly feagiengine_downloadGenome: (a: number, b: number) => void;
  readonly feagiengine_getBurstCount: (a: number) => bigint;
  readonly feagiengine_getConfig: (a: number) => number;
  readonly feagiengine_getStats: (a: number, b: number) => void;
  readonly feagiengine_initStorage: (a: number) => number;
  readonly feagiengine_isGenomeLoaded: (a: number) => number;
  readonly feagiengine_listGenomes: (a: number) => number;
  readonly feagiengine_loadGenome: (a: number, b: number, c: number, d: number) => void;
  readonly feagiengine_loadGenomeFromStorage: (a: number, b: number, c: number) => number;
  readonly feagiengine_new: (a: number) => void;
  readonly feagiengine_processBurst: (a: number, b: number, c: number) => void;
  readonly feagiengine_processBurstFast: (a: number, b: number, c: number) => void;
  readonly feagiengine_reset: (a: number) => void;
  readonly feagiengine_saveGenome: (a: number, b: number, c: number) => number;
  readonly feagiengine_setConfig: (a: number, b: number, c: number) => void;
  readonly init: () => void;
  readonly version: (a: number) => void;
  readonly __wasm_bindgen_func_elem_310: (a: number, b: number, c: number) => void;
  readonly __wasm_bindgen_func_elem_108: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_708: (a: number, b: number, c: number) => void;
  readonly __wasm_bindgen_func_elem_693: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_2777: (a: number, b: number, c: number, d: number) => void;
  readonly __wbindgen_export: (a: number, b: number) => number;
  readonly __wbindgen_export2: (a: number, b: number, c: number, d: number) => number;
  readonly __wbindgen_export3: (a: number) => void;
  readonly __wbindgen_export4: (a: number, b: number, c: number) => void;
  readonly __wbindgen_add_to_stack_pointer: (a: number) => number;
  readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
* Instantiates the given `module`, which can either be bytes or
* a precompiled `WebAssembly.Module`.
*
* @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
*
* @returns {InitOutput}
*/
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
* If `module_or_path` is {RequestInfo} or {URL}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
*
* @returns {Promise<InitOutput>}
*/
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;



// ============================================================================
// Enhanced TypeScript Definitions for FEAGI WASM
// ============================================================================

/**
 * Configuration for the FEAGI neural engine
 */
export interface EngineConfig {
    /** Burst processing frequency in Hz (default: 30) */
    burst_frequency_hz: number;
    /** Enable synaptic plasticity learning (default: false) */
    enable_plasticity: boolean;
    /** Maximum number of neurons to process (default: 1000000) */
    max_neurons: number;
}

/**
 * Result of decoding Type 11 neuron data
 */
export interface DecodeResult {
    /** Whether decoding succeeded */
    success: boolean;
    /** Total number of neurons across all areas */
    total_neurons: number;
    /** Neuron data organized by cortical area ID */
    areas: Record<string, CorticalAreaData>;
    /** Error message if decoding failed */
    error?: string;
}

/**
 * Neuron position and power data for a cortical area
 */
export interface CorticalAreaData {
    /** X coordinates of neurons */
    x_array: number[];
    /** Y coordinates of neurons */
    y_array: number[];
    /** Z coordinates of neurons */
    z_array: number[];
    /** Power/activation values of neurons */
    p_array: number[];
}

/**
 * Result of processing a neural burst
 */
export interface BurstResult {
    /** Unique burst identifier */
    burst_id: number;
    /** Neurons that fired during this burst */
    fired_neurons: FiredNeuron[];
    /** Motor output values by area ID */
    motor_outputs: Record<string, any>;
    /** Time taken to process burst in milliseconds */
    processing_time_ms: number;
}

/**
 * Information about a neuron that fired
 */
export interface FiredNeuron {
    /** Cortical area ID */
    area_id: string;
    /** Neuron ID within the area */
    neuron_id: number;
    /** 3D position [x, y, z] */
    position: [number, number, number];
    /** Firing power/activation */
    power: number;
}

/**
 * Engine statistics and state
 */
export interface EngineStats {
    /** FEAGI WASM version */
    version: string;
    /** Whether a genome is currently loaded */
    genome_loaded: boolean;
    /** Number of bursts processed */
    burst_count: number;
    /** Current engine configuration */
    config: EngineConfig;
}

/**
 * Genome data structure
 */
export interface GenomeData {
    /** Cortical area definitions */
    cortical_areas: Record<string, CorticalArea>;
    /** Connectome data */
    connectome: Connectome;
    /** Metadata */
    metadata?: GenomeMetadata;
}

/**
 * Cortical area definition
 */
export interface CorticalArea {
    /** Unique area identifier */
    id: string;
    /** Area type (ipu, opu, mem, etc) */
    type: string;
    /** Dimensions [x, y, z] */
    dimensions: [number, number, number];
    /** Neuron parameters */
    parameters: Record<string, any>;
}

/**
 * Connectome (synapse) data
 */
export interface Connectome {
    /** Source neuron IDs */
    source_neurons: number[];
    /** Target neuron IDs */
    target_neurons: number[];
    /** Synaptic weights (0-255) */
    weights: number[];
    /** Synaptic conductances (0-255) */
    conductances: number[];
    /** Synapse types (0=excitatory, 1=inhibitory) */
    types: number[];
}

/**
 * Genome metadata
 */
export interface GenomeMetadata {
    /** Genome name */
    name: string;
    /** Creation timestamp */
    created: string;
    /** Version */
    version: string;
    /** Description */
    description?: string;
}

// ============================================================================
// Module Exports
// ============================================================================

/**
 * Initialize the FEAGI WASM module
 * Must be called before using any other functions
 * 
 * @example
 * await init();
 * const engine = new FeagiEngine();
 */
export default function init(module?: WebAssembly.Module | Promise<WebAssembly.Module>): Promise<void>;

/**
 * Get the version of the FEAGI WASM module
 * 
 * @returns Version string (e.g., "2.0.0")
 */
export function version(): string;

/**
 * Decode FEAGI Type 11 neuron payload
 * 
 * @param buffer - Raw byte buffer containing Type 11 data
 * @returns Decoded neuron data or error
 * 
 * @example
 * const result = decode_type_11(byteArray);
 * if (result.success) {
 *   console.log(`Decoded ${result.total_neurons} neurons`);
 * }
 */
export function decode_type_11(buffer: Uint8Array): DecodeResult;

/**
 * Main FEAGI neural computation engine
 * 
 * Provides the primary interface for running FEAGI neural networks
 * in WebAssembly. Manages genome loading, burst processing, and state.
 * 
 * @example
 * const engine = new FeagiEngine();
 * await engine.loadGenome(genomeData);
 * const result = engine.processBurst(inputData);
 */
export class FeagiEngine {
    /**
     * Create a new FEAGI engine instance
     */
    constructor();

    /**
     * Get the current engine configuration
     * 
     * @returns Current configuration object
     */
    getConfig(): EngineConfig;

    /**
     * Update engine configuration
     * 
     * @param config - New configuration object
     * 
     * @example
     * engine.setConfig({
     *   burst_frequency_hz: 60,
     *   enable_plasticity: true,
     *   max_neurons: 1000000
     * });
     */
    setConfig(config: Partial<EngineConfig>): void;

    /**
     * Load a genome from JSON data
     * 
     * @param genomeData - Genome data object
     * @throws Error if genome loading fails
     * 
     * @example
     * await engine.loadGenome(genomeData);
     */
    loadGenome(genomeData: GenomeData): Promise<void>;

    /**
     * Check if a genome is currently loaded
     * 
     * @returns true if genome is loaded
     */
    isGenomeLoaded(): boolean;

    /**
     * Get the number of bursts processed since last reset
     * 
     * @returns Burst count
     */
    getBurstCount(): number;

    /**
     * Process a single neural burst
     * 
     * @param inputData - Input sensory data
     * @returns Burst processing result
     * @throws Error if no genome is loaded
     * 
     * @example
     * const result = engine.processBurst({
     *   sensory_data: {
     *     'ipu-vision': [[0.5, 0.8, 0.2]]
     *   }
     * });
     */
    processBurst(inputData: any): BurstResult;

    /**
     * Reset engine state
     * 
     * Clears burst count and unloads genome
     */
    reset(): void;

    /**
     * Get engine statistics
     * 
     * @returns Current engine stats
     */
    getStats(): EngineStats;

    /**
     * Free the engine resources
     * 
     * Should be called when done with the engine to free WASM memory
     */
    free(): void;
}
