# Genome Number Detection Fix

## Problem

Brain Visualizer (BV) was not detecting `genome_num` changes and refreshing the cache when a new genome was loaded. The genome change detection code existed but was disabled due to a conditional check.

## Root Cause

In `FEAGILocalCache.gd` line 366, the genome change detection required **BOTH** `feagi_session` and `genome_num` to be non-null:

```gdscript
# OLD CODE (line 366)
if feagi_session_value != null and genome_num_value != null:
    # genome change detection code here...
```

Since `feagi_session` is still `null` (not yet implemented in feagi-core), this entire block was being skipped, preventing `genome_num` changes from being detected.

## Solution

Changed the condition to allow `genome_num` detection independently of `feagi_session`:

```gdscript
# NEW CODE (line 366)
if genome_num_value != null:
    # Handle feagi_session: use 0 as placeholder if null
    var current_feagi_session = 0
    if feagi_session_value != null:
        current_feagi_session = int(feagi_session_value)
    
    var current_genome_num = int(genome_num_value)
    # ... rest of genome change detection logic
```

## Changes Made

### File: `brain-visualizer/godot_source/addons/FeagiCoreIntegration/FeagiCore/LocalCache/FEAGILocalCache.gd`

1. **Line 366**: Changed condition from `if feagi_session_value != null and genome_num_value != null:` to `if genome_num_value != null:`

2. **Lines 367-371**: Added safe handling for null `feagi_session`:
   ```gdscript
   var current_feagi_session = 0  # Default to 0 if null
   if feagi_session_value != null:
       current_feagi_session = int(feagi_session_value)
   ```

3. **Lines 389-391**: Added debug logging:
   ```gdscript
   if _previous_genome_num != current_genome_num:
       print("🧬 [GENOME-CHANGE-DEBUG] genome_num changed: %d → %d (will reload: %s)" % [_previous_genome_num, current_genome_num, genome_changed])
   ```

## How It Works Now

1. **First Genome Load** (e.g., essential genome):
   - `genome_num` changes from `0` → `1`
   - Debug log: `genome_num changed: 0 → 1 (will reload: false)`
   - No reload triggered (initial load, `_previous_genome_num` was 0)
   - `_previous_genome_num` updated to `1`

2. **Second Genome Load** (e.g., barebones genome):
   - `genome_num` changes from `1` → `2`
   - Debug log: `genome_num changed: 1 → 2 (will reload: true)`
   - **Reload triggered!** ✅
   - `genome_refresh_needed` signal emitted
   - Cache cleared and scene refreshed
   - `_previous_genome_num` updated to `2`

3. **Subsequent Loads**:
   - Each genome load increments `genome_num`
   - BV detects the change and refreshes

## Testing

1. Start FEAGI and BV
2. Load essential genome
3. Check BV console for: `genome_num changed: 0 → 1`
4. Load barebones genome
5. Check BV console for: `genome_num changed: 1 → 2 (will reload: true)`
6. Verify BV scene refreshes automatically

## Expected Console Output

```
🧬 [GENOME-CHANGE-DEBUG] genome_num changed: 0 → 1 (will reload: false)
🧬 [GENOME-CHANGE-DEBUG] genome_num changed: 1 → 2 (will reload: true)
⚡ FEAGI CACHE: Genome refresh triggered - genome changed (num: 1 → 2)
```

## Compatibility

- ✅ Works with `feagi_session = null` (current state)
- ✅ Will continue to work when `feagi_session` is implemented
- ✅ Backward compatible with existing genome tracking
- ✅ Respects cooldown period (10 seconds between reloads)

## Related Code

### Genome Change Detection Logic (line 391)
```gdscript
var genome_changed = (_previous_genome_num != 0 and current_genome_num != _previous_genome_num)
```

This ensures:
- Initial load (`0 → 1`) doesn't trigger reload
- Subsequent changes (`1 → 2`, `2 → 3`, etc.) do trigger reload

### Reload Trigger (line 448)
```gdscript
genome_refresh_needed.emit(current_feagi_session, current_genome_num, reason)
```

This signal triggers the cache refresh and scene update in BV.

## Future Considerations

When `feagi_session` is implemented in feagi-core:
- Session-based detection will work alongside genome-based detection
- Both types of changes will trigger cache refresh
- No code changes needed in BV (already handles both)

---

**Date**: 2025-11-25  
**Fixed By**: AI Assistant  
**Tested**: Pending user verification  
**Status**: Ready for testing


