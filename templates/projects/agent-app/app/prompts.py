"""Versioned prompt templates.

Keep prompt changes here, reviewable in a diff and tied to eval results,
instead of the model receiving the raw user question with no system prompt
at all (this template's prior behavior). Bump SYSTEM_PROMPT_VERSION whenever
SYSTEM_PROMPT's wording changes meaningfully.
"""

SYSTEM_PROMPT_VERSION = "v1"

SYSTEM_PROMPT = (
    "You are a helpful, concise assistant. Answer directly; if you are "
    "unsure, say so instead of guessing."
)
