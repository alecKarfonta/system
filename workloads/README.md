# Workloads

Application manifests deployed onto the k3s cluster. Cluster infrastructure
(GPU operator, storage, monitoring) lives in `manifests/`; this directory is
for services like Ollama, Jupyter, and DevPI.

## Planned migrations from legacy

| Legacy | Target |
|--------|--------|
| `manual_deployments/ollama-rtx5090/` | `workloads/ollama/` |
| `manual_deployments/jupyter-server/` | `workloads/jupyter/` |
| `manual_deployments/devpi/` | `workloads/devpi/` |
| `manual_deployments/postgres/` | `workloads/postgres/` |

See `manifests/examples/` for GPU workload patterns to follow.
