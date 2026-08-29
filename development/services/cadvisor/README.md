# cadvisor

This directory is the canonical configuration package for the `cadvisor` local
development service. Reports per-container CPU/memory/disk/network metrics, scraped
by `prometheus`.

**Deliberate security note**: cAdvisor requires `privileged: true` and read-only
mounts of the Docker socket, `/sys`, and `/var/lib/docker` to read host/container
cgroup data — this is the standard, documented cAdvisor deployment shape (not a
workaround), and only runs when the `observability` profile is explicitly started.

On Windows, Docker runs inside WSL2, so cAdvisor reports the WSL2 VM's resource usage,
not true native-Windows host stats.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation (none needed).
- `compose.yaml` — service topology.

No runtime secrets are required.
