# Group ID Feature Implementation

## Summary

Added Group ID selection to the "Add Input/Output Cortical Area" workflow, allowing users to create multiple instances of the same cortical type with different group IDs. The system validates that group IDs are unique for each cortical type and prevents duplicate creation.

## Feature Overview

### What is Group ID?

- **Group ID** is byte 7 (the last byte) of the 8-byte cortical ID
- Allows multiple instances of the same cortical type in a genome
- Example: `isvi0000` (group 0) and `isvi0001` (group 1) can both exist

### Cortical ID Structure Reminder

```
Byte 0-3: cortical_subtype (e.g., "isvi", "imot")
Byte 4:   encoding_flags
Byte 5:   reserved
Byte 6:   unit_id
Byte 7:   group_id ← THIS IS WHAT WE'RE CONFIGURING
```

## UI Changes

### Added Field: Group ID

**Location:** IOPU Definition Panel (after device is selected)

**Type:** SpinBox (integer input)
- **Min Value:** 0
- **Max Value:** 255
- **Default Value:** 0
- **Position:** First field (above Device Count)

**Field Order:**
1. **Device Name** (read-only label)
2. **Group ID** (SpinBox) ← NEW
3. **Device Count** (SpinBox)
4. **Location** (Vector3i)

### Real-Time Validation

As the user changes the Group ID:

1. **Check Existing Areas** - Scans all cortical areas in the genome
2. **Decode Cortical IDs** - Extracts group_id from base64-encoded cortical IDs
3. **Match Checking** - Looks for cortical_type + group_id collision
4. **Visual Feedback** - Updates status label with color-coded message
5. **Button Control** - Disables "Add" button if collision detected

### Validation States

#### ✓ Valid (Green)
```
✓ Group ID 0 is available for isvi
```
- Status label shows green text
- Add button is **enabled**
- User can proceed with creation

#### ⚠ Invalid (Red)
```
⚠ Group ID 0 already exists for isvi (Segmented Vision Sensor)
```
- Status label shows red text
- Add button is **disabled**
- Tooltip on Add button shows warning message

## Implementation Details

### Files Modified

#### 1. `PartSpawnCorticalAreaIOPU.tscn`
**Changes:**
- Added `GroupID` SpinBox node (min: 0, max: 255)
- Added "Group ID:" label
- Added `GroupIDStatus` label for validation messages
- Connected `value_changed` signal to `_on_group_id_changed()`

#### 2. `PartSpawnCorticalAreaIOPU.gd`
**Added Variables:**
```gdscript
var group_id: SpinBox
var _group_id_status_label: Label
```

**Added Signal:**
```gdscript
signal group_id_validation_changed(is_valid: bool, message: String)
```

**Added Methods:**
- `_on_group_id_changed(_value: float)` - Called when user changes group ID
- `_validate_group_id()` - Checks if cortical_type + group_id already exists
- `_decode_cortical_id_group(cortical_id: String) -> int` - Extracts group_id from base64 cortical ID
- `get_selected_group_id() -> int` - Returns current group ID value

**Validation Logic:**
```gdscript
func _validate_group_id() -> void:
    # Get selected type and group ID
    var cortical_type_key: String = _selected_template.ID
    var selected_group_id: int = int(group_id.value)
    
    # Scan all existing cortical areas
    for cortical_id in existing_areas.keys():
        if cortical_id_str.begins_with(cortical_type_key):
            # Decode and check group_id (byte 7)
            var decoded_group = _decode_cortical_id_group(cortical_id_str)
            if decoded_group == selected_group_id:
                # COLLISION DETECTED
                emit invalid state
                return
    
    # Group ID is available
    emit valid state
}
```

#### 3. `WindowCreateCorticalArea.gd`
**Added Variable:**
```gdscript
var _add_button: Button
```

**Added Connection:**
```gdscript
_IOPU_definition.group_id_validation_changed.connect(_on_group_id_validation_changed)
```

**Added Method:**
```gdscript
func _on_group_id_validation_changed(is_valid: bool, message: String) -> void:
    _add_button.disabled = !is_valid
    _add_button.tooltip_text = message if !is_valid else ""
```

**Updated Creation Calls:**
- Added `selected_group_id` variable extraction
- Passed group_id to `add_IOPU_cortical_area()` for both IPU and OPU

#### 4. `FEAGIRequests.gd`
**Updated Function Signature:**
```gdscript
func add_IOPU_cortical_area(..., group_id: int = 0) -> FeagiRequestOutput:
```

**Updated Request Payload:**
```gdscript
var dict_to_send: Dictionary = {
    "cortical_id": IOPU_template.ID,
    "group_id": group_id,  # ← NEW
    ...
}
```

## Usage Flow

### Creating First Instance (Group 0)

1. Click "Add Input Cortical Area"
2. Select "Segmented Vision" icon
3. Positioning window opens with:
   - Device Name: "Segmented Vision"
   - **Group ID: 0** (default)
   - Device Count: 1
   - Location: [40, 0, 0]
4. Status shows: ✓ Group ID 0 is available for isvi
5. Click "Add" - creates `isvi` with group_id=0

### Creating Second Instance (Group 1)

1. Click "Add Input Cortical Area" again
2. Select "Segmented Vision" icon
3. Positioning window opens
4. **Change Group ID to 1**
5. Status shows: ✓ Group ID 1 is available for isvi
6. Click "Add" - creates `isvi` with group_id=1

### Preventing Duplicates

1. Click "Add Input Cortical Area"
2. Select "Segmented Vision" icon
3. Group ID defaults to 0
4. Status shows: ⚠ Group ID 0 already exists for isvi (Segmented Vision Sensor)
5. Add button is **grayed out** (disabled)
6. User must change Group ID to proceed

## Backend Integration

The `group_id` is sent to FEAGI Core in the creation request:

```json
{
  "cortical_id": "isvi",
  "group_id": 1,
  "device_count": 1,
  "coordinates_3d": [40, 0, 0],
  "cortical_type": "sensory",
  ...
}
```

FEAGI Core will construct the full 8-byte cortical ID by encoding:
- Bytes 0-3: Type ("isvi")
- Byte 4-5: Encoding flags
- Byte 6: Unit ID (from device_count iteration)
- Byte 7: **Group ID** (from user input)

## Benefits

1. **Multiple Instances** - Users can have multiple cameras, motors, etc.
2. **Collision Prevention** - Cannot accidentally overwrite existing areas
3. **Clear Feedback** - Visual indication of what group IDs are available
4. **Intuitive UX** - Red/green color coding, disabled button when invalid
5. **Tooltip Help** - Hover over disabled button shows why it's disabled

## Testing Scenarios

### Test 1: Create First Group
1. Add isvi with group_id=0
2. Verify status shows "available"
3. Verify button is enabled
4. Verify creation succeeds

### Test 2: Prevent Duplicate
1. Try to add isvi with group_id=0 again
2. Verify status shows "already exists"
3. Verify button is disabled
4. Verify tooltip explains why

### Test 3: Create Second Group
1. Add isvi with group_id=1
2. Verify status shows "available"
3. Verify button is enabled
4. Verify creation succeeds

### Test 4: Different Types Don't Conflict
1. Create iinf with group_id=0
2. Create isvi with group_id=0
3. Both should succeed (different cortical types)

### Test 5: Validation Updates in Real-Time
1. Select isvi
2. Set group_id=0 → should show "exists"
3. Change to group_id=5 → should show "available"
4. Change back to group_id=0 → should show "exists" again

## Related Files

- **UI Scene:** `BrainVisualizer/UI/Windows/CreateCorticalArea/Parts/PartSpawnCorticalAreaIOPU.tscn`
- **UI Logic:** `BrainVisualizer/UI/Windows/CreateCorticalArea/Parts/PartSpawnCorticalAreaIOPU.gd`
- **Parent Window:** `BrainVisualizer/UI/Windows/CreateCorticalArea/WindowCreateCorticalArea.gd`
- **API Requests:** `addons/FeagiCoreIntegration/FeagiCore/FEAGIRequests.gd`
- **Cortical ID Decoder:** `/feagi-core/crates/feagi-types/src/cortical_id_decoder.rs`

## Future Enhancements

1. **Suggest Next Available** - Auto-suggest the next available group ID
2. **Show All Groups** - Display list of existing group IDs for this type
3. **Group Management** - Allow renaming/deleting entire groups
4. **Batch Creation** - Create multiple group IDs at once

