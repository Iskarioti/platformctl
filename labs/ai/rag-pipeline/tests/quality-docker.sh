#!/usr/bin/env bash
set -euo pipefail
NET=platform-lab-rag-pipeline

# A real RAG quality eval: a small golden question/answer set, retrieved
# against real embeddings, answered by a real generation call, graded by a
# second LLM call acting as judge (not a substring/exact-match check - real
# RAG answers paraphrase) - gated on a numeric threshold so a real quality
# regression fails the test, not just an outage.

read -r -d '' PYCODE <<'PY' || true
import json
import re
import urllib.error
import urllib.request


def request(url, payload=None, method=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}, method=method
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())


def embed(text):
    r = request("http://ollama:11434/api/embeddings", {"model": "nomic-embed-text", "prompt": text})
    return r["embedding"]


def generate(prompt, model="gemma3:1b"):
    r = request(
        "http://ollama:11434/api/generate",
        {"model": model, "prompt": prompt, "stream": False, "options": {"temperature": 0}},
    )
    return r["response"].strip()


CORPUS = [
    "platformctl labs validate architecture before it reaches production.",
    "The platform-dev Docker network is how governed projects reach shared dev-services by container name.",
    "workstation dr-drill rehearses backup and restore into a throwaway directory so it never touches the real machine.",
    "MLflow in this repo shares the postgres and garage dev-services instead of running its own private database.",
]

GOLDEN = [
    {"question": "What do platformctl labs validate?", "expected": "Architecture, before it reaches production."},
    {"question": "How do governed projects reach shared dev-services?", "expected": "By container name, over the platform-dev Docker network."},
    {"question": "Where does workstation dr-drill restore to?", "expected": "A throwaway directory, never the real machine."},
    {"question": "What does MLflow share instead of running its own database?", "expected": "The postgres and garage dev-services."},
]

COLLECTION = "http://qdrant:6333/collections/rag-quality"
try:
    request(COLLECTION, {"vectors": {"size": 768, "distance": "Cosine"}}, method="PUT")
except urllib.error.HTTPError as e:
    # the lab's qdrant volume survives "lab up"/"lab down" cycles - tolerate
    # a collection left over from a prior run of this test.
    if e.code != 409:
        raise

points = [{"id": i, "vector": embed(text), "payload": {"text": text}} for i, text in enumerate(CORPUS, start=1)]
request(f"{COLLECTION}/points?wait=true", {"points": points}, method="PUT")


def judge(question, expected, actual):
    # gemma3:1b is used for the generation step above (fast, and good enough
    # to answer from context) but confirmed live to be a bad judge - it
    # scored an obviously-correct paraphrase as 0.1. gemma3:4b judges the
    # same case correctly (1.0); use the larger model for judging only.
    prompt = (
        "You are grading a RAG system's answer against a reference answer.\n"
        f"Question: {question}\n"
        f"Reference answer: {expected}\n"
        f"Candidate answer: {actual}\n"
        "Score how well the candidate answer captures the reference answer's "
        "meaning, from 0 (unrelated/wrong) to 1 (fully correct). Respond with "
        "ONLY a single number between 0 and 1, nothing else."
    )
    raw = generate(prompt, model="gemma3:4b")
    m = re.search(r"\d*\.?\d+", raw)
    if not m:
        return 0.0
    return max(0.0, min(1.0, float(m.group())))


scores = []
for case in GOLDEN:
    qvec = embed(case["question"])
    result = request(f"{COLLECTION}/points/search", {"vector": qvec, "limit": 2, "with_payload": True}, method="POST")
    context = "\n".join(p["payload"]["text"] for p in result["result"])
    answer = generate(
        "Answer the question using ONLY the context below. Be concise, one sentence.\n\n"
        f"Context:\n{context}\n\nQuestion: {case['question']}\nAnswer:"
    )
    score = judge(case["question"], case["expected"], answer)
    scores.append(score)
    print(f"Q: {case['question']!r}\n  A: {answer!r}\n  score={score:.2f}")

mean_score = sum(scores) / len(scores)
THRESHOLD = 0.6
print(f"\nmean_score={mean_score:.3f} threshold={THRESHOLD} (n={len(scores)})")
assert mean_score >= THRESHOLD, f"RAG quality below threshold: {mean_score:.3f} < {THRESHOLD}"
print("PASS rag quality eval")
PY

docker run --rm --network "$NET" python:3.13.15-slim-bookworm python3 -c "$PYCODE"
echo "PASS rag-pipeline docker quality"
