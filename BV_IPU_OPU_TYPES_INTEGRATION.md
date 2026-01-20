# Brain Visualizer IPU/OPU Types Integration

## Summary

Integrated the new dynamic IPU/OPU types API endpoints into Brain Visualizer, replacing the old hardcoded template system. The "Add Input Cortical Area" and "Add Output Cortical Area" windows now fetch available types directly from the FEAGI API and display them with properly named icons.

## Changes Made

### 1. Icon File Renaming

**Location:** `godot_source/BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/`

**Renamed Files (Old → New):**

**Input Sensors (IPU):**
- `iinf00.png` → `iinf.png` (Infrared Sensor)
- `ipro00.png` → `ipro.png` (Proximity Sensor)
- `ishk00.png` → `ishk.png` (Shock Sensor)
- `ibat00.png` → `ibat.png` (Battery Sensor)
- `iagpio.png` → `iagp.png` (Analog GPIO)
- `iv00CC.png` → `iimg.png` (Vision Sensor)
- `segmented_vision.png` → `isvi.png` (Segmented Vision)
- `i_misc.png` → `imis.png` (Miscellaneous Sensor)

**Output Actuators (OPU):**
- `omot00.png` → `omot.png` (Rotary Motor)
- `vision_gaze_control.png` → `ogaz.png` (Gaze Control)

**Created Missing Icons:**
- `opse.png` (Positional Servo - copied from `oagp00.png`)
- `omis.png` (Miscellaneous Motor - copied from `omot.png`)

**Naming Convention:** `[i|o][3-letter-unit-ref].png`
- `i` prefix for inputs (IPU)
- `o` prefix for outputs (OPU)
- 3-letter unit reference from `feagi-data-processing` templates (e.g., `inf`, `mot`, `gaz`)

### 2. API Endpoint Registration

**File:** `godot_source/addons/FeagiCoreIntegration/FeagiCore/Networking/API/FEAGIHTTPAddressList.gd`

**Added:**
```gdscript
var GET_corticalAreas_ipu_types: StringName = "/v1/cortical_area/ipu/types"
var GET_corticalAreas_opu_types: StringName = "/v1/cortical_area/opu/types"
```

### 3. Window Update - Dynamic API Integration

**File:** `godot_source/BrainVisualizer/UI/Windows/SelectCorticalTemplate/WindowSelectCorticalTemplate.gd`

**Major Changes:**

1. **`_populate_grid()` - Now calls API endpoints:**
   - Removed hardcoded template iteration from cache
   - Added `await _populate_from_api_endpoint()` call
   - Endpoints called based on cortical type (IPU vs OPU)

2. **`_populate_from_api_endpoint()` - New function:**
   - Makes HTTP GET request to `/v1/cortical_area/ipu/types` or `/opu/types`
   - Parses JSON response with type metadata
   - Sorts types alphabetically by description
   - Creates tiles dynamically for each type

3. **`_add_tile_from_api_data()` - New function:**
   - Creates UI tile from API response data
   - Loads icon using type_key (e.g., "iinf", "omot")
   - Displays description from API metadata
   - Stores metadata in button for later use

4. **`_choose_from_api()` - New function:**
   - Handles selection of API-based type
   - Creates `CorticalTemplate` object from API metadata
   - Includes resolution, structure, description from API
   - Emits `template_chosen` signal with newly created template

**Response Format (from API):**
```json
{
  "iinf": {
    "description": "Infrared Sensor",
    "encodings": ["absolute", "incremental"],
    "formats": ["linear", "fractional"],
    "units": 1,
    "resolution": [1, 1, 1],
    "structure": "asymmetric"
  },
  "ipro": {
    "description": "Proximity Sensor",
    "encodings": ["absolute", "incremental"],
    "formats": ["linear", "fractional"],
    "units": 1,
    "resolution": [1, 1, 1],
    "structure": "asymmetric"
  },
  "iimg": {
    "description": "Vision Sensor",
    "encodings": ["absolute", "incremental"],
    "formats": [],
    "units": 1,
    "resolution": [64, 64, 1],
    "structure": "asymmetric"
  },
  ...
}
```

## Benefits

1. **Dynamic Discovery** - New sensor/motor types automatically appear when added to `feagi-data-processing`
2. **Single Source of Truth** - Icons named after template definitions
3. **No Hardcoding** - All type information comes from API
4. **Maintainable** - Adding new types requires no BV code changes
5. **Consistent Naming** - Icon filenames match cortical type identifiers

## Testing

### Manual Test Steps

1. **Start FEAGI Core:**
   ```bash
   cd /Users/nadji/code/FEAGI-2.0/feagi-core
   cargo run --package feagi
   ```

2. **Start Brain Visualizer:**
   - Open Godot
   - Load `brain-visualizer/godot_source/project.godot`
   - Run the project

3. **Test Input Window:**
   - Click "Add Input Cortical Area" button
   - Verify window populates with sensor icons
   - Verify icons load correctly (iinf.png, ipro.png, etc.)
   - Verify descriptions display from API

4. **Test Output Window:**
   - Click "Add Output Cortical Area" button
   - Verify window populates with actuator icons
   - Verify icons load correctly (omot.png, ogaz.png, etc.)
   - Verify descriptions display from API

5. **Verify API Calls:**
   - Check Godot console for API request logs
   - Should see "Fetching IPU/OPU types from API..."
   - Should see "Received N IPU/OPU types"

### Expected Behavior

- Windows should populate with 9 IPU types and 4 OPU types (based on current templates)
- Icons should display correctly for all types
- Clicking an icon should select that type and close the window
- No errors in Godot console

## Flow After Icon Selection

1. User clicks an icon in `WindowSelectCorticalTemplate`
2. `_choose_from_api()` creates a `CorticalTemplate` object from API metadata
3. Signal `template_chosen` is emitted with the template
4. `WindowManager` catches the signal and opens `WindowCreateCorticalArea`
5. `WindowCreateCorticalArea` displays the positioning interface:
   - Location (x, y, z coordinates)
   - Device count (for multi-unit types)
   - Visual preview in 3D scene
   - Create/Cancel buttons
6. User positions the cortical area and clicks Create
7. Cortical area is created in FEAGI via API

## Compatibility Notes

- **No Cache Dependency:** The system no longer depends on `FeagiCore.feagi_local_cache.IPU_templates` or `OPU_templates`
- **Fully API-Driven:** All type information comes from the new API endpoints
- **Template Creation:** `CorticalTemplate` objects are created on-the-fly from API responses

## Files Not Modified (Legacy Support)

These files still reference old icon names and should be updated in future iterations:
- `UIManager.gd` - `KNOWN_ICON_PATHS` mapping (fallback lookup)
- Files keeping old naming: `i__acc.png`, `i__gyr.png`, `i__bci.png`, etc. (not in exposed templates yet)

## Future Improvements

1. **Complete Migration** - Remove dependency on `FeagiCore.feagi_local_cache` templates
2. **Icon Updates** - Update/create better icons for `opse.png` and `omis.png` (currently copies)
3. **Expose More Templates** - Add accelerometer, gyroscope, BCI, etc. to `feagi-data-processing` templates
4. **Encoding/Format Selection** - Use `encodings` and `formats` fields from API to let users choose encoding type
5. **Unit Count Display** - Show `units` field to indicate multi-area types (e.g., segmented vision = 9 units)

## Related Documentation

- **FEAGI Core API:** `/Users/nadji/code/FEAGI-2.0/feagi-core/IPU_OPU_TYPES_ENDPOINTS_IMPLEMENTATION.md`
- **Template Definitions:** `/Users/nadji/code/FEAGI-2.0/feagi-data-processing/feagi-data-structures/src/templates/`
- **Icon Rename Plan:** `godot_source/BrainVisualizer/UI/GenericResources/CorticalAreaIcons/knowns/RENAME_PLAN.md`

