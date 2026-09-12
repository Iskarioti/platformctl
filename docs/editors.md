# Editor Management

`platformctl` treats terminal editors as part of the WSL/Linux engineering plane.

## Profiles

- `platform` — default LazyVim-based Systems & Platform Architect profile.
- `nvchad` — isolated NvChad v2.5 alternate profile.
- `minimal` — plugin-free Neovim repair/troubleshooting profile.
- `personal` — LazyVim personal IDE migrated from `Iskarioti/.dotfiles`
  (`.config/nvim`) - Mason/LSP (Lua, Rust, Go, Tailwind, templ, nil, HTML/HTMX,
  TypeScript), Telescope, Treesitter, Copilot, lualine, oil.nvim, which-key.
  See "Personal profile" below for what changed during the port.
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
workstation editor profile personal
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

## Personal profile

Ported from `github.com/Iskarioti/.dotfiles`'s `.config/nvim` as-is (init.lua,
~25 `lua/plugins/*` files, `lazy-lock.json`), except for one real, live-verified
fix: `nvim-treesitter`'s default branch ("main") is a full rewrite with a
different API (no more `.configs` module) - this config uses the pre-rewrite
API, so the plugin spec now pins `branch = "master"` (upstream's own
maintained-but-archived legacy-compatible branch) instead of rewriting the
config to the new API. Without this pin, the profile installed fine but
crashed on every startup with `module 'nvim-treesitter.configs' not found`.
Also removed one dead line (`local parser_config =
require("nvim-treesitter.parsers").get_parser_configs()`) that was never used
and only existed to crash against the same API removal.

Verified live: a real headless `nvim` load with this profile starts clean, a
real Lua buffer opens with `filetype=lua` and treesitter/LSP wiring intact
(Lua/Rust/Go/Tailwind/templ/nil/HTML/HTMX/TypeScript language servers are
configured but not auto-installed - install them yourself, e.g.
`lua-language-server`/`rust-analyzer`/`gopls`, the same expectation the
`platform` profile already has for its own languages). One remaining
non-fatal deprecation warning: `nvim-lspconfig`'s classic `require('lspconfig')`
setup style is deprecated in favor of `vim.lsp.config` and will be removed in
`nvim-lspconfig` v3.0.0 - not fixed here since it still works today and
rewriting to the new API would mean redesigning the actual LSP setup, not
just porting it; revisit before v3.0.0 ships.

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

NvChad and the personal profile can be pre-warmed separately:

```bash
workstation editor sync nvchad
workstation editor sync personal
```
