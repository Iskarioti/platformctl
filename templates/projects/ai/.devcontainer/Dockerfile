FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm
USER root
COPY requirements.lock /tmp/requirements.lock
RUN pip install --no-cache-dir -r /tmp/requirements.lock && rm /tmp/requirements.lock
USER vscode
