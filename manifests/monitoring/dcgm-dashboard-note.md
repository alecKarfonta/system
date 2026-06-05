# GPU dashboards in Grafana

The GPU Operator deploys **DCGM Exporter**, which publishes per-GPU metrics
(utilization, memory, temperature, power) that Prometheus scrapes automatically.

To get the prebuilt NVIDIA dashboard:
1. Open Grafana (see the port-forward command printed after `make stack`).
2. Dashboards -> New -> Import.
3. Use dashboard ID **12239** ("NVIDIA DCGM Exporter Dashboard").
4. Select your Prometheus data source.

You'll see every GPU in the fleet, grouped by node, in one view.
