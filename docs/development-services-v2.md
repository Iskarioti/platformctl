# Modular Development Services

Each service owns its own configuration package under `development/services/<service>/`:

- `service.json`
- `versions.env`
- `defaults.env`
- `.env.example`
- `compose.yaml`
- `config/` where needed
- `README.md`

Runtime secrets are not tracked. They are generated per service under:

`~/.config/workstation/services/<service>.env`

The root catalog is `development/catalog.json`.

Typical commands:

```bash
workstation services list
workstation services config redis
workstation services up core
workstation services up redisinsight
workstation services up ui
workstation services urls
workstation services doctor
```

All host-published ports bind to `127.0.0.1`. WSL and the local Windows host can use
the localhost endpoints; Dev Containers attached to `platform-dev` use Docker DNS names.
