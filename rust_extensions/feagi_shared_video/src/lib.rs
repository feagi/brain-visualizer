use godot::prelude::*;
use godot::classes::{Image, ImageTexture};
use godot::classes::image::Format;
use memmap2::Mmap;
use memmap2::MmapOptions;
use std::fs::File;
use std::path::PathBuf;

const HEADER_SIZE: usize = 256;
const MAGIC: &[u8; 8] = b"FEAGIVID";

fn read_u32_le(buf: &[u8], offset: usize) -> Option<u32> {
    if offset + 4 > buf.len() {
        return None;
    }
    let mut b = [0u8; 4];
    b.copy_from_slice(&buf[offset..offset + 4]);
    Some(u32::from_le_bytes(b))
}

fn read_u64_le(buf: &[u8], offset: usize) -> Option<u64> {
    if offset + 8 > buf.len() {
        return None;
    }
    let mut b = [0u8; 8];
    b.copy_from_slice(&buf[offset..offset + 8]);
    Some(u64::from_le_bytes(b))
}

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct SharedMemVideo {
    #[base]
    base: Base<RefCounted>,
    path: Option<String>,
    mmap: Option<Mmap>,
}

#[godot_api]
impl IRefCounted for SharedMemVideo {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base, path: None, mmap: None }
    }
}

#[godot_api]
impl SharedMemVideo {
    /// Open and map a shared memory file produced by the Python video agent.
    /// Path should point to the memory-mapped file created by SharedFrameWriter.
    #[func]
    pub fn open(&mut self, path: GString) -> bool {
        let path_str = path.to_string();
        let p = PathBuf::from(&path_str);
        let file = match File::open(&p) {
            Ok(f) => f,
            Err(err) => {
                godot_error!("SharedMemVideo: failed to open file {}: {}", path_str, err);
                return false;
            }
        };
        let mmap = match unsafe { MmapOptions::new().map(&file) } {
            Ok(m) => m,
            Err(err) => {
                godot_error!("SharedMemVideo: mmap failed for {}: {}", path_str, err);
                return false;
            }
        };

        if mmap.len() < HEADER_SIZE {
            godot_error!("SharedMemVideo: file too small to contain header: {} bytes", mmap.len());
            return false;
        }
        // Validate magic
        if &mmap[0..8] != MAGIC {
            godot_error!("SharedMemVideo: invalid magic in header");
            return false;
        }

        self.path = Some(path_str);
        self.mmap = Some(mmap);
        // Log header info for debugging (direct read)
        let mapref = self.mmap.as_ref().unwrap();
        let w = read_u32_le(mapref, 12).unwrap_or(0);
        let h = read_u32_le(mapref, 16).unwrap_or(0);
        let ch = read_u32_le(mapref, 20).unwrap_or(0);
        let slots = read_u32_le(mapref, 28).unwrap_or(0);
        let stride = read_u64_le(mapref, 32).unwrap_or(0);
        let widx = read_u32_le(mapref, 40).unwrap_or(0);
        let seq = read_u64_le(mapref, 44).unwrap_or(0);
        godot_print!(
            "SharedMemVideo: mapped file ok (w={} h={} ch={} slots={} stride={} write_idx={} seq={} len={})",
            w, h, ch, slots, stride, widx, seq, mapref.len()
        );
        true
    }

    /// Read the latest frame into an ImageTexture. Returns null if unavailable.
    #[func]
    pub fn get_texture(&self) -> Option<Gd<ImageTexture>> {
        let mmap = match &self.mmap {
            Some(m) => m,
            None => return None,
        };

        if mmap.len() < HEADER_SIZE {
            return None;
        }

        // Read header (first pass)
        if &mmap[0..8] != MAGIC {
            return None;
        }

        let width = match read_u32_le(mmap, 12) { Some(v) => v, None => return None } as i64;
        let height = match read_u32_le(mmap, 16) { Some(v) => v, None => return None } as i64;
        let channels = match read_u32_le(mmap, 20) { Some(v) => v, None => return None } as usize;
        if channels != 3 || width <= 0 || height <= 0 {
            return None;
        }
        let frame_stride = match read_u64_le(mmap, 32) { Some(v) => v, None => return None } as usize;
        let num_slots = match read_u32_le(mmap, 28) { Some(v) => v, None => return None } as usize;
        let write_index_1 = match read_u32_le(mmap, 40) { Some(v) => v, None => return None } as usize;
        let seq_1 = match read_u64_le(mmap, 44) { Some(v) => v, None => return None };

        if num_slots == 0 {
            return None;
        }

        let header_ok = HEADER_SIZE + frame_stride * num_slots <= mmap.len();
        if !header_ok {
            return None;
        }

        // Compute offset
        let frame_offset = HEADER_SIZE + (write_index_1 % num_slots) * frame_stride;
        if frame_offset + frame_stride > mmap.len() {
            return None;
        }

        // Copy frame bytes
        let mut frame_data = Vec::with_capacity(frame_stride);
        frame_data.extend_from_slice(&mmap[frame_offset..frame_offset + frame_stride]);

        // Verify sequence did not change; if changed, try one more time
        let write_index_2 = match read_u32_le(mmap, 40) { Some(v) => v, None => return None } as usize;
        let seq_2 = match read_u64_le(mmap, 44) { Some(v) => v, None => return None };
        if seq_2 != seq_1 || write_index_2 != write_index_1 {
            let frame_offset2 = HEADER_SIZE + (write_index_2 % num_slots) * frame_stride;
            if frame_offset2 + frame_stride <= mmap.len() {
                frame_data.clear();
                frame_data.extend_from_slice(&mmap[frame_offset2..frame_offset2 + frame_stride]);
            }
        }

        // Build Image and texture
        let image = Image::create_from_data(
            width as i32,
            height as i32,
            false,
            Format::RGB8,
            &PackedByteArray::from(&frame_data[..]),
        )?;
        let texture = ImageTexture::create_from_image(&image)?;
        Some(texture)
    }

    /// Return current header info for debugging and UI display.
    #[func]
    pub fn get_header_info(&self) -> Dictionary {
        let mut d = Dictionary::new();
        if let Some(mmap) = self.mmap.as_ref() {
            if mmap.len() >= HEADER_SIZE && &mmap[0..8] == MAGIC {
                if let Some(v) = read_u32_le(mmap, 12) { d.set("width", v as i64); }
                if let Some(v) = read_u32_le(mmap, 16) { d.set("height", v as i64); }
                if let Some(v) = read_u32_le(mmap, 20) { d.set("channels", v as i64); }
                if let Some(v) = read_u32_le(mmap, 28) { d.set("num_slots", v as i64); }
                if let Some(v) = read_u64_le(mmap, 32) { d.set("frame_stride", v as i64); }
                if let Some(v) = read_u32_le(mmap, 40) { d.set("write_index", v as i64); }
                if let Some(v) = read_u64_le(mmap, 44) { d.set("frame_seq", v as i64); }
                d.set("file_len", mmap.len() as i64);
                return d;
            }
        }
        d.set("error", String::from("no_header"));
        d
    }

    /// Get the file path that was opened (for reopening on restart detection).
    #[func]
    pub fn get_path(&self) -> GString {
        self.path.as_ref()
            .map(|p| GString::from(p.as_str()))
            .unwrap_or_else(|| GString::from(""))
    }
}

struct Lib;

#[gdextension]
unsafe impl ExtensionLibrary for Lib {}


