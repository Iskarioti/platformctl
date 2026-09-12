"""Run this app's own golden question set through Langfuse as a real dataset
experiment - not just traces nobody reads back. The AI Engineer role
review's own finding applies here too, not just to rag-app: "Langfuse
captures traces but nothing runs its dataset/scoring features against
them."

Same judge approach as rag-app/scripts/eval_dataset.py and
labs/ai/rag-pipeline's "quality" test (see docs/ai-workstation.md) - this is
the same idea applied to this app's own traced production code path
(`graph.invoke`), not a separate lab harness.

Requires: workstation services up langfuse, workstation models up (with
gemma3:4b pulled), and LANGFUSE_PUBLIC_KEY/LANGFUSE_SECRET_KEY set in .env
(see README's "Prerequisites").

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

from app.main import OLLAMA_BASE_URL, graph

load_dotenv()

DATASET_NAME = "agent-golden-qa"
JUDGE_MODEL = "gemma3:4b"
THRESHOLD = 0.6

GOLDEN = [
    {"question": "What is the capital of France?", "expected_output": "Paris."},
    {"question": "What is 12 multiplied by 8?", "expected_output": "96."},
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


def task(*, item, **_kwargs) -> str:
    result = graph.invoke({"question": item.input, "answer": ""})
    return result["answer"]


def llm_judge_evaluator(*, input, output, expected_output, **_kwargs):
    # gemma3:1b (this app's own default CHAT_MODEL) was confirmed too weak a
    # judge in labs/ai/rag-pipeline's own quality test - scored an
    # obviously-correct paraphrase 0.1. Judging always uses gemma3:4b here,
    # independent of whatever CHAT_MODEL this app is configured with.
    llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=JUDGE_MODEL)
    prompt = (
        "You are grading an assistant's answer against a reference answer.\n"
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
