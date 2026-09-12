"""Run this app's own golden Q&A set through Langfuse as a real dataset
experiment - not just traces nobody reads back. The AI Engineer role
review's own finding: "Langfuse captures traces but nothing runs its
dataset/scoring features against them." `run_experiment` creates one traced
run per item, scores each with an LLM judge, and aggregates the result.

Same golden set and judge approach as labs/ai/rag-pipeline's "quality" test
(see docs/ai-workstation.md) - this is the same idea applied to this app's
own traced production code path, not a separate lab harness.

Requires: workstation services up qdrant langfuse, workstation models up
(with nomic-embed-text, gemma3:4b pulled), and LANGFUSE_PUBLIC_KEY/
LANGFUSE_SECRET_KEY set in .env (see README's "Prerequisites").

    python scripts/eval_dataset.py
"""

import os
import re
import sys

from dotenv import load_dotenv
from langchain_ollama import ChatOllama
from langfuse import get_client
from langfuse.api.core.api_error import ApiError

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import CHAT_MODEL, OLLAMA_BASE_URL, get_store
from app.prompts import render_qa_prompt

load_dotenv()

DATASET_NAME = "rag-golden-qa"
JUDGE_MODEL = "gemma3:4b"
THRESHOLD = 0.6

CORPUS = [
    "platformctl is a workstation-as-code repository, not an application.",
    "The platform-dev Docker network is how governed projects reach shared dev-services by container name.",
]

GOLDEN = [
    {"question": "What is platformctl?", "expected_output": "A workstation-as-code repository, not an application."},
    {"question": "How do governed projects reach shared dev-services?", "expected_output": "By container name, over the platform-dev Docker network."},
]


def ensure_dataset(lf) -> None:
    try:
        lf.create_dataset(name=DATASET_NAME)
    except ApiError:
        pass  # already exists - create_dataset_item below upserts either way

    for case in GOLDEN:
        lf.create_dataset_item(
            dataset_name=DATASET_NAME,
            input=case["question"],
            expected_output=case["expected_output"],
        )


def seed_corpus() -> None:
    store = get_store()
    store.add_texts(CORPUS)


def task(*, item, **_kwargs) -> str:
    question = item.input
    docs = get_store().similarity_search(question, k=3)
    context = "\n\n".join(d.page_content for d in docs)
    llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=CHAT_MODEL)
    return llm.invoke(render_qa_prompt(context, question)).content


def llm_judge_evaluator(*, input, output, expected_output, **_kwargs):
    # gemma3:1b (this app's own default CHAT_MODEL) was confirmed too weak a
    # judge in labs/ai/rag-pipeline's own quality test - scored an
    # obviously-correct paraphrase 0.1. Judging always uses gemma3:4b here,
    # independent of whatever CHAT_MODEL this app is configured with.
    llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=JUDGE_MODEL)
    prompt = (
        "You are grading a RAG system's answer against a reference answer.\n"
        f"Question: {input}\n"
        f"Reference answer: {expected_output}\n"
        f"Candidate answer: {output}\n"
        "Score how well the candidate answer captures the reference answer's "
        "meaning, from 0 (unrelated/wrong) to 1 (fully correct). Respond with "
        "ONLY a single number between 0 and 1, nothing else."
    )
    raw = llm.invoke(prompt).content
    match = re.search(r"\d*\.?\d+", raw)
    score = max(0.0, min(1.0, float(match.group()))) if match else 0.0
    return {"name": "llm-judge", "value": score, "comment": raw.strip()}


def main() -> None:
    lf = get_client()
    seed_corpus()
    ensure_dataset(lf)
    dataset = lf.get_dataset(DATASET_NAME)

    result = lf.run_experiment(
        name="golden-qa-eval",
        data=dataset.items,
        task=task,
        evaluators=[llm_judge_evaluator],
    )
    lf.flush()

    scores = [
        item.evaluations[0].value
        for item in result.item_results
        if item.evaluations
    ]
    mean_score = sum(scores) / len(scores) if scores else 0.0
    print(f"mean_score={mean_score:.3f} threshold={THRESHOLD} (n={len(scores)})")
    if result.dataset_run_url:
        print(f"View this run in Langfuse: {result.dataset_run_url}")
    assert mean_score >= THRESHOLD, f"quality below threshold: {mean_score:.3f} < {THRESHOLD}"
    print("PASS langfuse dataset eval")


if __name__ == "__main__":
    main()
