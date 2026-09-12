import os
import re

from dotenv import load_dotenv
from fastapi import FastAPI
from langchain_ollama import ChatOllama, OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient
from qdrant_client.http.models import Distance, VectorParams

from app import guardrails
from app.prompts import QA_PROMPT_VERSION, render_qa_prompt

load_dotenv()

OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://ollama:11434")
QDRANT_URL = os.environ.get("QDRANT_URL", "http://dev-qdrant:6333")
QDRANT_API_KEY = os.environ.get("QDRANT_API_KEY")
EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")
CHAT_MODEL = os.environ.get("CHAT_MODEL", "gemma3:4b")

# Suffixed with the embedding model: switching EMBED_MODEL otherwise
# silently orphans the existing collection (different model, different
# vector space, same name) with nothing to catch it - a real gap the AI
# Engineer role review flagged. Qdrant collection names accept only
# [A-Za-z0-9_-], so a model name containing ":" (e.g. "gemma3:4b"-style
# tags) gets sanitized, not rejected.
COLLECTION = f"__PROJECT_NAME__-{re.sub(r'[^A-Za-z0-9_-]', '-', EMBED_MODEL)}"

app = FastAPI(title="__PROJECT_NAME__")

embeddings = OllamaEmbeddings(base_url=OLLAMA_BASE_URL, model=EMBED_MODEL)
client = QdrantClient(url=QDRANT_URL, api_key=QDRANT_API_KEY)

# Optional: trace every LLM call to Langfuse (workstation services up
# langfuse) if configured - see .env.example. Falls back to no tracing if
# LANGFUSE_PUBLIC_KEY isn't set, so this template works standalone too.
_callbacks = []
if os.environ.get("LANGFUSE_PUBLIC_KEY"):
    from langfuse.langchain import CallbackHandler

    _callbacks = [CallbackHandler()]


def ensure_collection() -> None:
    if not client.collection_exists(COLLECTION):
        client.create_collection(
            COLLECTION,
            vectors_config=VectorParams(size=768, distance=Distance.COSINE),
        )


def get_store() -> QdrantVectorStore:
    ensure_collection()
    return QdrantVectorStore(client=client, collection_name=COLLECTION, embedding=embeddings)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/ingest")
def ingest(text: str) -> dict[str, str]:
    # Redacted before it ever reaches the vector store (no-op unless
    # GUARDRAILS_ENABLED=true) - this endpoint accepts arbitrary text, and
    # anything stored here is retrievable by any future /query call. See
    # README's "Threat model" section.
    get_store().add_texts([guardrails.redact_pii(text)])
    return {"status": "ingested"}


@app.post("/query")
def query(question: str) -> dict[str, str]:
    docs = get_store().similarity_search(question, k=3)
    context = "\n\n".join(d.page_content for d in docs)
    injection_flags = guardrails.flag_prompt_injection(context)

    llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=CHAT_MODEL)
    response = llm.invoke(
        render_qa_prompt(context, question),
        config={"callbacks": _callbacks},
    )
    result: dict[str, str] = {
        "answer": guardrails.redact_pii(response.content),
        "promptVersion": QA_PROMPT_VERSION,
    }
    if injection_flags:
        # Not blocked - flagged. Retrieved content carrying instruction-like
        # phrases is exactly this template's own indirect-injection risk
        # (README "Threat model"); a real deployment decides what to do
        # with this signal, this template surfaces it rather than hiding it.
        result["retrievedContentFlags"] = ",".join(injection_flags)
    return result
