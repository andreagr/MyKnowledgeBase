"""Hardware compatibility checks and local model recommendations."""

from __future__ import annotations

from typing import Any, Literal

from local_llm import catalog, hardware

Tier = Literal["none", "light", "balanced", "quality"]
CompatibilityTier = Literal["light", "balanced", "quality"]


def _assign_tier(specs: dict[str, Any]) -> Tier:
    total_ram = float(specs["total_ram_gb"])
    available_ram = float(specs["available_ram_gb"])
    free_disk = float(specs["free_disk_gb"])
    vram = specs.get("vram_gb")

    if total_ram < hardware.MIN_PLATFORM_RAM_GB or free_disk < hardware.MIN_PLATFORM_DISK_GB:
        return "none"

    effective_ram = total_ram
    if vram is not None and float(vram) >= 8.0:
        effective_ram = max(total_ram, float(vram) + hardware.RAG_STACK_RESERVE_GB)

    if effective_ram >= 32.0 or (vram is not None and float(vram) >= 12.0):
        tier: Tier = "quality"
    elif effective_ram >= 16.0 or (vram is not None and float(vram) >= 8.0):
        tier = "balanced"
    elif total_ram >= 8.0 and available_ram >= 4.0:
        tier = "light"
    else:
        return "none"

    return tier


def _build_blockers(specs: dict[str, Any], tier: Tier) -> list[str]:
    blockers: list[str] = []
    total_ram = float(specs["total_ram_gb"])
    free_disk = float(specs["free_disk_gb"])
    platform_name = str(specs["platform"])
    architecture = str(specs["architecture"]).lower()

    if platform_name != "Windows":
        blockers.append(
            f"Local models are currently supported on Windows only (this device reports {platform_name})."
        )
    elif "arm" in architecture and "64" in architecture:
        blockers.append("Windows on ARM is not supported yet for managed local models.")

    if total_ram < hardware.MIN_PLATFORM_RAM_GB:
        blockers.append(
            f"At least {hardware.MIN_PLATFORM_RAM_GB:.0f} GB of system memory is required "
            f"(this PC has {total_ram:.1f} GB)."
        )
    if free_disk < hardware.MIN_PLATFORM_DISK_GB:
        blockers.append(
            f"At least {hardware.MIN_PLATFORM_DISK_GB:.0f} GB of free disk space is required "
            f"(currently {free_disk:.1f} GB free)."
        )
    if tier == "none" and not blockers:
        blockers.append(
            "Not enough available memory right now. Close other apps and try again."
        )
    return blockers


def _build_warnings(specs: dict[str, Any], tier: Tier) -> list[str]:
    warnings: list[str] = []
    available_ram = float(specs["available_ram_gb"])
    vram = specs.get("vram_gb")

    if tier in {"balanced", "quality"} and not specs.get("has_gpu"):
        warnings.append(
            "No dedicated GPU detected — local answers may take 30–60 seconds on CPU."
        )
    if available_ram < 6.0 and tier != "none":
        warnings.append(
            "Available memory is low. Close other apps before downloading a local model."
        )
    if vram is not None and float(vram) < 8.0 and tier == "balanced":
        warnings.append(
            f"GPU memory is limited ({float(vram):.1f} GB). The app may run the model on CPU."
        )
    return warnings


def _pick_recommended_model(tier: Tier) -> catalog.LocalModel | None:
    if tier == "none":
        return None
    if tier == "light":
        return catalog.MODELS_BY_ID[catalog.DEFAULT_LIGHT_MODEL_ID]
    if tier == "balanced":
        return catalog.MODELS_BY_ID[catalog.DEFAULT_BALANCED_MODEL_ID]
    return catalog.MODELS_BY_ID.get(
        "qwen2.5:14b",
        catalog.MODELS_BY_ID[catalog.DEFAULT_QUALITY_MODEL_ID],
    )


def _model_fits(model: catalog.LocalModel, specs: dict[str, Any]) -> bool:
    total_ram = float(specs["total_ram_gb"])
    available_ram = float(specs["available_ram_gb"])
    free_disk = float(specs["free_disk_gb"])
    vram = specs.get("vram_gb")

    effective_ram = total_ram
    if vram is not None:
        effective_ram = max(total_ram, float(vram) + hardware.RAG_STACK_RESERVE_GB)

    return (
        effective_ram >= model.min_ram_gb
        and available_ram >= max(4.0, model.min_ram_gb - hardware.RAG_STACK_RESERVE_GB)
        and free_disk >= model.min_disk_gb
    )


def _fallback_reason(model: catalog.LocalModel) -> str:
    return (
        f"Based on available memory right now, {model.name} is the best model "
        f"this PC can run comfortably (~{model.download_size_gb:.1f} GB download)."
    )


def _recommendation_reason(model: catalog.LocalModel, specs: dict[str, Any], tier: Tier) -> str:
    total_ram = float(specs["total_ram_gb"])
    if tier == "light":
        return (
            f"Your PC has {total_ram:.0f} GB of memory — {model.name} is the best fit for "
            "fast, on-device document answers."
        )
    if specs.get("has_gpu"):
        vram = float(specs["vram_gb"])
        return (
            f"Your PC has {total_ram:.0f} GB RAM and {vram:.0f} GB GPU memory — "
            f"{model.name} offers the best quality for document Q&A on this hardware."
        )
    return (
        f"Your PC has {total_ram:.0f} GB of memory — {model.name} balances answer quality "
        "and response time for document questions."
    )


def check_compatibility() -> dict[str, Any]:
    specs = hardware.collect_specs()
    tier = _assign_tier(specs)
    blockers = _build_blockers(specs, tier)
    compatible = tier != "none" and not blockers
    warnings = _build_warnings(specs, tier) if compatible else []

    tier_default = _pick_recommended_model(tier) if compatible else None
    recommended = tier_default
    used_fallback = False
    if recommended is not None and not _model_fits(recommended, specs):
        for candidate in reversed(catalog.models_for_tier(tier if tier != "none" else "light")):
            if _model_fits(candidate, specs):
                recommended = candidate
                used_fallback = candidate.id != tier_default.id
                break
        else:
            recommended = None
            compatible = False
            blockers.append(
                "Not enough free memory or disk space right now for a local model. "
                "Close other apps or free disk space, then scan again."
            )

    offered_tier: CompatibilityTier | None = None if tier == "none" else tier
    offered_models = (
        [catalog.model_to_dict(model) for model in catalog.models_for_tier(offered_tier)]
        if offered_tier
        else []
    )
    fitting_models = (
        [
            catalog.model_to_dict(model)
            for model in catalog.models_for_tier(offered_tier)
            if _model_fits(model, specs)
        ]
        if offered_tier
        else []
    )

    return {
        "compatible": compatible,
        "tier": tier,
        "recommended_model": catalog.model_to_dict(recommended) if recommended else None,
        "recommendation_reason": (
            _fallback_reason(recommended)
            if recommended and used_fallback
            else _recommendation_reason(recommended, specs, tier)
            if recommended and tier != "none"
            else ""
        ),
        "blockers": blockers,
        "warnings": warnings,
        "specs": specs,
        "offered_models": offered_models,
        "fitting_models": fitting_models,
        "managed_by_app": True,
    }
