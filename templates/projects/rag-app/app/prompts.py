"""Versioned prompt templates.

Keep prompt changes here, reviewable in a diff and tied to eval results
(see labs/ai/rag-pipeline's "quality" test - docs/ai-workstation.md), instead
of scattered as inline f-strings in app/main.py. Bump QA_PROMPT_VERSION
whenever render_qa_prompt's wording changes meaningfully, so a quality-eval
regression can be traced back to a specific prompt revision.
"""

QA_PROMPT_VERSION = "v1"


def render_qa_prompt(context: str, question: str) -> str:
    return (
        "Answer the question using only the context below.\n\n"
        f"Context:\n{context}\n\nQuestion: {question}"
    )
