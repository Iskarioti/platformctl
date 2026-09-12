import os
from typing import TypedDict

from dotenv import load_dotenv
from fastapi import FastAPI
from langchain_ollama import ChatOllama
from langgraph.graph import END, START, StateGraph

from app import guardrails
from app.prompts import SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION

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
    result = llm.invoke([("system", SYSTEM_PROMPT), ("human", state["question"])])
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
    injection_flags = guardrails.flag_prompt_injection(question)
    result = graph.invoke({"question": question, "answer": ""}, config={"callbacks": _callbacks})
    response: dict[str, str] = {
        "answer": guardrails.redact_pii(result["answer"]),
        "promptVersion": SYSTEM_PROMPT_VERSION,
    }
    if injection_flags:
        # Not blocked - flagged, same pattern as rag-app. A real deployment
        # decides what to do with this signal once the graph reads content
        # it didn't generate itself (a tool result, a fetched page) - see
        # README's "Threat model" section.
        response["inputFlags"] = ",".join(injection_flags)
    return response
