FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Pinned per this repo's forbidLatestTag policy - bump deliberately, not
# tracked automatically (matches every other template's Dockerfile).
ARG QUARTO_VERSION=1.10.18

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    texlive-latex-base texlive-latex-recommended texlive-latex-extra \
    texlive-fonts-recommended texlive-bibtex-extra biber latexmk pandoc make \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/quarto.deb \
      "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
    && apt-get update && apt-get install -y /tmp/quarto.deb \
    && rm -f /tmp/quarto.deb && rm -rf /var/lib/apt/lists/*

USER vscode
