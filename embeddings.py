"""Local text embeddings via FastEmbed (ONNX — no PyTorch)."""

from __future__ import annotations

from pathlib import Path

from fastembed import TextEmbedding

_MODEL_ALIASES = {
    "all-MiniLM-L6-v2": "sentence-transformers/all-MiniLM-L6-v2",
}


def resolve_embedding_model(name: str) -> str:
    return _MODEL_ALIASES.get(name, name)


def load_embedding_model(model_name: str, cache_dir: Path) -> TextEmbedding:
    return TextEmbedding(
        model_name=resolve_embedding_model(model_name),
        cache_dir=str(cache_dir),
    )


def embed_text(model: TextEmbedding, text: str) -> list[float]:
    return next(model.embed([text])).tolist()
