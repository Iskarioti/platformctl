FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm
USER root
RUN pip install --no-cache-dir \
    fastapi uvicorn httpx pydantic-settings \
    numpy pandas scikit-learn \
    opentelemetry-api opentelemetry-sdk
USER vscode
