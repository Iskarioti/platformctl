# GPU variant of the base ../Dockerfile - same image and packages, plus a
# CUDA-enabled PyTorch build. PyTorch's own wheels bundle the CUDA runtime
# libraries they need, so no nvidia/cuda base image is required - only an
# NVIDIA driver + the NVIDIA Container Toolkit on the HOST, and --gpus=all
# (or the devcontainer.json hostRequirements below) at container start.
FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm
USER root
RUN pip install --no-cache-dir \
    fastapi uvicorn httpx pydantic-settings \
    numpy pandas scikit-learn \
    opentelemetry-api opentelemetry-sdk
# cu126: confirmed available for the current PyTorch release at
# https://download.pytorch.org/whl/cu126/torch/ - re-check that index if
# bumping the CUDA tag later, wheel availability lags new CUDA releases.
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cu126
USER vscode
