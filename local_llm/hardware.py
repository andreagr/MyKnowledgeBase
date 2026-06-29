"""Collect raw hardware signals from the host machine."""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
from typing import Any

import paths

# Reserve headroom for the embedding model, Qdrant, and the OS alongside the LLM.
RAG_STACK_RESERVE_GB = 1.5
MIN_PLATFORM_RAM_GB = 8.0
MIN_PLATFORM_DISK_GB = 8.0


def _round_gb(value_bytes: int | float) -> float:
    return round(float(value_bytes) / (1024**3), 1)


def _detect_vram_gb() -> float | None:
    if platform.system() != "Windows":
        return None
    try:
        result = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=memory.total",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0 or not result.stdout.strip():
        return None
    try:
        total_mib = max(int(line.strip()) for line in result.stdout.splitlines() if line.strip())
    except ValueError:
        return None
    return round(total_mib / 1024, 1)


def collect_specs() -> dict[str, Any]:
    import psutil

    memory = psutil.virtual_memory()
    disk = shutil.disk_usage(paths.get_data_dir())
    vram_gb = _detect_vram_gb()

    return {
        "platform": platform.system(),
        "architecture": platform.machine(),
        "cpu_cores": os.cpu_count() or 1,
        "total_ram_gb": _round_gb(memory.total),
        "available_ram_gb": _round_gb(memory.available),
        "free_disk_gb": _round_gb(disk.free),
        "vram_gb": vram_gb,
        "has_gpu": vram_gb is not None and vram_gb > 0,
    }
