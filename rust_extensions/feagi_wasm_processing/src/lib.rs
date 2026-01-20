use wasm_bindgen::prelude::*;
use serde::Serialize;

/// Structured output for a single cortical area's decoded arrays.
#[derive(Serialize)]
pub struct AreaOutput {
    pub x_array: Vec<i32>,
    pub y_array: Vec<i32>,
    pub z_array: Vec<i32>,
    pub p_array: Vec<f32>,
}

/// Top-level decode result returned to JavaScript callers.
#[derive(Serialize)]
pub struct DecodeOutput {
    pub success: bool,
    pub total_neurons: u32,
    pub areas: std::collections::BTreeMap<String, AreaOutput>,
    pub error: Option<String>,
}

/// Decode FEAGI "Type 11" neuron payloads in the browser (WebAssembly).
///
/// - `buffer`: byte slice containing a Type 11 message (LE-encoded header + area sections).
/// - Returns: a JS object (via `wasm-bindgen`) with `{ success, total_neurons, areas, error }`.
///   Each `areas[cortical_id]` has `x_array`, `y_array`, `z_array` (i32[]) and `p_array` (f32[]).
#[wasm_bindgen]
pub fn decode_type_11(buffer: &[u8]) -> JsValue {
    let result = match decode_type_11_inner(buffer) {
        Ok(out) => out,
        Err(e) => DecodeOutput {
            success: false,
            total_neurons: 0,
            areas: Default::default(),
            error: Some(e),
        },
    };
    serde_wasm_bindgen::to_value(&result).unwrap_or(JsValue::NULL)
}

fn decode_type_11_inner(buffer: &[u8]) -> Result<DecodeOutput, String> {
    if buffer.len() < 4 {
        return Err("Buffer too small for global header".to_string());
    }

    let structure_type = buffer[0];
    let version = buffer[1];
    let num_areas = u16::from_le_bytes([buffer[2], buffer[3]]);

    if structure_type != 11 {
        return Err(format!("Invalid structure type: {} (expected 11)", structure_type));
    }
    if version != 1 {
        return Err(format!("Unsupported version: {} (expected 1)", version));
    }
    if num_areas == 0 {
        return Err("No cortical areas in data".to_string());
    }

    let mut pos = 4usize;
    let area_headers_size = (num_areas as usize) * 14;
    if pos + area_headers_size > buffer.len() {
        return Err("Buffer too small for area headers".to_string());
    }

    #[derive(Clone)]
    struct AreaHeader { id: String, off: usize, len: usize }
    let mut headers = Vec::with_capacity(num_areas as usize);
    for _ in 0..num_areas {
        let id = String::from_utf8_lossy(&buffer[pos..pos+6]).trim_end_matches('\0').to_string();
        pos += 6;
        let off = u32::from_le_bytes([buffer[pos], buffer[pos+1], buffer[pos+2], buffer[pos+3]]) as usize;
        pos += 4;
        let len = u32::from_le_bytes([buffer[pos], buffer[pos+1], buffer[pos+2], buffer[pos+3]]) as usize;
        pos += 4;
        headers.push(AreaHeader { id, off, len });
    }

    let mut areas = std::collections::BTreeMap::new();
    let mut total_neurons: u32 = 0;

    for h in headers.into_iter() {
        if h.off + h.len > buffer.len() {
            return Err(format!("Area {} data range exceeds buffer", h.id));
        }
        if h.len % 16 != 0 {
            return Err(format!("Area {} data length {} not divisible by 16", h.id, h.len));
        }
        let num = (h.len / 16) as u32;
        let mut p = h.off;
        let arr_bytes = (num as usize) * 4;
        let x = bytes_to_i32(&buffer[p..p+arr_bytes]); p += arr_bytes;
        let y = bytes_to_i32(&buffer[p..p+arr_bytes]); p += arr_bytes;
        let z = bytes_to_i32(&buffer[p..p+arr_bytes]); p += arr_bytes;
        let power = bytes_to_f32(&buffer[p..p+arr_bytes]);
        areas.insert(h.id, AreaOutput { x_array: x, y_array: y, z_array: z, p_array: power });
        total_neurons += num;
    }

    Ok(DecodeOutput { success: true, total_neurons, areas, error: None })
}

/// Convert a little-endian byte slice to a Vec<i32>.
fn bytes_to_i32(bytes: &[u8]) -> Vec<i32> {
    let mut out = Vec::with_capacity(bytes.len()/4);
    for c in bytes.chunks_exact(4) {
        out.push(i32::from_le_bytes([c[0], c[1], c[2], c[3]]));
    }
    out
}

/// Convert a little-endian byte slice to a Vec<f32>.
fn bytes_to_f32(bytes: &[u8]) -> Vec<f32> {
    let mut out = Vec::with_capacity(bytes.len()/4);
    for c in bytes.chunks_exact(4) {
        out.push(f32::from_le_bytes([c[0], c[1], c[2], c[3]]));
    }
    out
}


