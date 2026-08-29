# node-exporter

This directory is the canonical configuration package for the `node-exporter` local
development service. Reports host-level CPU/memory/disk/network metrics, scraped by
`prometheus`.

**Deliberate security note**: node-exporter requires `pid: host` and read-only mounts
of `/proc`, `/sys`, and `/` — this is the standard, documented deployment shape (not a
workaround), and only runs when the `observability` profile is explicitly started.

On Windows, this reports the WSL2 VM's resources, not true native-Windows host stats
(battery, native Windows process list, etc. are not visible from inside WSL).

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation (none needed).
- `compose.yaml` — service topology.

No runtime secrets are required.
