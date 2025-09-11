declare namespace wasm_bindgen {
	/* tslint:disable */
	/* eslint-disable */
	/**
	 * Decode FEAGI "Type 11" neuron payloads in the browser (WebAssembly).
	 *
	 * - `buffer`: byte slice containing a Type 11 message (LE-encoded header + area sections).
	 * - Returns: a JS object (via `wasm-bindgen`) with `{ success, total_neurons, areas, error }`.
	 *   Each `areas[cortical_id]` has `x_array`, `y_array`, `z_array` (i32[]) and `p_array` (f32[]).
	 */
	export function decode_type_11(buffer: Uint8Array): any;
	
}

declare type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

declare interface InitOutput {
  readonly memory: WebAssembly.Memory;
  readonly decode_type_11: (a: number, b: number) => any;
  readonly __wbindgen_export_0: WebAssembly.Table;
  readonly __wbindgen_malloc: (a: number, b: number) => number;
  readonly __wbindgen_start: () => void;
}

/**
* If `module_or_path` is {RequestInfo} or {URL}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
*
* @returns {Promise<InitOutput>}
*/
declare function wasm_bindgen (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
