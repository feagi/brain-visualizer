"""Setup script for feagi-bv meta-package with platform-specific dependencies.

Uses environment markers so ALL platform deps are in metadata regardless of
build host. Otherwise building on Linux bakes only feagi-bv-linux, and
pip install feagi-bv on Windows never pulls feagi-bv-windows.
"""

from setuptools import setup, find_packages


def get_version():
    """Extract version from pyproject.toml."""
    try:
        with open("pyproject.toml", encoding="utf-8") as f:
            for line in f:
                if line.startswith("version ="):
                    return line.split("=")[1].strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return "1.0.0"


VERSION = get_version()

setup(
    install_requires=[
        "feagi-core>=2.1.1",
        "toml>=0.10.2",
        f"feagi-bv-linux>={VERSION} ; sys_platform == 'linux'",
        f"feagi-bv-windows>={VERSION} ; sys_platform == 'win32'",
        f"feagi-bv-macos-arm64>={VERSION} ; sys_platform == 'darwin' and platform_machine == 'arm64'",
        f"feagi-bv-macos-x86_64>={VERSION} ; sys_platform == 'darwin' and platform_machine == 'x86_64'",
    ],
)
