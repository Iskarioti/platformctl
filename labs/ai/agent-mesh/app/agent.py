import os
from typing import TypedDict

from fastapi import FastAPI
from langchain_ollama import ChatOllama
from langgraph.graph import END, START, StateGraph

OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://ollama:11434")
CHAT_MODEL = os.environ.get("CHAT_MODEL", "gemma3:1b")
NODE_ID = os.environ.get("NODE_ID", "unknown")


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
app = FastAPI(title="agent-mesh-node")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "node": NODE_ID}


@app.post("/invoke")
def invoke(question: str) -> dict[str, str]:
    result = graph.invoke({"question": question, "answer": ""})
    return {"answer": result["answer"], "node": NODE_ID}
