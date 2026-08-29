# Editor Management

`platformctl` treats terminal editors as part of the WSL/Linux engineering plane.

## Profiles

- `platform` — default LazyVim-based Systems & Platform Architect profile.
- `nvchad` — isolated NvChad v2.5 alternate profile.
- `minimal` — plugin-free Neovim repair/troubleshooting profile.
- `vim` — plugin-free rescue editor for remote/minimal environments.

Neovim profiles use `NVIM_APPNAME`, so plugin/data/state directories are isolated.

## Commands

```bash
workstation editor install
workstation editor apply
workstation editor doctor
workstation editor list
workstation editor profile platform
workstation editor profile nvchad
workstation editor profile minimal
workstation editor sync platform
```

Direct launchers:

```bash
nvim
nvim-platform
nvim-chad
nvim-minimal
nvim-real --clean
vim
```

## Platform profile

The primary profile uses LazyVim and Tokyo Night, with language/infrastructure extras for:

- Ansible
- Docker / Compose
- JSON / YAML / TOML
- Markdown
- Python
- SQL
- Terraform / HCL
- TypeScript / JavaScript
- Go
- Rust

The editor config never stores database passwords, cloud credentials, SSH private keys,
tokens or `.env` secrets.

Project-local Neovim config and Vim modelines are disabled by default.

## Toolchain boundary

Editor/LSP tooling may run in WSL. Application runtimes, dependencies, compilers and
project-specific versions should remain in Dev Containers whenever practical.

## First run

After bootstrap:

```bash
workstation editor doctor
nvim
```

The first `nvim` launch downloads LazyVim plugins. To pre-warm the profile:

```bash
workstation editor sync platform
```

NvChad can be pre-warmed separately:

```bash
workstation editor sync nvchad
```
