"""LLM provider registry and chat completion helpers."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Literal

ApiStyle = Literal["openai", "anthropic"]

SYSTEM_PROMPT = (
    "You answer questions using only the provided document context. "
    "If the answer is not in the context, say you could not find it "
    "in the indexed documents. "
    "When the user asks where a file is, how to find it, or wants to "
    "open it, mention the exact filename and folder path shown in the "
    "context. Tell them they can click the 'Open folder' link below "
    "your answer to open the file location."
)


@dataclass(frozen=True)
class LlmProvider:
    id: str
    name: str
    env_key: str
    models: tuple[str, ...]
    default_model: str
    api_style: ApiStyle
    base_url: str | None = None

    def to_dict(
        self,
        *,
        has_custom_key: bool = False,
        api_key_preview: str = "",
    ) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "models": list(self.models),
            "default_model": self.default_model,
            "has_custom_key": has_custom_key,
            "api_key_preview": api_key_preview,
        }


PROVIDERS: dict[str, LlmProvider] = {
    "deepseek": LlmProvider(
        id="deepseek",
        name="DeepSeek",
        env_key="DEEPSEEK_API_KEY",
        models=("deepseek-chat", "deepseek-reasoner"),
        default_model="deepseek-chat",
        api_style="openai",
        base_url="https://api.deepseek.com",
    ),
    "openai": LlmProvider(
        id="openai",
        name="OpenAI",
        env_key="OPENAI_API_KEY",
        models=("gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini"),
        default_model="gpt-4o-mini",
        api_style="openai",
    ),
    "anthropic": LlmProvider(
        id="anthropic",
        name="Anthropic",
        env_key="ANTHROPIC_API_KEY",
        models=(
            "claude-sonnet-4-20250514",
            "claude-3-5-haiku-latest",
            "claude-3-5-sonnet-latest",
        ),
        default_model="claude-sonnet-4-20250514",
        api_style="anthropic",
    ),
    "google": LlmProvider(
        id="google",
        name="Google Gemini",
        env_key="GOOGLE_API_KEY",
        models=("gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-2.5-pro-preview-05-06"),
        default_model="gemini-2.0-flash",
        api_style="openai",
        base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
    ),
}

DEFAULT_PROVIDER_ID = "deepseek"


def list_providers(custom_keys: dict[str, str] | None = None) -> list[dict[str, Any]]:
    keys = custom_keys or {}
    result: list[dict[str, Any]] = []
    for provider in PROVIDERS.values():
        custom_key = keys.get(provider.id, "")
        result.append(
            provider.to_dict(
                has_custom_key=bool(custom_key),
                api_key_preview=_mask_api_key(custom_key),
            )
        )
    return result


def _mask_api_key(api_key: str) -> str:
    if not api_key:
        return ""
    if len(api_key) <= 8:
        return "••••••••"
    return f"{api_key[:3]}...{api_key[-4:]}"


def get_provider(provider_id: str) -> LlmProvider:
    if provider_id not in PROVIDERS:
        raise ValueError(f"Unknown provider: {provider_id}")
    return PROVIDERS[provider_id]


def get_default_api_key(provider_id: str) -> str:
    provider = get_provider(provider_id)
    return os.getenv(provider.env_key, "")


def generate_answer(provider_id: str, model: str, api_key: str, question: str, context: str) -> str:
    provider = get_provider(provider_id)
    user_content = f"Question: {question}\n\nContext:\n{context}"

    if provider.api_style == "openai":
        from openai import OpenAI

        client_kwargs: dict[str, Any] = {"api_key": api_key}
        if provider.base_url:
            client_kwargs["base_url"] = provider.base_url
        client = OpenAI(**client_kwargs)
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
            stream=False,
        )
        return response.choices[0].message.content or ""

    from anthropic import Anthropic

    client = Anthropic(api_key=api_key)
    response = client.messages.create(
        model=model,
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_content}],
    )
    return response.content[0].text
