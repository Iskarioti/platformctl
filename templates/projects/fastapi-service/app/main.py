from fastapi import FastAPI

app = FastAPI(title="__PROJECT_NAME__")

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
