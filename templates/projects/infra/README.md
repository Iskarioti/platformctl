# __PROJECT_NAME__

Governed multi-tool infrastructure-automation project created by platformctl -
Terraform, Ansible, Azure CLI, and kubectl/helm in one Dev Container. For a
Terraform-only project, use the `terraform` template instead.

## Terraform

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

## Ansible

```bash
ansible-playbook ansible/playbook.yml --syntax-check
```

Fill in `ansible/inventory.ini` with real hosts before running for real.

Cloud/infra credentials go in your own `.env` (never committed - see
`.env.example`), never hardcoded in Terraform variables or Ansible inventory.
