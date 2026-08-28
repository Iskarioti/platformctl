$ErrorActionPreference = "Stop"

$extensions = @(
    "ms-vscode-remote.remote-wsl",
    "ms-vscode-remote.remote-containers",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "charliermarsh.ruff",
    "ms-azuretools.vscode-docker",
    "hashicorp.terraform",
    "redhat.ansible",
    "redhat.vscode-yaml",
    "eamodio.gitlens",
    "humao.rest-client",
    "editorconfig.editorconfig",
    "usernamehw.errorlens"
)

foreach ($extension in $extensions) {
    code --install-extension $extension --force
}
code --list-extensions
