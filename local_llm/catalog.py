"""Curated local models available for on-device document Q&A."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

Tier = Literal["light", "balanced", "quality"]


@dataclass(frozen=True)
class LocalModel:
    id: str
    name: str
    description: str
    tier: Tier
    min_ram_gb: float
    min_disk_gb: float
    download_size_gb: float


LOCAL_MODELS: tuple[LocalModel, ...] = (
    LocalModel(
        id="gemma2:2b",
        name="Gemma 2 2B",
        description="Smallest option — fast on low-RAM laptops, lower answer quality.",
        tier="light",
        min_ram_gb=6.0,
        min_disk_gb=6.0,
        download_size_gb=1.6,
    ),
    LocalModel(
        id="llama3.2:3b",
        name="Llama 3.2 3B",
        description="Lightweight and reliable for simple document questions.",
        tier="light",
        min_ram_gb=8.0,
        min_disk_gb=8.0,
        download_size_gb=2.0,
    ),
    LocalModel(
        id="phi3:mini",
        name="Phi-3 Mini",
        description="Compact model with strong reasoning for its size.",
        tier="light",
        min_ram_gb=8.0,
        min_disk_gb=8.0,
        download_size_gb=2.3,
    ),
    LocalModel(
        id="qwen2.5:3b",
        name="Qwen 2.5 3B",
        description="Good multilingual support on modest hardware.",
        tier="light",
        min_ram_gb=8.0,
        min_disk_gb=8.0,
        download_size_gb=2.0,
    ),
    LocalModel(
        id="qwen2.5:7b",
        name="Qwen 2.5 7B",
        description="Best balance of quality and speed for document Q&A.",
        tier="balanced",
        min_ram_gb=12.0,
        min_disk_gb=12.0,
        download_size_gb=4.7,
    ),
    LocalModel(
        id="mistral:7b",
        name="Mistral 7B",
        description="Strong general reasoning for English-heavy document sets.",
        tier="balanced",
        min_ram_gb=12.0,
        min_disk_gb=12.0,
        download_size_gb=4.1,
    ),
    LocalModel(
        id="llama3.1:8b",
        name="Llama 3.1 8B",
        description="Higher-quality answers on capable workstations.",
        tier="quality",
        min_ram_gb=16.0,
        min_disk_gb=14.0,
        download_size_gb=4.7,
    ),
    LocalModel(
        id="qwen2.5:14b",
        name="Qwen 2.5 14B",
        description="Top local quality for large document libraries.",
        tier="quality",
        min_ram_gb=24.0,
        min_disk_gb=18.0,
        download_size_gb=9.0,
    ),
)

MODELS_BY_ID = {model.id: model for model in LOCAL_MODELS}

DEFAULT_LIGHT_MODEL_ID = "llama3.2:3b"
DEFAULT_BALANCED_MODEL_ID = "qwen2.5:7b"
DEFAULT_QUALITY_MODEL_ID = "qwen2.5:7b"


def models_for_tier(tier: Tier | None) -> list[LocalModel]:
    if tier is None:
        return []
    order = {"light": 1, "balanced": 2, "quality": 3}
    max_rank = order.get(tier)
    if max_rank is None:
        return []
    return [model for model in LOCAL_MODELS if order[model.tier] <= max_rank]


def model_to_dict(model: LocalModel) -> dict:
    return {
        "id": model.id,
        "name": model.name,
        "description": model.description,
        "tier": model.tier,
        "min_ram_gb": model.min_ram_gb,
        "min_disk_gb": model.min_disk_gb,
        "download_size_gb": model.download_size_gb,
    }
