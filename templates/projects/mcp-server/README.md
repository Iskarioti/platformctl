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

## Threat model (OWASP LLM Top 10, applied to MCP)

An MCP tool is code the *LLM host* decides to call from natural-language
input it read somewhere - the trust boundary is the tool's own argument
validation, not anything upstream. Check each real tool you add (not
`echo`, which takes no privileged action) against these before shipping:

- **Insecure plugin/tool design (LLM07)** - the most MCP-specific risk. If a
  tool shells out, reads/writes files, or calls another service using an
  argument the model supplied, treat that argument as attacker-controlled -
  the model can be steered into supplying it by content it read elsewhere
  (a webpage, a file, another tool's output), not just the end user's own
  words. Validate/allowlist inputs at the tool boundary itself, the same as
  any other untrusted-input boundary - never trust "the LLM will only ask
  for reasonable things."
- **Excessive agency (LLM06)** - give each tool the narrowest permission it
  actually needs (a read-only tool should use a read-only credential/API
  scope, not one that happens to also allow writes). A confused or
  adversarially-steered model can only do what the tool it's calling is
  itself capable of.
- **Sensitive information disclosure (LLM02)** - a tool that returns file
  contents, API responses, or query results returns them to whatever LLM
  host is calling this server, over whatever transport - don't return
  secrets/credentials/internal-only data through a tool's return value.
- **Supply chain (LLM05)** - this template's own dependencies
  (`requirements.txt`) get Dependabot updates (`.github/dependabot.yml`);
  the same applies to any MCP client/host you integrate with.

## Deploy

Package as a container image using this same `.devcontainer/Dockerfile` as the base
(swap `postCreateCommand`'s dev install for a production `pip install .`), and run
`python app/server.py` (or whichever transport - stdio/SSE/streamable-HTTP - your
MCP host expects) as the container's entrypoint.
