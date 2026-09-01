import os
from typing import TypedDict

from dotenv import load_dotenv
from fastapi import FastAPI
from langchain_ollama import ChatOllama
from langgraph.graph import END, START, StateGraph

load_dotenv()

OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://ollama:11434")
CHAT_MODEL = os.environ.get("CHAT_MODEL", "gemma3:4b")

# Optional: trace every node's LLM call to Langfuse (workstation services up
# langfuse) if configured - see .env.example. Falls back to no tracing if
# LANGFUSE_PUBLIC_KEY isn't set, so this template works standalone too.
_callbacks = []
if os.environ.get("LANGFUSE_PUBLIC_KEY"):
    from langfuse.langchain import CallbackHandler

    _callbacks = [CallbackHandler()]


class AgentState(TypedDict):
    question: str
    answer: str


def respond(state: AgentState) -> AgentState:
    llm = ChatOllama(base_url=OLLAMA_BASE_URL, model=CHAT_MODEL)
    result = llm.invoke(state["question"])
    return {"question": state["question"], "answer": result.content}


def build_graph():
    builder = StateGraph(AgentState)
    builder.add_node("respond", respond)
    builder.add_edge(START, "respond")
    builder.add_edge("respond", END)
    return builder.compile()


graph = build_graph()
app = FastAPI(title="__PROJECT_NAME__")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/invoke")
def invoke(question: str) -> dict[str, str]:
    result = graph.invoke({"question": question, "answer": ""}, config={"callbacks": _callbacks})
    return {"answer": result["answer"]}
