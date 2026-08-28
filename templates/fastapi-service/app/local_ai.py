from __future__ import annotations

import os

import httpx


async def generate_local(prompt: str, model: str = "gemma3:4b") -> str:
    base_url = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{base_url}/api/generate",
            json={"model": model, "prompt": prompt, "stream": False},
        )
        response.raise_for_status()
        return response.json()["response"]
