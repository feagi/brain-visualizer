# Icon Renaming Plan - Cortical ID to Cortical Type

## Mapping from Old Names (Cortical IDs) to New Names (Cortical Types)

### Input Sensors (IPU)
- `iinf00.png` → `iinf.png` (Infrared - unit ref: *b"inf")
- `ipro00.png` → `ipro.png` (Proximity - unit ref: *b"pro")  
- `ishk00.png` → `ishk.png` (Shock - unit ref: *b"shk")
- `ibat00.png` → `ibat.png` (Battery - unit ref: *b"bat")
- `iagpio.png` → `iagp.png` (Analog GPIO - unit ref: *b"agp")
- `idgp00.png` → KEEP (Digital GPIO - not in current templates)
- `iv00CC.png` → `iimg.png` (Vision - unit ref: *b"img")
- `isvp00.png` → KEEP (Servo Position - appears to be sensor, not in current templates)
- `segmented_vision.png` → `isvi.png` (Segmented Vision - unit ref: *b"svi")
- `i_misc.png` → `imis.png` (Miscellaneous - unit ref: *b"mis")
- `i__acc.png` → KEEP (Accelerometer - not in exposed templates yet)
- `i__gyr.png` → KEEP (Gyroscope - not in exposed templates yet)
- `i__bci.png` → KEEP (BCI - not in exposed templates yet)
- `i_hear.png` → KEEP (Hearing - not in exposed templates yet)
- `i___id.png` → KEEP (ID - not in exposed templates yet)
- `i_pres.png` → KEEP (Pressure - not in exposed templates yet)
- `ilidar.png` → KEEP (LIDAR - not in exposed templates yet)

### Output Actuators (OPU)
- `omot00.png` → `omot.png` (Rotary Motor - unit ref: *b"mot")
- `oagp00.png` → KEEP (Analog GPIO - servo might map to `opse.png` but need clarification)
- `odgp00.png` → KEEP (Digital GPIO - not in current templates)
- `o__led.png` → KEEP (LED - not in current templates)
- `opoint.png` → KEEP (Pointer - not in current templates)
- `ov_out.png` → KEEP (Vision output - not in current templates)
- `vision_gaze_control.png` → `ogaz.png` (Gaze Control - unit ref: *b"gaz")

### Missing Icons Needed
- `opse.png` (Positional Servo - unit ref: *b"pse") - MISSING, might use oagp00.png?
- `omis.png` (Miscellaneous Motor - unit ref: *b"mis") - MISSING

## Core Types (Keep as-is)
- `_power.png` → KEEP
- `primary_vision.png` → KEEP  
- `vision_enhancements.png` → KEEP

## Implementation Notes

1. The new naming convention is: `[i|o][3-letter-unit-ref].png`
2. Files marked KEEP are sensors/actuators not yet exposed in the current template system
3. We should only rename files that map to currently exposed template types
4. Missing icons need to be created or sourced from existing similar icons

