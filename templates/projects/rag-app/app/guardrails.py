"""Optional guardrails - conditional, no-op unless GUARDRAILS_ENABLED is set
(the same "opt in, no-op if unset" pattern this template's Langfuse tracing
integration already uses; see .env.example). Not a complete LLM security
defense - a real, working starting point for the two risks a RAG app's own
/ingest endpoint concretely creates (see README's "Threat model" section):
PII landing in a vector store nobody meant to persist it in, and indirect
prompt injection via retrieved content.
"""

import os
import re


def _enabled() -> bool:
    # Read at call time, not import time, so tests can toggle it via
    # monkeypatch without reloading the module.
    return os.environ.get("GUARDRAILS_ENABLED", "").lower() in ("1", "true", "yes")


_EMAIL_RE = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")
_PHONE_RE = re.compile(r"\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b")

# Not exhaustive - a real deployment needs a maintained list or a dedicated
# classifier, not a fixed phrase list. This catches the obvious/lazy cases,
# nothing more.
_INJECTION_PHRASES = (
    "ignore previous instructions",
    "ignore all previous instructions",
    "disregard the above",
    "disregard previous instructions",
    "you are now",
    "new instructions:",
    "system prompt:",
)


def redact_pii(text: str) -> str:
    """Replace obvious emails/phone numbers with a placeholder. No-op unless enabled."""
    if not _enabled():
        return text
    text = _EMAIL_RE.sub("[REDACTED-EMAIL]", text)
    text = _PHONE_RE.sub("[REDACTED-PHONE]", text)
    return text


def flag_prompt_injection(text: str) -> list[str]:
    """Return which known injection phrases appear in text. No-op (empty) unless enabled."""
    if not _enabled():
        return []
    lowered = text.lower()
    return [phrase for phrase in _INJECTION_PHRASES if phrase in lowered]
