import os

from dotenv import load_dotenv
from fastapi import FastAPI
from langchain_ollama import ChatOllama, OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient
from qdrant_client.http.models import Distance, VectorParams

load_dotenv()

OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://ollama:11434")
QDRANT_URL = os.environ.get("QDRANT_URL", "http://dev-qdrant:6333")
QDRANT_API_KEY = os.environ.get("QDRANT_API_KEY")
EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")
CHAT_MODEL = os.environ.get("CHAT_MODEL", "gemma3:4b")
COLLECTION = "__PROJECT_NAME__"

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
    get_store().add_texts([text])
    return {"status": "ingested"}


@app.post("/query")
def query(question: str) -> dict[str, str]:
    docs = get_store().similarity_search(question, k=3)
    context = "\n\n".join(d.page_content for d in docs)
    llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=CHAT_MODEL)
    response = llm.invoke(
        f"Answer the question using only the context below.\n\n"
        f"Context:\n{context}\n\nQuestion: {question}",
        config={"callbacks": _callbacks},
    )
    return {"answer": response.content}
