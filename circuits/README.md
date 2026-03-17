# Circuits Library

This folder contains reusable circuit packages that appear in the Brain Visualizer
"Add Neural Circuit" selector.

## Structure

- Each circuit lives in its own subfolder under `circuits/`.
- Each circuit folder must include:
  - `circuit_image.png` (icon shown in the selector)
  - `genome.json` (genome payload sent to FEAGI)
- The `manifest.json` file defines how circuits are displayed.

## Manifest format

The `manifest.json` file contains a `circuits` object. Each key is the circuit
folder name. Values describe display metadata.

Example:

```json
{
  "circuits": {
    "my_circuit": {
      "title": "My Circuit",
      "icon_path": "my_circuit/circuit_image.png",
      "markdown_path": "my_circuit/README.md"
    }
  }
}
```

Paths in the manifest are relative to `circuits/`.
