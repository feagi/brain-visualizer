# Icon Naming Convention - Cortical Types

**Status: MIGRATION COMPLETE** ✅

All icons now follow the cortical type naming convention where filenames map to the 3-letter unit reference extracted from cortical ID base64 strings, not full cortical IDs.

## Completed Mappings from Old Names (Cortical IDs) to New Names (Cortical Types)

### Input Sensors (IPU)
- `iinf00.png` → `iinf.png` ✅ (Infrared - unit ref: *b"inf")
- `ipro00.png` → `ipro.png` ✅ (Proximity - unit ref: *b"pro")  
- `ishk00.png` → `ishk.png` ✅ (Shock - unit ref: *b"shk")
- `ibat00.png` → `ibat.png` ✅ (Battery - unit ref: *b"bat")
- `iagpio.png` → `iagp.png` ✅ (Analog GPIO - unit ref: *b"agp")
- `idgp00.png` → `idgp.png` ✅ (Digital GPIO - unit ref: *b"dgp")
- `iv00CC.png` → `iimg.png` ✅ (Vision - unit ref: *b"img")
- `isvp00.png` → `isvp.png` ✅ (Servo Position - unit ref: *b"svp")
- `segmented_vision.png` → `isvi.png` ✅ (Segmented Vision - unit ref: *b"svi")
- `i_misc.png` → `imis.png` ✅ (Miscellaneous - unit ref: *b"mis")
- `i__acc.png` → `iacc.png` ✅ (Accelerometer - unit ref: *b"acc")
- `i__gyr.png` → `igyr.png` ✅ (Gyroscope - unit ref: *b"gyr")
- `i__bci.png` → `ibci.png` ✅ (BCI - unit ref: *b"bci")
- `i_hear.png` → `ihear.png` ✅ (Hearing - unit ref: *b"hear")
- `i___id.png` → `iid.png` ✅ (ID - unit ref: *b"id")
- `i_pres.png` → `ipres.png` ✅ (Pressure - unit ref: *b"pres")
- `ilidar.png` → `ilidar.png` ✅ (LIDAR - unit ref: *b"lidar")

### Output Actuators (OPU)
- `omot00.png` → `omot.png` ✅ (Rotary Motor - unit ref: *b"mot")
- `oagp00.png` → `oagp.png` ✅ (Analog GPIO - unit ref: *b"agp")
- `odgp00.png` → `odgp.png` ✅ (Digital GPIO - unit ref: *b"dgp")
- `o__led.png` → `oled.png` ✅ (LED - unit ref: *b"led")
- `opoint.png` → `opoint.png` ✅ (Pointer - unit ref: *b"point")
- `ov_out.png` → `ovout.png` ✅ (Vision output - unit ref: *b"vout")
- `vision_gaze_control.png` → `ogaz.png` ✅ (Gaze Control - unit ref: *b"gaz")

### Previously Missing Icons (Now Created)
- `opse.png` (Positional Servo - unit ref: *b"pse") - ✅ CREATED
- `omis.png` (Miscellaneous Motor - unit ref: *b"mis") - ✅ CREATED

## Core Types (Keep as-is)
- `_power.png` → KEEP
- `primary_vision.png` → KEEP  
- `vision_enhancements.png` → KEEP

## Implementation Notes

1. **Naming Convention**: `[i|o][unit-ref].png`
   - `i` = Input (IPU/sensors)
   - `o` = Output (OPU/actuators)
   - unit-ref = cortical type extracted from cortical ID base64 string (2-5 letters)
2. **100% Migration**: ALL icons now follow cortical type naming convention
3. No legacy cortical ID-based names remain
4. All icons ready for use when their templates are exposed in UI

## Migration Completion

- Date: December 2025
- **ALL 27 icon files** renamed to cortical types ✅
- No legacy cortical ID names remain ✅
- All scene file references updated ✅
- Godot UID cache regenerated ✅
- No errors in export process ✅
- feagi-desktop integration updated ✅

### Complete Icon Inventory (27 total)

**Input Sensors (18):**
`iacc`, `iagp`, `ibat`, `ibci`, `idgp`, `igyr`, `ihear`, `iid`, `iimg`, `iinf`, `ilidar`, `imis`, `ipres`, `ipro`, `ishk`, `isvi`, `isvp`

**Output Actuators (9):**
`oagp`, `odgp`, `ogaz`, `oled`, `omis`, `omot`, `opoint`, `opse`, `ovout`

**Special Icons (3):**
`_power`, `primary_vision`, `vision_enhancements`

