# =============================================================================
#  Homelab GPU Cluster - friendly command interface
#  Run 'make' or 'make help' to see everything.
# =============================================================================
SHELL := /bin/bash
S := ./scripts

.DEFAULT_GOAL := help

.PHONY: help preflight server join-server agent add-node remove-node \
        label-gpus status stack dashboard ui cockpit cockpit-ui cockpit-demo cli kubeconfig smoke uninstall config

help: ## Show this help
	@echo ""
	@echo "  Homelab GPU Cluster"
	@echo "  ==================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[1m%-14s\033[0m %s\n",$$1,$$2}'
	@echo ""
	@echo "  Typical first run (on the control-plane machine):"
	@echo "    make config        # then edit config/cluster.env"
	@echo "    make preflight"
	@echo "    make server"
	@echo "    make kubeconfig"
	@echo "    make stack"
	@echo "    make label-gpus"
	@echo "    make status"
	@echo ""

config: ## Create config/cluster.env from the template
	@if [[ -f config/cluster.env ]]; then \
	  echo "config/cluster.env already exists — not overwriting."; \
	else \
	  cp config/cluster.env.example config/cluster.env; \
	  echo "Created config/cluster.env — open it and edit SERVER_HOST etc."; \
	fi

preflight: ## Check this machine is ready (run on every node before joining)
	@$(S)/preflight.sh

server: ## Install the FIRST control-plane node (run on that machine)
	@$(S)/install-server.sh

join-server: ## Join as an ADDITIONAL control-plane node (needs JOIN_TOKEN=...)
	@$(S)/join-server.sh

agent: ## Join as a GPU worker (needs JOIN_TOKEN=...)
	@$(S)/install-agent.sh

add-node: ## (on a server) Print the command to add a new node. ROLE=worker|server
	@$(S)/add-node.sh $(ROLE)

remove-node: ## (on a server) Gracefully remove a node. Usage: make remove-node NODE=name
	@$(S)/remove-node.sh

label-gpus: ## Auto-tag nodes by GPU tier (training/inference/...)
	@$(S)/label-gpus.sh

status: ## Show the whole fleet: nodes, GPUs, tiers, workloads
	@$(S)/cluster-status.sh

stack: ## Install GPU Operator + DRA + Longhorn + monitoring (Helm)
	@$(S)/bootstrap-stack.sh

dashboard: ## Install Headlamp, a web GUI for the cluster (run once)
	@$(S)/dashboard.sh install

ui: ## Open the Headlamp web GUI + print your login token
	@$(S)/dashboard.sh open

cockpit: ## Install/update the Fleet Cockpit (GPU-centric management GUI)
	@$(S)/cockpit.sh install

cockpit-ui: ## Open the Fleet Cockpit
	@$(S)/cockpit.sh open

cockpit-demo: ## Preview the Cockpit locally with fake data
	@$(S)/cockpit.sh demo

cli: ## Install the 'homelab' CLI to /usr/local/bin
	@sudo ln -sf $(CURDIR)/cli/homelab /usr/local/bin/homelab && echo "Installed: homelab (try 'homelab discover')"

kubeconfig: ## (on a server) Write ~/.kube/config so plain kubectl works
	@$(S)/kubeconfig.sh

smoke: ## Run a GPU smoke test and show its output
	@kubectl apply -f manifests/examples/01-gpu-smoke-test.yaml
	@echo "Waiting for the test pod to finish..."
	@kubectl wait --for=condition=complete job/gpu-smoke-test --timeout=120s || \
	  kubectl wait --for=condition=failed job/gpu-smoke-test --timeout=10s || true
	@echo "----- nvidia-smi output -----"
	@kubectl logs job/gpu-smoke-test || true
	@kubectl delete -f manifests/examples/01-gpu-smoke-test.yaml >/dev/null 2>&1 || true

uninstall: ## Remove k3s from THIS machine (destructive)
	@$(S)/uninstall.sh
