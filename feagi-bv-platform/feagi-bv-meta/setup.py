"""Setup script for feagi-bv meta-package with platform-specific dependencies."""

from setuptools import setup, find_packages
import sys
import os

# Read version from pyproject.toml
def get_version():
    """Extract version from pyproject.toml."""
    try:
        with open('pyproject.toml', 'r') as f:
            for line in f:
                if line.startswith('version ='):
                    # Extract version string: version = "2.0.3"
                    return line.split('=')[1].strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return "1.0.0"  # Fallback version

# Determine platform-specific dependency
platform_deps = []
if sys.platform.startswith('linux'):
    platform_deps = [f'feagi-bv-linux>={get_version()}']
elif sys.platform == 'darwin':
    # Detect macOS architecture
    import platform
    machine = platform.machine().lower()
    if machine in ('arm64', 'aarch64'):
        platform_deps = [f'feagi-bv-macos-arm64>={get_version()}']
    elif machine in ('x86_64', 'amd64'):
        platform_deps = [f'feagi-bv-macos-x86_64>={get_version()}']
    else:
        # Fallback to arm64 (Apple Silicon is now default)
        platform_deps = [f'feagi-bv-macos-arm64>={get_version()}']
elif sys.platform == 'win32':
    platform_deps = [f'feagi-bv-windows>={get_version()}']
else:
    print(f"Warning: Unsupported platform '{sys.platform}'. No binaries will be installed.")

# Setup configuration (metadata comes from pyproject.toml)
setup(
    install_requires=[
        'feagi-core>=2.1.1',
        'toml>=0.10.2',
    ] + platform_deps,
)
