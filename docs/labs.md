# platformctl Labs

Labs are disposable architecture-validation environments and are deliberately separate
from the stable local development-service catalog.

Initial labs:

- `redis-cluster` — six-node Redis Cluster; smoke and failover tests.
- `kafka-kraft-3` — three-node Kafka KRaft; smoke and broker-failure tests.
- `redis-security` — Redis TLS/mTLS and ACL authorization checks.
- `rag-pipeline` — Ollama + Qdrant RAG retrieval pipeline; smoke and
  Qdrant-outage tests. See `docs/ai-workstation.md`.
- `agent-mesh` — three-replica LangGraph agent mesh behind Ollama; smoke and
  node-failure tests. See `docs/ai-workstation.md`.

Each supports Docker and Kubernetes.

Examples:

```bash
workstation lab toolchain install
workstation lab cluster create

workstation lab up redis-cluster --runtime docker
workstation lab test redis-cluster smoke --runtime docker
workstation lab test redis-cluster failover --runtime docker
workstation lab report redis-cluster --runtime docker
workstation lab destroy redis-cluster --runtime docker --yes

workstation lab up kafka-kraft-3 --runtime kubernetes
workstation lab test kafka-kraft-3 broker-failure --runtime kubernetes
workstation lab report kafka-kraft-3 --runtime kubernetes
workstation lab destroy kafka-kraft-3 --runtime kubernetes --yes

workstation lab up redis-security --runtime kubernetes
workstation lab test redis-security smoke --runtime kubernetes
```

Kubernetes labs use a dedicated k3d cluster called `platform-labs`. Labs are isolated
with their own namespaces and Docker Compose project/network names.

Lab state, certificates and generated credentials are stored outside Git under
`~/.local/state/platformctl/labs`.

Production is never deployed directly from lab state. Successful patterns and evidence
are translated into reviewed production IaC (Terraform/Helm/Ansible/etc.).
