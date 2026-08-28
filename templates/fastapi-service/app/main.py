from __future__ import annotations

import time
import uuid

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

app = FastAPI(title="Platform Service", version="0.1.0")


@app.middleware("http")
async def request_context(request: Request, call_next):
    correlation_id = request.headers.get("x-correlation-id") or str(uuid.uuid4())
    started = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception:
        response = JSONResponse(status_code=500, content={"detail": "internal server error"})
    response.headers["x-correlation-id"] = correlation_id
    response.headers["x-response-time-ms"] = str(round((time.perf_counter() - started) * 1000, 2))
    return response


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/readiness")
async def readiness():
    # Extend with database/Redis dependency checks before production.
    return {"status": "ready"}
