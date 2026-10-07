"""Tests for Linux Rust target selection in the Godot extension build."""

import importlib.util
from pathlib import Path

import pytest

_BUILD_SCRIPT = (
    Path(__file__).resolve().parents[2] / "rust_extensions" / "build.py"
)
_SPEC = importlib.util.spec_from_file_location(
    "feagi_bv_rust_build", _BUILD_SCRIPT
)
assert _SPEC is not None and _SPEC.loader is not None
_BUILD = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_BUILD)


def test_linux_x86_64_triple():
    """x86_64 and amd64 both map to the x86_64 GNU triple."""
    assert (
        _BUILD.linux_gnu_target_triple("x86_64")
        == "x86_64-unknown-linux-gnu"
    )
    assert (
        _BUILD.linux_gnu_target_triple("amd64")
        == "x86_64-unknown-linux-gnu"
    )


def test_linux_arm64_triple():
    """aarch64 and arm64 both map to the aarch64 GNU triple."""
    assert (
        _BUILD.linux_gnu_target_triple("aarch64")
        == "aarch64-unknown-linux-gnu"
    )
    assert (
        _BUILD.linux_gnu_target_triple("arm64")
        == "aarch64-unknown-linux-gnu"
    )


def test_linux_unknown_architecture_is_rejected():
    """An unrecognized machine does not select a triple."""
    with pytest.raises(ValueError, match="Unsupported Linux architecture"):
        _BUILD.linux_gnu_target_triple("riscv64")


def test_export_and_gdextension_declare_linux_arm64():
    """Release export and GDExtension manifests include Linux ARM64."""
    root = Path(__file__).resolve().parents[2]
    preset = (root / "godot_source" / "export_presets.cfg").read_text(
        encoding="utf-8"
    )
    assert 'name="Linux/X11-arm64"' in preset
    assert 'binary_format/architecture="arm64"' in preset

    required = (
        "godot_source/addons/FeagiCoreIntegration/feagi_data_deserializer.gdextension",
        "godot_source/addons/FeagiCoreIntegration/feagi_type_system.gdextension",
        "godot_source/addons/FeagiCoreIntegration/feagi_agent_client.gdextension",
        "godot_source/addons/feagi_shared_video/feagi_shared_video.gdextension",
        "godot_source/addons/feagi_embedded/feagi_embedded.gdextension",
    )
    for relative in required:
        text = (root / relative).read_text(encoding="utf-8")
        assert "linux.release.arm64" in text, relative
