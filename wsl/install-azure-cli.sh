#!/usr/bin/env bash
set -euo pipefail
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az extension add --name azure-devops --upgrade
az version
