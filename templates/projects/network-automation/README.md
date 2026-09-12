# __PROJECT_NAME__

Governed network automation project created by platformctl - Netmiko, Nornir,
NAPALM, and Scrapli for multi-vendor device automation, plus common network
diagnostic tools (ping, traceroute, mtr, dig, nmap, tcpdump, snmp) in the Dev
Container. The container runs with `NET_RAW` capability for raw-socket tools
(ping/traceroute) to work.

Device credentials go in your own `.env` (never committed - see `.env.example`),
never hardcoded in inventory files.

## Getting started

```bash
pip install -r requirements-dev.txt
ruff check .
pytest -q
```

Runtime dependencies (netmiko, nornir, napalm, scrapli, typer, rich) are
installed in the Dev Container image (`.devcontainer/Dockerfile`), not via
`requirements.txt`.

## Inventory

`nornir/config.yaml` and `nornir/inventory/{hosts,groups,defaults}.yaml` are a
minimal Nornir starting point - fill in real hosts/groups before running
`src/main.py` against actual devices.
