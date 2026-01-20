# PNG Icon System for Cortical Areas

This directory contains PNG icon files for special cortical areas that should be rendered as billboards instead of 3D shapes.

## How to Add Custom Icons

1. **Create your PNG icon** (recommended size: 128x128 or 256x256 pixels)
2. **Name the file** using the cortical area ID: `{cortical_id}.png`
3. **Place the file** in this directory
4. **The system will automatically** load and display your custom icon

## Supported Cortical Areas

The following cortical area IDs are configured to use PNG icons:

- `_death.png` - Death/mortality indicator (placeholder: red with cross)
- `_health.png` - Health status indicator (placeholder: green with cross)  
- `_energy.png` - Energy level indicator (placeholder: yellow with cross)
- `_status.png` - General status indicator (placeholder: blue with cross)

## Adding New Icon Areas

To add support for additional cortical areas:

1. **Edit the code** in `UI_BrainMonitor_DirectPointsCorticalAreaRenderer.gd`
2. **Find the function** `_should_use_png_icon()`
3. **Add your cortical area ID** to the `png_icon_areas` array
4. **Add your PNG file** to this directory

## Icon Requirements

- **Format**: PNG with transparency support
- **Size**: 128x128 to 512x512 pixels (power of 2 recommended)
- **Transparency**: Alpha channel supported for clean edges
- **Content**: Should be clearly visible against various backgrounds

## Placeholder System

If a PNG file is not found, the system automatically creates a colored placeholder with:
- Colored background based on the cortical area type
- White border for visibility
- Simple cross pattern as a placeholder symbol
- Appropriate glow effects for special areas (e.g., red glow for death)

## Billboard Behavior

PNG icons are rendered as:
- **Billboards** that always face the camera
- **Always visible** (no depth testing)
- **Positioned above** the cortical area center
- **3x3 unit size** for good visibility
- **Hover responsive** like other cortical areas

## Example

To add a custom death icon:
1. Create `_death.png` (your skull/death symbol)
2. Place it in this directory
3. The system will automatically use it instead of the red placeholder

The icon will appear as a billboard floating above the cortical area position with appropriate glow effects.
