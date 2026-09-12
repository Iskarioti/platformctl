# 0002: Docker runs inside WSL, never Docker Desktop

**Status:** accepted

## Context

On Windows, Docker is available two ways: Docker Desktop (a native Windows
application with its own VM and GUI), or the Docker Engine installed
natively inside a WSL distribution and used directly from there. Docker
Desktop is the more common default for Windows developers.

## Decision

This workstation runs Docker Engine natively inside WSL only. Docker
Desktop is never installed or used - this is a hard rule
(`AGENTS.md` rule #7: "Docker on Windows lives inside WSL, never Docker
Desktop").

## Consequences

- One consistent Docker Engine across the whole WSL/Linux/macOS engineering
  plane, with no Docker-Desktop-specific licensing, resource-limit UI, or
  Windows-integration quirks to account for.
- All dev-services, labs, and project Dev Containers assume this - none of
  them have been tested against Docker Desktop and shouldn't be.
- The single-machine capacity concern (see ADR 0005) is entirely about this
  one WSL instance's own resource budget, not split across a separate
  Docker Desktop VM.
