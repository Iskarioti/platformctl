# __PROJECT_NAME__

Governed MCP (Model Context Protocol) server created by platformctl.

## Develop

Run the server directly for a quick sanity check:
```bash
python app/server.py
```

## Test interactively (MCP Inspector)

The devcontainer includes Node (`ghcr.io/devcontainers/features/node:1`) so the
official [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector) can
run alongside the Python server with no extra setup:
```bash
npx @modelcontextprotocol/inspector python app/server.py
```
The Inspector prints its own local URL - VS Code auto-forwards the port once it
detects the process listening, no `forwardPorts` entry needed.

## Test automatically

```bash
pytest
```
`tests/test_server.py` tests the underlying tool functions directly. For full
protocol-level testing, use the MCP SDK's client session against this server.

## Deploy

Package as a container image using this same `.devcontainer/Dockerfile` as the base
(swap `postCreateCommand`'s dev install for a production `pip install .`), and run
`python app/server.py` (or whichever transport - stdio/SSE/streamable-HTTP - your
MCP host expects) as the container's entrypoint.
