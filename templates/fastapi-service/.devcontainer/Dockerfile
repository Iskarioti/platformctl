FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl wget gnupg jq postgresql-client redis-tools netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv \
    && install -m 0755 /root/.local/bin/uvx /usr/local/bin/uvx

# Task official apt repository
RUN curl -1sLf 'https://dl.cloudsmith.io/public/task/task/setup.deb.sh' | bash \
    && apt-get update \
    && apt-get install -y task \
    && rm -rf /var/lib/apt/lists/*

# Trivy official apt repository
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget gnupg \
    && wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
       | gpg --dearmor \
       | tee /usr/share/keyrings/trivy.gpg >/dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
       > /etc/apt/sources.list.d/trivy.list \
    && apt-get update \
    && apt-get install -y trivy \
    && rm -rf /var/lib/apt/lists/*

USER vscode

ENV PATH="/home/vscode/.local/bin:/home/vscode/.codex/bin:${PATH}"
