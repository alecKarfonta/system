# ML Dev Stack (Legacy)

Multi-service docker-compose environment from the pre-k3s era.

```bash
cd manual_deployments/ml-dev-stack
docker compose up -d
```

Services: Jupyter, PostgreSQL, DevPI, vLLM, Redis, MongoDB, Elasticsearch,
Kibana, Grafana, Prometheus, Nginx.

**Note:** Some referenced files (e.g. `postgres/init.sql`, `ml/Dockerfile.vllm`,
nginx/grafana/prometheus configs) may be missing — this stack was never fully
wired up.
